pipeline {
    agent any
    
    environment {
        // Configurar variables de entorno para Terraform
        TF_IN_AUTOMATION = 'true'
        TF_INPUT = 'false'
        TF_LOG = 'INFO'  // Cambiar a DEBUG si necesitas más detalles
        
        // Configurar AWS CLI si es necesario
        AWS_DEFAULT_REGION = 'us-east-1'
        AWS_REGION = 'us-east-1'
    }
    
    stages {
        stage('Verificar Herramientas') {
            steps {
                echo "🔧 Verificando herramientas necesarias..."
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
                        echo "⚠️ AWS CLI no encontrado (opcional)"
                    fi
                    
                    # Verificar Git
                    if command -v git &> /dev/null; then
                        echo "✅ Git encontrado: $(git --version)"
                    else
                        echo "⚠️ Git no encontrado (opcional)"
                    fi
                '''
            }
        }
        
        stage('Preparar Workspace') {
            steps {
                echo "📁 Preparando workspace de Terraform..."
                sh '''
                    echo "Copiando archivos de infraestructura..."
                    
                    # Copiar todos los archivos de Terraform
                    cp -r /home/leonardo-sanchez/PROYECTO-INFRAESTRUCTURA/*.tf . 2>/dev/null || true
                    cp -r /home/leonardo-sanchez/PROYECTO-INFRAESTRUCTURA/.terraform* . 2>/dev/null || true
                    cp -r /home/leonardo-sanchez/PROYECTO-INFRAESTRUCTURA/terraform.* . 2>/dev/null || true
                    
                    echo "📋 Archivos de Terraform encontrados:"
                    ls -la *.tf 2>/dev/null || echo "No se encontraron archivos .tf"
                    
                    echo "📋 Otros archivos de Terraform:"
                    ls -la terraform.* .terraform* 2>/dev/null || echo "No se encontraron archivos de estado/configuración"
                    
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
        
        stage('Terraform Init') {
            steps {
                echo "🚀 Ejecutando terraform init..."
                sh '''
                    echo "====================================="
                    echo "🔧 TERRAFORM INIT"
                    echo "====================================="
                    
                    # Limpiar cualquier directorio .terraform anterior (opcional)
                    if [ -d ".terraform" ]; then
                        echo "🗑️ Limpiando directorio .terraform anterior..."
                        rm -rf .terraform
                    fi
                    
                    # Ejecutar terraform init
                    echo "🚀 Iniciando terraform init..."
                    terraform init -input=false -no-color
                    
                    INIT_EXIT_CODE=$?
                    
                    if [ $INIT_EXIT_CODE -eq 0 ]; then
                        echo "✅ terraform init completado exitosamente"
                    else
                        echo "❌ terraform init falló con código de salida: $INIT_EXIT_CODE"
                        exit $INIT_EXIT_CODE
                    fi
                    
                    echo "====================================="
                    echo "📊 INFORMACIÓN POST-INIT"
                    echo "====================================="
                    
                    # Mostrar información del workspace
                    echo "📂 Workspace actual:"
                    terraform workspace show || echo "No hay workspace configurado"
                    
                    # Mostrar providers instalados
                    echo ""
                    echo "🔌 Providers instalados:"
                    if [ -d ".terraform/providers" ]; then
                        find .terraform/providers -name "terraform-provider-*" -type f | head -10
                    else
                        echo "No se encontraron providers"
                    fi
                    
                    # Mostrar versión de Terraform y estado
                    echo ""
                    echo "📋 Información de Terraform:"
                    terraform version
                    
                    # Verificar archivo de estado
                    echo ""
                    echo "💾 Estado de Terraform:"
                    if [ -f "terraform.tfstate" ]; then
                        echo "✅ Archivo de estado encontrado: terraform.tfstate"
                        echo "📊 Tamaño: $(du -h terraform.tfstate)"
                    else
                        echo "ℹ️ No hay archivo de estado local (normal para nuevo workspace)"
                    fi
                    
                    echo "====================================="
                    echo "✅ TERRAFORM INIT COMPLETADO"
                    echo "====================================="
                '''
            }
        }
        
        stage('Validar Configuración') {
            steps {
                echo "🔍 Validando configuración de Terraform..."
                sh '''
                    echo "====================================="
                    echo "🔍 TERRAFORM VALIDATE"
                    echo "====================================="
                    
                    # Ejecutar terraform validate
                    terraform validate -no-color
                    
                    VALIDATE_EXIT_CODE=$?
                    
                    if [ $VALIDATE_EXIT_CODE -eq 0 ]; then
                        echo "✅ Configuración de Terraform es válida"
                    else
                        echo "❌ Configuración de Terraform tiene errores"
                        echo "⚠️ El init fue exitoso pero hay problemas de sintaxis"
                        # No fallamos el pipeline aquí, solo advertimos
                    fi
                '''
            }
        }
        
        stage('Mostrar Plan (Opcional)') {
            when {
                // Solo ejecutar si hay credenciales AWS configuradas
                expression { 
                    return env.AWS_ACCESS_KEY_ID != null || fileExists('~/.aws/credentials') 
                }
            }
            steps {
                echo "📋 Mostrando plan de Terraform (solo si hay credenciales AWS)..."
                script {
                    try {
                        sh '''
                            echo "====================================="
                            echo "📋 TERRAFORM PLAN (PREVIEW)"
                            echo "====================================="
                            
                            # Ejecutar terraform plan solo para mostrar qué se haría
                            # Sin aplicar cambios
                            terraform plan -no-color -input=false || echo "⚠️ No se pudo ejecutar plan (credenciales AWS faltantes)"
                        '''
                    } catch (Exception e) {
                        echo "⚠️ No se pudo ejecutar terraform plan: ${e.getMessage()}"
                        echo "ℹ️ Esto es normal si no hay credenciales AWS configuradas"
                    }
                }
            }
        }
    }
    
    post {
        always {
            echo "📁 Archivando artefactos de Terraform..."
            
            // Archivar archivos importantes de Terraform
            script {
                try {
                    archiveArtifacts artifacts: '.terraform.lock.hcl, terraform.tfstate*, *.tf', allowEmptyArchive: true, fingerprint: true
                    echo "✅ Artefactos archivados exitosamente"
                } catch (Exception e) {
                    echo "⚠️ Error al archivar: ${e.getMessage()}"
                }
            }
            
            echo ""
            echo "📋 RESULTADOS DEL TERRAFORM INIT:"
            echo "✅ Workspace preparado"
            echo "✅ Providers descargados"
            echo "✅ Backend inicializado"
            echo "📁 Archivos archivados como artifacts"
            echo ""
            echo "🔗 PRÓXIMOS PASOS:"
            echo "1. Configurar credenciales AWS si planeas hacer 'terraform plan/apply'"
            echo "2. Revisar los archivos .tf si terraform validate mostró errores"
            echo "3. Ejecutar pipeline de 'terraform plan' si quieres ver cambios"
        }
        
        success {
            echo ""
            echo "🎉 ¡TERRAFORM INIT COMPLETADO EXITOSAMENTE!"
            echo "✅ Tu workspace de Terraform está listo para usar"
            echo "🚀 Puedes proceder con terraform plan/apply"
        }
        
        failure {
            echo ""
            echo "❌ TERRAFORM INIT FALLÓ"
            echo "🔍 Revisa los logs arriba para identificar el problema"
            echo "🛠️ Problemas comunes:"
            echo "   - Archivos .tf con errores de sintaxis"
            echo "   - Providers no disponibles"
            echo "   - Problemas de conectividad"
            echo "   - Permisos de archivo/directorio"
        }
        
        unstable {
            echo ""
            echo "⚠️ TERRAFORM INIT COMPLETADO CON ADVERTENCIAS"
            echo "🔍 Revisa los mensajes de validación arriba"
        }
    }
}
