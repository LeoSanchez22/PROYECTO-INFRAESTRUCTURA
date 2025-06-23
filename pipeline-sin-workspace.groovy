pipeline {
    agent any
    
    stages {
        stage('Preparar Archivos') {
            steps {
                echo "Copiando archivos del proyecto al workspace de Jenkins..."
                sh '''
                    echo "Workspace actual de Jenkins: $(pwd)"
                    
                    # Copiar todos los archivos de tu proyecto al workspace de Jenkins
                    cp -r /home/leonardo-sanchez/PROYECTO-INFRAESTRUCTURA/* . || true
                    cp -r /home/leonardo-sanchez/PROYECTO-INFRAESTRUCTURA/.* . 2>/dev/null || true
                    
                    echo "Archivos copiados:"
                    ls -la
                    
                    echo "Verificando Docker..."
                    docker --version
                '''
            }
        }
        
        stage('Ejecutar Checkov') {
            steps {
                echo "Ejecutando análisis de seguridad con Checkov..."
                sh '''
                    echo "Iniciando Checkov scan en: $(pwd)"
                    
                    # Tu comando exacto de Checkov - ahora ejecutándose en el workspace de Jenkins
                    docker run --rm -v $(pwd):/app --workdir /app bridgecrew/checkov \
                        --directory /app \
                        --output junitxml \
                        --output-file-path /app/results.xml \
                        --quiet
                    
                    echo "Checkov completado"
                    
                    # Verificar que se creó el archivo
                    if [ -f "results.xml" ]; then
                        echo "✅ Archivo results.xml creado exitosamente"
                        echo "Tamaño del archivo: $(du -h results.xml)"
                        echo "Ubicación: $(pwd)/results.xml"
                        echo ""
                        echo "Primeras líneas del archivo:"
                        head -10 results.xml
                    else
                        echo "❌ ERROR: No se creó el archivo results.xml"
                        echo "Contenido del directorio actual:"
                        ls -la
                        exit 1
                    fi
                '''
            }
        }
        
        stage('Mostrar Resultados') {
            steps {
                echo "Procesando y mostrando resultados..."
                sh '''
                    echo "=== ANÁLISIS DE RESULTADOS DE SEGURIDAD ==="
                    
                    if [ -f "results.xml" ]; then
                        # Extraer información básica del XML
                        TOTAL_TESTS=$(grep -o 'tests="[0-9]*"' results.xml | head -1 | grep -o '[0-9]*' || echo "0")
                        FAILURES=$(grep -o 'failures="[0-9]*"' results.xml | head -1 | grep -o '[0-9]*' || echo "0")
                        ERRORS=$(grep -o 'errors="[0-9]*"' results.xml | head -1 | grep -o '[0-9]*' || echo "0")
                        SKIPPED=$(grep -o 'skipped="[0-9]*"' results.xml | head -1 | grep -o '[0-9]*' || echo "0")
                        
                        echo "📊 RESUMEN DE SEGURIDAD:"
                        echo "   📋 Total de verificaciones: $TOTAL_TESTS"
                        echo "   ❌ Fallas encontradas: $FAILURES"
                        echo "   🚫 Errores encontrados: $ERRORS"
                        echo "   ⏭️  Verificaciones omitidas: $SKIPPED"
                        echo ""
                        
                        if [ "$FAILURES" -gt 0 ] || [ "$ERRORS" -gt 0 ]; then
                            echo "⚠️  SE ENCONTRARON $((FAILURES + ERRORS)) PROBLEMAS DE SEGURIDAD"
                            echo "🔍 Revisa los detalles en 'Test Results' después de que termine el pipeline"
                        else
                            echo "✅ NO SE ENCONTRARON PROBLEMAS DE SEGURIDAD CRÍTICOS"
                        fi
                        
                        echo "================================================="
                        echo ""
                        echo "📄 CONTENIDO COMPLETO DEL REPORTE XML:"
                        echo "================================================="
                        cat results.xml
                        echo "================================================="
                        
                    else
                        echo "❌ No se pudo procesar results.xml"
                        echo "Archivos presentes en el directorio:"
                        ls -la
                    fi
                '''
            }
        }
    }
    
    post {
        always {
            echo "📁 Archivando resultados..."
            
            // Publicar resultados de pruebas
            script {
                if (fileExists('results.xml')) {
                    try {
                        publishTestResults testResultsPattern: 'results.xml'
                        echo "✅ Resultados publicados en Jenkins Test Results"
                        echo "🔗 Ve al sidebar izquierdo y busca 'Test Result' para ver los detalles"
                    } catch (Exception e) {
                        echo "⚠️ Error al publicar resultados: ${e.getMessage()}"
                        echo "Pero el archivo results.xml se guardará como artifact"
                    }
                } else {
                    echo "⚠️ No se encontró results.xml para publicar"
                }
            }
            
            // Archivar el archivo results.xml como artifact
            archiveArtifacts artifacts: 'results.xml', allowEmptyArchive: true, fingerprint: true
            
            echo ""
            echo "📋 CÓMO VER LOS RESULTADOS EN JENKINS:"
            echo "1. 🔗 'Test Result' en el sidebar izquierdo (si está disponible)"
            echo "2. 📁 'Build Artifacts' para descargar results.xml"
            echo "3. 📜 'Console Output' para ver este resumen completo"
        }
        
        success {
            echo ""
            echo "🎉 ¡PIPELINE COMPLETADO EXITOSAMENTE!"
            echo "✅ El análisis de seguridad de Checkov ha terminado"
            echo "📊 Revisa los resultados arriba o en 'Test Results'"
        }
        
        failure {
            echo ""
            echo "❌ PIPELINE FALLÓ"
            echo "🔍 Revisa los logs de 'Console Output' para ver el error específico"
            echo "🛠️ Problemas comunes:"
            echo "   - Docker no está disponible en Jenkins"
            echo "   - Permisos de archivos"
            echo "   - Archivos de proyecto no encontrados"
        }
        
        unstable {
            echo ""
            echo "⚠️ PIPELINE COMPLETADO CON ADVERTENCIAS"
            echo "🔍 Se encontraron problemas de seguridad - revisa 'Test Results'"
        }
    }
}
