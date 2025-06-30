pipeline {
    agent any
    
    environment {
        // Configurar variables de entorno para Terraform
        TF_IN_AUTOMATION = 'true'
        TF_INPUT = 'false'
        TF_LOG = 'INFO'
        
        // Configurar AWS
        AWS_DEFAULT_REGION = 'us-east-1'
        AWS_REGION = 'us-east-1'
    }
    
    parameters {
        booleanParam(
            name: 'AUTO_APPROVE',
            defaultValue: false,
            description: '⚠️ ¿Destruir automáticamente sin confirmación manual? (PELIGROSO)'
        )
        choice(
            name: 'WORKSPACE',
            choices: ['dev', 'staging', 'default', 'prod'],
            description: '🏢 Workspace de Terraform a destruir'
        )
        string(
            name: 'TARGET_RESOURCE',
            defaultValue: '',
            description: '🎯 Recurso específico a destruir (opcional, ej: aws_instance.web)'
        )
        booleanParam(
            name: 'BACKUP_STATE',
            defaultValue: true,
            description: '💾 ¿Crear backup del estado antes de destruir?'
        )
        string(
            name: 'CONFIRMATION_TEXT',
            defaultValue: '',
            description: '⚠️ Escribe "DESTROY" para confirmar (solo si AUTO_APPROVE está activado)'
        )
    }
    
    stages {
        stage('Verificar Configuración') {
            steps {
                echo "🔧 Verificando configuración para Terraform Destroy..."
                sh '''
                    echo "📍 Workspace: $(pwd)"
                    echo "👤 Usuario: $(whoami)"
                    echo "🏠 Home: $HOME"
                    
                    # Verificar Terraform
                    if command -v terraform &> /dev/null; then
                        echo "✅ Terraform encontrado: $(terraform version)"
                    else
                        echo "❌ Terraform no encontrado"
                        exit 1
                    fi
                    
                    # Verificar AWS CLI
                    if command -v aws &> /dev/null; then
                        echo "✅ AWS CLI encontrado: $(aws --version)"
                    else
                        echo "❌ AWS CLI no encontrado - necesario para destroy"
                        exit 1
                    fi
                '''
            }
        }
        
        stage('Validaciones de Seguridad') {
            steps {
                script {
                    echo "🛡️ Ejecutando validaciones de seguridad..."
                    
                    // Verificar que no es producción sin confirmaciones extras
                    if (params.WORKSPACE == 'prod' && params.AUTO_APPROVE) {
                        error("🚨 ERROR: No se permite AUTO_APPROVE en workspace 'prod'. Desactiva AUTO_APPROVE para continuar.")
                    }
                    
                    // Si AUTO_APPROVE está activado, verificar texto de confirmación
                    if (params.AUTO_APPROVE && params.CONFIRMATION_TEXT != 'DESTROY') {
                        error("🚨 ERROR: Para usar AUTO_APPROVE debes escribir 'DESTROY' en CONFIRMATION_TEXT")
                    }
                    
                    echo "✅ Validaciones de seguridad pasadas"
                    echo "🏢 Workspace objetivo: ${params.WORKSPACE}"
                    if (params.TARGET_RESOURCE) {
                        echo "🎯 Recurso específico: ${params.TARGET_RESOURCE}"
                    } else {
                        echo "⚠️ ADVERTENCIA: Se destruirá TODA la infraestructura del workspace"
                    }
                }
            }
        }
        
        stage('Preparar Workspace') {
            steps {
                echo "📁 Preparando workspace de Terraform..."
                sh '''
                    echo "Copiando archivos de infraestructura..."
                    
                    # Copiar archivos de Terraform
                    cp -r /home/leonardo-sanchez/PROYECTO-INFRAESTRUCTURA/*.tf . 2>/dev/null || true
                    cp -r /home/leonardo-sanchez/PROYECTO-INFRAESTRUCTURA/.terraform* . 2>/dev/null || true
                    cp -r /home/leonardo-sanchez/PROYECTO-INFRAESTRUCTURA/terraform.* . 2>/dev/null || true
                    
                    echo "📋 Archivos copiados:"
                    ls -la *.tf 2>/dev/null || echo "❌ No se encontraron archivos .tf"
                    
                    # Verificar que tenemos archivos .tf
                    if ls *.tf 1> /dev/null 2>&1; then
                        echo "✅ Archivos .tf encontrados"
                        echo "📊 Total de archivos .tf: $(ls *.tf | wc -l)"
                    else
                        echo "❌ No se encontraron archivos .tf"
                        exit 1
                    fi
                '''
            }
        }
        
        stage('Seleccionar Workspace') {
            steps {
                echo "🏢 Configurando workspace: ${params.WORKSPACE}"
                sh '''
                    echo "======================================"
                    echo "🏢 CONFIGURACIÓN DE WORKSPACE"
                    echo "======================================"
                    
                    # Mostrar workspace actual
                    echo "📂 Workspace actual:"
                    terraform workspace show || echo "No hay workspace configurado"
                    
                    # Cambiar al workspace especificado si no es el actual
                    CURRENT_WORKSPACE=$(terraform workspace show 2>/dev/null || echo "default")
                    TARGET_WORKSPACE="${params.WORKSPACE}"
                    
                    if [ "$CURRENT_WORKSPACE" != "$TARGET_WORKSPACE" ]; then
                        echo "🔄 Cambiando de workspace '$CURRENT_WORKSPACE' a '$TARGET_WORKSPACE'"
                        
                        # Intentar seleccionar el workspace
                        if terraform workspace select "$TARGET_WORKSPACE" 2>/dev/null; then
                            echo "✅ Workspace '$TARGET_WORKSPACE' seleccionado"
                        else
                            echo "❌ Workspace '$TARGET_WORKSPACE' no existe"
                            echo "📋 Workspaces disponibles:"
                            terraform workspace list
                            exit 1
                        fi
                    else
                        echo "✅ Ya estamos en el workspace correcto: $TARGET_WORKSPACE"
                    fi
                    
                    echo "📂 Workspace final: $(terraform workspace show)"
                '''
            }
        }
        
        stage('Backup del Estado') {
            when {
                expression { params.BACKUP_STATE }
            }
            steps {
                echo "💾 Creando backup del estado actual..."
                sh '''
                    echo "======================================"
                    echo "💾 BACKUP DEL ESTADO"
                    echo "======================================"
                    
                    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
                    WORKSPACE_NAME="${params.WORKSPACE}"
                    BACKUP_DIR="backup_${WORKSPACE_NAME}_${TIMESTAMP}"
                    
                    echo "📁 Creando directorio de backup: $BACKUP_DIR"
                    mkdir -p "$BACKUP_DIR"
                    
                    # Backup del estado
                    if [ -f "terraform.tfstate" ]; then
                        echo "💾 Backing up terraform.tfstate"
                        cp terraform.tfstate "$BACKUP_DIR/terraform.tfstate.backup"
                    fi
                    
                    # Backup de archivos de configuración
                    echo "📄 Backing up archivos .tf"
                    cp *.tf "$BACKUP_DIR/" 2>/dev/null || true
                    
                    # Backup del lock file
                    if [ -f ".terraform.lock.hcl" ]; then
                        echo "🔒 Backing up .terraform.lock.hcl"
                        cp .terraform.lock.hcl "$BACKUP_DIR/"
                    fi
                    
                    # Crear un manifest del backup
                    echo "📋 Creando manifest del backup"
                    cat > "$BACKUP_DIR/backup_manifest.txt" << EOF
Backup creado: $(date)
Workspace: $WORKSPACE_NAME
Usuario: $(whoami)
Terraform version: $(terraform version | head -1)
Total archivos .tf: $(ls *.tf | wc -l)
Estado respaldado: $([ -f "terraform.tfstate" ] && echo "Sí" || echo "No")
EOF
                    
                    echo "✅ Backup completado en: $BACKUP_DIR"
                    echo "📊 Contenido del backup:"
                    ls -la "$BACKUP_DIR"
                '''
            }
        }
        
        stage('Inventario Pre-Destroy') {
            steps {
                echo "📋 Inventariando recursos antes del destroy..."
                sh '''
                    echo "======================================"
                    echo "📋 INVENTARIO PRE-DESTROY"
                    echo "======================================"
                    
                    # Listar recursos actuales
                    echo "📦 Recursos en el estado actual:"
                    terraform state list 2>/dev/null || echo "No hay recursos en el estado"
                    
                    # Contar recursos
                    RESOURCE_COUNT=$(terraform state list 2>/dev/null | wc -l || echo "0")
                    echo ""
                    echo "📊 Total de recursos a destruir: $RESOURCE_COUNT"
                    
                    # Si hay recursos específicos, validar que existan
                    if [ -n "${TARGET_RESOURCE}" ]; then
                        echo ""
                        echo "🎯 Verificando recurso específico: ${TARGET_RESOURCE}"
                        if terraform state show "${TARGET_RESOURCE}" >/dev/null 2>&1; then
                            echo "✅ Recurso encontrado en el estado"
                        else
                            echo "❌ Recurso no encontrado en el estado"
                            echo "📋 Recursos disponibles:"
                            terraform state list | grep -i "$(echo ${TARGET_RESOURCE} | cut -d. -f1)" || echo "No se encontraron recursos similares"
                            exit 1
                        fi
                    fi
                    
                    # Verificar outputs que se perderán
                    echo ""
                    echo "📤 Outputs que se perderán:"
                    terraform output -no-color 2>/dev/null || echo "No hay outputs configurados"
                '''
            }
        }
        
        stage('Terraform Plan Destroy') {
            steps {
                echo "📋 Generando plan de destrucción..."
                sh '''
                    echo "======================================"
                    echo "🗑️ TERRAFORM PLAN -DESTROY"
                    echo "======================================"
                    
                    # Preparar comando de plan destroy
                    PLAN_COMMAND="terraform plan -destroy -no-color -input=false -out=destroy.tfplan"
                    
                    # Agregar target si se especificó
                    if [ -n "${TARGET_RESOURCE}" ]; then
                        echo "🎯 Destruyendo solo el recurso: ${TARGET_RESOURCE}"
                        PLAN_COMMAND="$PLAN_COMMAND -target=${TARGET_RESOURCE}"
                    else
                        echo "⚠️ DESTRUYENDO TODA LA INFRAESTRUCTURA"
                    fi
                    
                    echo "🚀 Ejecutando: $PLAN_COMMAND"
                    eval $PLAN_COMMAND
                    
                    PLAN_EXIT_CODE=$?
                    
                    if [ $PLAN_EXIT_CODE -eq 0 ]; then
                        echo "✅ Plan de destrucción generado exitosamente"
                    else
                        echo "❌ Plan de destrucción falló con código: $PLAN_EXIT_CODE"
                        exit $PLAN_EXIT_CODE
                    fi
                    
                    # Mostrar resumen del plan
                    echo ""
                    echo "📊 RESUMEN DEL PLAN DE DESTRUCCIÓN:"
                    echo "======================================"
                    terraform show -no-color destroy.tfplan | head -50
                    echo "======================================"
                '''
            }
        }
        
        stage('Confirmación Manual de Destroy') {
            when {
                expression { !params.AUTO_APPROVE }
            }
            steps {
                script {
                    echo "⚠️ CONFIRMACIÓN REQUERIDA PARA DESTRUIR INFRAESTRUCTURA"
                    echo ""
                    echo "🚨 OPERACIÓN DESTRUCTIVA - NO REVERSIBLE"
                    echo "📋 RESUMEN DE LA OPERACIÓN:"
                    echo "🏢 Workspace: ${params.WORKSPACE}"
                    if (params.TARGET_RESOURCE) {
                        echo "🎯 Recurso específico: ${params.TARGET_RESOURCE}"
                    } else {
                        echo "🎯 Scope: ⚠️ TODA LA INFRAESTRUCTURA DEL WORKSPACE ⚠️"
                    }
                    echo "💾 Backup creado: ${params.BACKUP_STATE ? 'Sí' : 'No'}"
                    echo ""
                    echo "⚠️ Esta operación eliminará permanentemente los recursos de AWS"
                    echo "⚠️ Asegúrate de haber revisado el plan de destrucción arriba"
                    echo ""
                    
                    // Confirmación manual con timeout más largo para destroy
                    timeout(time: 15, unit: 'MINUTES') {
                        input message: '🚨 ¿CONFIRMAS que deseas DESTRUIR estos recursos?\n\n⚠️ Esta acción NO es reversible ⚠️', 
                              ok: '🗑️ SÍ, DESTRUIR RECURSOS',
                              submitterParameter: 'DESTROYER'
                    }
                    
                    echo "⚠️ Destrucción autorizada por: ${env.DESTROYER ?: 'Usuario'}"
                }
            }
        }
        
        stage('Terraform Destroy') {
            steps {
                echo "🗑️ Destruyendo infraestructura..."
                sh '''
                    echo "======================================"
                    echo "🗑️ TERRAFORM DESTROY"
                    echo "======================================"
                    
                    # Verificar que existe el plan
                    if [ ! -f "destroy.tfplan" ]; then
                        echo "❌ No se encontró el archivo de plan 'destroy.tfplan'"
                        exit 1
                    fi
                    
                    echo "🗑️ Aplicando el plan de destrucción..."
                    echo "⚠️ ADVERTENCIA: Esta operación es irreversible"
                    
                    # Aplicar el plan de destrucción
                    terraform apply -no-color -input=false destroy.tfplan
                    
                    DESTROY_EXIT_CODE=$?
                    
                    if [ $DESTROY_EXIT_CODE -eq 0 ]; then
                        echo "✅ Destroy completado exitosamente"
                    else
                        echo "❌ Destroy falló con código: $DESTROY_EXIT_CODE"
                        echo "⚠️ Algunos recursos pueden haber sido destruidos parcialmente"
                        echo "🔍 Revisa el estado actual y los logs de error"
                        exit $DESTROY_EXIT_CODE
                    fi
                    
                    echo "======================================"
                    echo "📊 INFORMACIÓN POST-DESTROY"
                    echo "======================================"
                    
                    # Verificar qué recursos quedan
                    echo "📦 Recursos restantes en el estado:"
                    REMAINING_RESOURCES=$(terraform state list 2>/dev/null | wc -l || echo "0")
                    if [ "$REMAINING_RESOURCES" -eq 0 ]; then
                        echo "✅ No quedan recursos en el estado"
                    else
                        echo "⚠️ Quedan $REMAINING_RESOURCES recursos:"
                        terraform state list 2>/dev/null || echo "Error al listar recursos"
                    fi
                    
                    # Mostrar estado del workspace
                    echo ""
                    echo "📂 Workspace actual: $(terraform workspace show)"
                '''
            }
        }
        
        stage('Verificar Destrucción') {
            steps {
                echo "🔍 Verificando que la destrucción fue completa..."
                sh '''
                    echo "======================================"
                    echo "🔍 VERIFICACIÓN POST-DESTROY"
                    echo "======================================"
                    
                    # Verificar estado local
                    REMAINING_RESOURCES=$(terraform state list 2>/dev/null | wc -l || echo "0")
                    echo "📊 Recursos restantes en el estado local: $REMAINING_RESOURCES"
                    
                    if [ "$REMAINING_RESOURCES" -eq 0 ]; then
                        echo "✅ Estado local limpio - todos los recursos fueron destruidos"
                    else
                        echo "⚠️ Recursos que no se pudieron destruir:"
                        terraform state list
                        echo ""
                        echo "🔍 Esto puede ser normal para algunos recursos (data sources, etc.)"
                    fi
                    
                    # Verificar con AWS CLI si está disponible
                    if command -v aws &> /dev/null; then
                        echo ""
                        echo "🏥 Verificación en AWS:"
                        echo "👤 Usuario AWS: $(aws sts get-caller-identity --query 'Arn' --output text 2>/dev/null || echo 'No disponible')"
                        echo "🌍 Región: $(aws configure get region 2>/dev/null || echo $AWS_DEFAULT_REGION)"
                        
                        # Ejemplo de verificación (ajustar según tus recursos)
                        echo ""
                        echo "📊 Verificación rápida de recursos comunes en AWS:"
                        echo "🖥️ Instancias EC2 ejecutándose:"
                        aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" --query 'Reservations[].Instances[].InstanceId' --output text 2>/dev/null | wc -w || echo "No se pudo verificar"
                        
                        echo "🗄️ Grupos de seguridad (excluyendo default):"
                        aws ec2 describe-security-groups --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text 2>/dev/null | wc -w || echo "No se pudo verificar"
                    fi
                '''
            }
        }
    }
    
    post {
        always {
            echo "📁 Guardando artefactos de Terraform Destroy..."
            
            script {
                try {
                    // Archivar archivos importantes incluyendo backups
                    archiveArtifacts artifacts: 'destroy.tfplan, terraform.tfstate*, .terraform.lock.hcl, *.tf, backup_*/**', 
                                   allowEmptyArchive: true, 
                                   fingerprint: true
                    echo "✅ Artefactos archivados exitosamente"
                } catch (Exception e) {
                    echo "⚠️ Error al archivar: ${e.getMessage()}"
                }
            }
            
            // Limpiar plan file por seguridad
            sh 'rm -f destroy.tfplan || true'
            
            echo ""
            echo "📋 RESUMEN DE TERRAFORM DESTROY:"
            echo "🏢 Workspace procesado: ${params.WORKSPACE}"
            script {
                if (params.TARGET_RESOURCE) {
                    echo "🎯 Recurso destruido: ${params.TARGET_RESOURCE}"
                } else {
                    echo "🎯 Scope: Infraestructura completa del workspace"
                }
            }
            echo "💾 Backup creado: ${params.BACKUP_STATE ? 'Sí (ver Build Artifacts)' : 'No'}"
            echo "📁 Artefactos guardados en Build Artifacts"
        }
        
        success {
            echo ""
            echo "🎉 ¡TERRAFORM DESTROY COMPLETADO EXITOSAMENTE!"
            echo "✅ Infraestructura destruida correctamente"
            echo "💾 Backups disponibles en Build Artifacts (si se habilitó)"
            echo ""
            echo "🔄 PRÓXIMOS PASOS:"
            echo "1. Verificar que no hay recursos huérfanos en AWS"
            echo "2. Revisar los costos de AWS para confirmar que no hay cargos"
            echo "3. Limpiar el workspace si ya no es necesario"
            echo "4. Documentar la destrucción para auditoría"
        }
        
        failure {
            echo ""
            echo "❌ TERRAFORM DESTROY FALLÓ"
            echo "🔍 Revisa los logs para identificar el problema"
            echo ""
            echo "🛠️ PROBLEMAS COMUNES:"
            echo "   - Recursos con dependencias que impiden la destrucción"
            echo "   - Credenciales AWS incorrectas o expiradas"
            echo "   - Recursos protegidos contra eliminación"
            echo "   - Problemas de red o conectividad"
            echo "   - Recursos bloqueados por otros procesos"
            echo ""
            echo "🔄 RECUPERACIÓN:"
            echo "1. Revisa el estado actual: terraform state list"
            echo "2. Identifica recursos problemáticos en AWS console"
            echo "3. Considera usar terraform state rm para recursos problema"
            echo "4. Intenta destroy nuevamente con -target para recursos específicos"
            echo "5. Como último recurso, limpia manualmente en AWS console"
            echo ""
            echo "💾 TUS BACKUPS ESTÁN SEGUROS EN BUILD ARTIFACTS"
        }
        
        aborted {
            echo ""
            echo "⏹️ TERRAFORM DESTROY CANCELADO"
            echo "🔍 La operación fue cancelada por el usuario"
            echo "💾 El estado de Terraform puede estar en un estado intermedio"
            echo "🔄 Revisa terraform state list para ver el estado actual"
            echo "💾 Los backups están disponibles en Build Artifacts"
        }
    }
}
