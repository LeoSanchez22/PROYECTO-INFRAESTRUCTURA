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
                    echo "Copiando desde: /home/leonardo-sanchez/PROYECTO-INFRAESTRUCTURA/"
                    echo "Copiando hacia: $(pwd)"
                    
                    # Copiar archivos del proyecto
                    cp -r /home/leonardo-sanchez/PROYECTO-INFRAESTRUCTURA/* . 2>/dev/null || echo "⚠️ Algunos archivos no se pudieron copiar"
                    cp /home/leonardo-sanchez/PROYECTO-INFRAESTRUCTURA/.* . 2>/dev/null || echo "⚠️ Algunos archivos ocultos no se pudieron copiar"
                    
                    echo "📋 Archivos copiados:"
                    ls -la | head -20
                    
                    echo "🔍 Buscando archivos .tf (Terraform):"
                    find . -name "*.tf" -type f | head -10
                '''
            }
        }
        
        stage('Ejecutar Análisis Checkov') {
            steps {
                echo "🔐 Ejecutando análisis de seguridad con Checkov..."
                sh '''
                    echo "🚀 Iniciando Checkov scan..."
                    echo "📂 Directorio de análisis: $(pwd)"
                    
                    # Tu comando exacto de Checkov
                    docker run --rm -v $(pwd):/app --workdir /app bridgecrew/checkov \
                        --directory /app \
                        --output junitxml \
                        --output-file-path /app/results.xml \
                        --quiet
                    
                    echo "✅ Checkov completado"
                    
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
                        exit 1
                    fi
                '''
            }
        }
        
        stage('Procesar Resultados') {
            steps {
                echo "📊 Analizando resultados de seguridad..."
                sh '''
                    echo "===================================================="
                    echo "📋 RESUMEN DE ANÁLISIS DE SEGURIDAD CHECKOV"
                    echo "===================================================="
                    
                    if [ -f "results.xml" ]; then
                        # Extraer estadísticas del XML
                        TESTS=$(grep -o 'tests="[0-9]*"' results.xml | head -1 | grep -o '[0-9]*' || echo "0")
                        FAILURES=$(grep -o 'failures="[0-9]*"' results.xml | head -1 | grep -o '[0-9]*' || echo "0")
                        ERRORS=$(grep -o 'errors="[0-9]*"' results.xml | head -1 | grep -o '[0-9]*' || echo "0")
                        SKIPPED=$(grep -o 'skipped="[0-9]*"' results.xml | head -1 | grep -o '[0-9]*' || echo "0")
                        
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
                        cat results.xml
                        echo ""
                        echo "===================================================="
                        
                    else
                        echo "❌ No se pudo procesar el archivo results.xml"
                    fi
                '''
            }
        }
    }
    
    post {
        always {
            echo "📁 Guardando resultados y limpieza..."
            
            script {
                if (fileExists('results.xml')) {
                    try {
                        // Publicar resultados como tests de Jenkins
                        publishTestResults testResultsPattern: 'results.xml'
                        echo "✅ Resultados publicados en Jenkins Test Results"
                    } catch (Exception e) {
                        echo "⚠️ Error al publicar: ${e.getMessage()}"
                    }
                } else {
                    echo "⚠️ Archivo results.xml no encontrado"
                }
            }
            
            // Archivar como artifacts
            archiveArtifacts artifacts: 'results.xml', allowEmptyArchive: true, fingerprint: true
            
            echo ""
            echo "📋 CÓMO VER LOS RESULTADOS:"
            echo "1. 🔗 'Test Result' en el sidebar izquierdo de Jenkins"
            echo "2. 📁 'Build Artifacts' para descargar results.xml"
            echo "3. 📜 Este 'Console Output' para el resumen completo"
        }
        
        success {
            echo ""
            echo "🎉 ¡PIPELINE COMPLETADO EXITOSAMENTE!"
            echo "✅ Análisis de seguridad Checkov finalizado"
        }
        
        failure {
            echo ""
            echo "❌ PIPELINE FALLÓ"
            echo "🔍 Revisa los errores en Console Output"
        }
        
        unstable {
            echo ""
            echo "⚠️ PIPELINE COMPLETADO CON ADVERTENCIAS"
            echo "🔍 Se encontraron problemas de seguridad"
        }
    }
}
