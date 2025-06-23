pipeline {
    agent any
    
    stages {
        stage('Verificar Configuración') {
            steps {
                echo "🔧 Verificando configuración inicial..."
                sh '''
                    echo "📍 Workspace: $(pwd)"
                    echo "🐳 Docker version: $(docker --version)"
                    echo "👤 Usuario actual: $(whoami)"
                    echo "👥 Grupos: $(groups)"
                    echo "✅ Configuración verificada"
                '''
            }
        }
        
        stage('Copiar Archivos del Proyecto') {
            steps {
                echo "📁 Copiando archivos de infraestructura..."
                sh '''
                    set +e  # No fallar en errores
                    
                    echo "Copiando desde: /home/leonardo-sanchez/PROYECTO-INFRAESTRUCTURA/"
                    echo "Copiando hacia: $(pwd)"
                    
                    # Copiar archivos del proyecto
                    cp -r /home/leonardo-sanchez/PROYECTO-INFRAESTRUCTURA/* . 2>/dev/null
                    cp /home/leonardo-sanchez/PROYECTO-INFRAESTRUCTURA/.* . 2>/dev/null
                    
                    echo "📋 Archivos copiados:"
                    ls -la | head -20
                    
                    echo "🔍 Buscando archivos .tf (Terraform):"
                    find . -name "*.tf" -type f | head -10
                    
                    set -e  # Volver a activar el modo estricto
                '''
            }
        }
        
        stage('Ejecutar Análisis Checkov') {
            steps {
                echo "🔐 Ejecutando análisis de seguridad con Checkov..."
                script {
                    def checkovExitCode = sh(
                        script: '''
                            set +e  # No fallar automáticamente en errores
                            
                            echo "🚀 Iniciando Checkov scan..."
                            echo "📂 Directorio de análisis: $(pwd)"
                            
                            # Ejecutar Checkov y capturar el exit code
                            docker run --rm -v $(pwd):/app --workdir /app bridgecrew/checkov \
                                --directory /app \
                                --output junitxml \
                                --output-file-path /app/results.xml \
                                --quiet \
                                --soft-fail
                            
                            CHECKOV_EXIT_CODE=$?
                            echo "Checkov terminó con exit code: $CHECKOV_EXIT_CODE"
                            
                            # Verificar resultados
                            if [ -f "results.xml" ]; then
                                echo "📄 Archivo results.xml generado exitosamente"
                                echo "📊 Tamaño: $(du -h results.xml)"
                                
                                # Mostrar preview del XML
                                echo "👀 Preview del archivo:"
                                head -20 results.xml
                            else
                                echo "❌ ERROR: No se generó results.xml"
                                echo "📂 Contenido actual del directorio:"
                                ls -la
                                
                                # Crear un XML básico para que no falle Jenkins
                                echo '<?xml version="1.0" encoding="UTF-8"?><testsuites><testsuite name="Checkov" tests="1"><testcase name="No_Results" classname="Security"><failure message="No se pudo generar el reporte"/></testcase></testsuite></testsuites>' > results.xml
                                echo "📄 Archivo results.xml creado como fallback"
                            fi
                            
                            # Siempre salir con código 0 para no fallar el pipeline
                            exit 0
                        ''',
                        returnStatus: true
                    )
                    
                    echo "✅ Stage de Checkov completado con exit code: ${checkovExitCode}"
                }
            }
        }
        
        stage('Procesar Resultados') {
            steps {
                echo "📊 Analizando resultados de seguridad..."
                sh '''
                    set +e  # No fallar en errores
                    
                    echo "===================================================="
                    echo "📋 RESUMEN DE ANÁLISIS DE SEGURIDAD CHECKOV"
                    echo "===================================================="
                    
                    if [ -f "results.xml" ]; then
                        # Extraer estadísticas del XML
                        TESTS=$(grep -o 'tests="[0-9]*"' results.xml | head -1 | grep -o '[0-9]*' 2>/dev/null || echo "0")
                        FAILURES=$(grep -o 'failures="[0-9]*"' results.xml | head -1 | grep -o '[0-9]*' 2>/dev/null || echo "0")
                        ERRORS=$(grep -o 'errors="[0-9]*"' results.xml | head -1 | grep -o '[0-9]*' 2>/dev/null || echo "0")
                        SKIPPED=$(grep -o 'skipped="[0-9]*"' results.xml | head -1 | grep -o '[0-9]*' 2>/dev/null || echo "0")
                        
                        PASSED=$((TESTS - FAILURES - ERRORS - SKIPPED))
                        
                        echo "📊 ESTADÍSTICAS:"
                        echo "   ✅ Verificaciones totales: $TESTS"
                        echo "   🟢 Verificaciones exitosas: $PASSED"
                        echo "   🔴 Fallas encontradas: $FAILURES"
                        echo "   ⚠️  Errores encontrados: $ERRORS"
                        echo "   ⏭️  Verificaciones omitidas: $SKIPPED"
                        echo ""
                        
                        # Estado general
                        if [ "$FAILURES" -gt 0 ] || [ "$ERRORS" -gt 0 ]; then
                            TOTAL_ISSUES=$((FAILURES + ERRORS))
                            echo "🚨 RESULTADO: Se encontraron $TOTAL_ISSUES problemas de seguridad"
                            echo "🔍 Revisa los detalles en 'Test Results' en Jenkins"
                        else
                            echo "🎉 RESULTADO: ¡No se encontraron problemas de seguridad!"
                        fi
                        
                        echo "===================================================="
                        echo ""
                        echo "📄 CONTENIDO COMPLETO DEL REPORTE XML:"
                        echo "===================================================="
                        cat results.xml 2>/dev/null || echo "Error al mostrar el contenido del XML"
                        echo ""
                        echo "===================================================="
                        
                    else
                        echo "❌ No se pudo procesar el archivo results.xml"
                    fi
                    
                    # Asegurar que siempre termine con exit code 0
                    exit 0
                '''
            }
        }
    }
    
    post {
        always {
            echo "📁 Guardando resultados y limpieza..."
            
            script {
                try {
                    if (fileExists('results.xml')) {
                        // Intentar publicar con junit
                        junit(
                            allowEmptyResults: true,
                            testResults: 'results.xml',
                            keepLongStdio: true
                        )
                        echo "✅ Resultados publicados en Jenkins Test Results"
                    } else {
                        echo "⚠️ Archivo results.xml no encontrado, creando uno básico..."
                        writeFile file: 'results.xml', text: '''<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
    <testsuite name="Checkov" tests="1">
        <testcase name="Pipeline_Execution" classname="Security">
            <system-out>Pipeline ejecutado pero sin resultados de Checkov</system-out>
        </testcase>
    </testsuite>
</testsuites>'''
                        
                        junit(
                            allowEmptyResults: true,
                            testResults: 'results.xml',
                            keepLongStdio: true
                        )
                    }
                } catch (Exception e) {
                    echo "⚠️ Error al publicar resultados: ${e.getMessage()}"
                    echo "📝 Los resultados están disponibles en Build Artifacts"
                }
            }
            
            // Archivar como artifacts
            archiveArtifacts artifacts: '**/*.xml', allowEmptyArchive: true, fingerprint: true
            
            echo ""
            echo "📋 RESULTADOS DISPONIBLES EN:"
            echo "1. 🔗 'Test Result' en el sidebar izquierdo"
            echo "2. 📁 'Build Artifacts' para archivos descargables"
            echo "3. 📜 'Console Output' para ver este resumen"
        }
        
        success {
            echo ""
            echo "🎉 ¡PIPELINE COMPLETADO EXITOSAMENTE!"
            echo "✅ Análisis de seguridad finalizado sin errores técnicos"
        }
        
        failure {
            echo ""
            echo "❌ PIPELINE FALLÓ"
            echo "🔍 Revisa Console Output para detalles técnicos"
        }
    }
}
