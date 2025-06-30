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
            description: '¿Aplicar automáticamente sin confirmación manual?'
        )
        choice(
            name: 'WORKSPACE',
            choices: ['default', 'dev', 'staging', 'prod'],
            description: 'Workspace de Terraform a utilizar'
        )
        string(
            name: 'TARGET_RESOURCE',
            defaultValue: '',
            description: 'Recurso específico a aplicar (opcional, ej: aws_instance.web)'
        )
    }
    
    stages {
        stage('Verificar Configuración') {
            steps {
                echo "🔧 Verificando configuración para Terraform Apply..."
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
                        echo "❌ AWS CLI no encontrado - necesario para apply"
                        exit 1
                    fi
                '''
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
                            echo "⚠️ Workspace '$TARGET_WORKSPACE' no existe, creándolo..."
                            terraform workspace new "$TARGET_WORKSPACE"
                            echo "✅ Workspace '$TARGET_WORKSPACE' creado y seleccionado"
                        fi
                    else
                        echo "✅ Ya estamos en el workspace correcto: $TARGET_WORKSPACE"
                    fi
                    
                    echo "📂 Workspace final: $(terraform workspace show)"
                '''
            }
        }
        
        stage('Terraform Plan') {
            steps {
                echo "📋 Generando plan de ejecución..."
                sh '''
                    echo "======================================"
                    echo "📋 TERRAFORM PLAN"
                    echo "======================================"
                    
                    # Preparar comando de plan
                    PLAN_COMMAND="terraform plan -no-color -input=false -out=tfplan"
                    
                    # Agregar target si se especificó
                    if [ -n "${TARGET_RESOURCE}" ]; then
                        echo "🎯 Aplicando solo al recurso: ${TARGET_RESOURCE}"
                        PLAN_COMMAND="$PLAN_COMMAND -target=${TARGET_RESOURCE}"
                    fi
                    
                    echo "🚀 Ejecutando: $PLAN_COMMAND"
                    eval $PLAN_COMMAND
                    
                    PLAN_EXIT_CODE=$?
                    
                    if [ $PLAN_EXIT_CODE -eq 0 ]; then
                        echo "✅ Plan generado exitosamente"
                    elif [ $PLAN_EXIT_CODE -eq 2 ]; then
                        echo "ℹ️ Plan completado - hay cambios para aplicar"
                    else
                        echo "❌ Plan falló con código: $PLAN_EXIT_CODE"
                        exit $PLAN_EXIT_CODE
                    fi
                    
                    # Mostrar resumen del plan
                    echo ""
                    echo "📊 RESUMEN DEL PLAN:"
                    echo "======================================"
                    terraform show -no-color tfplan | head -50
                    echo "======================================"
                '''
            }
        }
        
        stage('Confirmación Manual') {
            when {
                expression { !params.AUTO_APPROVE }
            }
            steps {
                script {
                    echo "⏸️ Esperando confirmación manual para aplicar los cambios..."
                    echo ""
                    echo "📋 RESUMEN DE LA OPERACIÓN:"
                    echo "🏢 Workspace: ${params.WORKSPACE}"
                    if (params.TARGET_RESOURCE) {
                        echo "🎯 Recurso específico: ${params.TARGET_RESOURCE}"
                    } else {
                        echo "🎯 Scope: Toda la infraestructura"
                    }
                    echo ""
                    
                    // Confirmación manual
                    timeout(time: 10, unit: 'MINUTES') {
                        input message: '¿Deseas aplicar estos cambios de Terraform?', 
                              ok: 'Sí, aplicar cambios',
                              submitterParameter: 'APPROVER'
                    }
                    
                    echo "✅ Cambios aprobados por: ${env.APPROVER ?: 'Usuario'}"
                }
            }
        }
        
        stage('Terraform Apply') {
            steps {
                echo "🚀 Aplicando cambios de infraestructura..."
                sh '''
                    echo "======================================"
                    echo "🚀 TERRAFORM APPLY"
                    echo "======================================"
                    
                    # Verificar que existe el plan
                    if [ ! -f "tfplan" ]; then
                        echo "❌ No se encontró el archivo de plan 'tfplan'"
                        exit 1
                    fi
                    
                    echo "📋 Aplicando el plan generado..."
                    
                    # Aplicar el plan
                    terraform apply -no-color -input=false tfplan
                    
                    APPLY_EXIT_CODE=$?
                    
                    if [ $APPLY_EXIT_CODE -eq 0 ]; then
                        echo "✅ Apply completado exitosamente"
                    else
                        echo "❌ Apply falló con código: $APPLY_EXIT_CODE"
                        exit $APPLY_EXIT_CODE
                    fi
                    
                    echo "======================================"
                    echo "📊 INFORMACIÓN POST-APPLY"
                    echo "======================================"
                    
                    # Mostrar outputs si existen
                    echo "📤 Outputs de Terraform:"
                    terraform output -no-color 2>/dev/null || echo "No hay outputs configurados"
                    
                    # Mostrar estado del workspace
                    echo ""
                    echo "📂 Workspace actual: $(terraform workspace show)"
                    
                    # Información del estado
                    echo ""
                    echo "💾 Estado de Terraform:"
                    if [ -f "terraform.tfstate" ]; then
                        echo "✅ Estado actualizado: terraform.tfstate"
                        echo "📊 Tamaño: $(du -h terraform.tfstate)"
                    fi
                '''
            }
        }
        
        stage('Verificar Infraestructura') {
            steps {
                echo "🔍 Verificando infraestructura aplicada..."
                sh '''
                    echo "======================================"
                    echo "🔍 VERIFICACIÓN POST-APPLY"
                    echo "======================================"
                    
                    # Mostrar lista de recursos en el estado
                    echo "📋 Recursos en el estado:"
                    terraform state list 2>/dev/null | head -20 || echo "No se pudo listar el estado"
                    
                    # Si hay más de 20 recursos, mostrar el conteo
                    RESOURCE_COUNT=$(terraform state list 2>/dev/null | wc -l || echo "0")
                    if [ "$RESOURCE_COUNT" -gt 20 ]; then
                        echo "... y $(($RESOURCE_COUNT - 20)) recursos más"
                    fi
                    
                    echo ""
                    echo "📊 Total de recursos gestionados: $RESOURCE_COUNT"
                    
                    # Verificar la salud básica con AWS CLI si está disponible
                    if command -v aws &> /dev/null; then
                        echo ""
                        echo "🏥 Verificación básica de AWS:"
                        echo "👤 Usuario AWS: $(aws sts get-caller-identity --query 'Arn' --output text 2>/dev/null || echo 'No disponible')"
                        echo "🌍 Región: $(aws configure get region 2>/dev/null || echo $AWS_DEFAULT_REGION)"
                    fi
                '''
            }
        }
    }
    
    post {
        always {
            echo "📁 Guardando artefactos de Terraform..."
            
            script {
                try {
                    // Archivar archivos importantes
                    archiveArtifacts artifacts: 'tfplan, terraform.tfstate*, .terraform.lock.hcl, *.tf', 
                                   allowEmptyArchive: true, 
                                   fingerprint: true
                    echo "✅ Artefactos archivados exitosamente"
                } catch (Exception e) {
                    echo "⚠️ Error al archivar: ${e.getMessage()}"
                }
            }
            
            // Limpiar plan file por seguridad
            sh 'rm -f tfplan || true'
            
            echo ""
            echo "📋 RESUMEN DE TERRAFORM APPLY:"
            echo "🏢 Workspace utilizado: ${params.WORKSPACE}"
            script {
                if (params.TARGET_RESOURCE) {
                    echo "🎯 Recurso aplicado: ${params.TARGET_RESOURCE}"
                }
            }
            echo "📁 Artefactos guardados en Build Artifacts"
        }
        
        success {
            echo ""
            echo "🎉 ¡TERRAFORM APPLY COMPLETADO EXITOSAMENTE!"
            echo "✅ Infraestructura aplicada correctamente"
            echo "🔗 Revisa los outputs y el estado en Build Artifacts"
            echo ""
            echo "🚀 PRÓXIMOS PASOS:"
            echo "1. Verificar que los recursos funcionen como esperado"
            echo "2. Ejecutar pruebas de conectividad si es necesario"
            echo "3. Monitorear los recursos creados/modificados"
        }
        
        failure {
            echo ""
            echo "❌ TERRAFORM APPLY FALLÓ"
            echo "🔍 Revisa los logs para identificar el problema"
            echo ""
            echo "🛠️ PROBLEMAS COMUNES:"
            echo "   - Credenciales AWS incorrectas o expiradas"
            echo "   - Recursos con conflictos o dependencias"
            echo "   - Límites de cuota de AWS alcanzados"
            echo "   - Problemas de red o conectividad"
            echo "   - Configuración de Terraform incorrecta"
            echo ""
            echo "🔄 RECUPERACIÓN:"
            echo "1. Revisa el estado actual: terraform state list"
            echo "2. Verifica credenciales AWS"
            echo "3. Ejecuta terraform plan para diagnosticar"
            echo "4. Considera hacer terraform refresh si es seguro"
        }
        
        aborted {
            echo ""
            echo "⏹️ TERRAFORM APPLY CANCELADO"
            echo "🔍 La operación fue cancelada por el usuario"
            echo "💾 El estado de Terraform no fue modificado"
        }
    }
}
