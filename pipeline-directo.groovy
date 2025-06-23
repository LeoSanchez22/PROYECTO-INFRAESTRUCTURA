pipeline {
    agent any
    
    stages {
        stage('Preparar Workspace') {
            steps {
                echo "Preparando el workspace para análisis de seguridad..."
                sh '''
                    pwd
                    ls -la
                    echo "Verificando que Docker esté disponible..."
                    docker --version
                '''
            }
        }
        
        stage('Ejecutar Checkov') {
            steps {
                echo "Ejecutando análisis de seguridad con Checkov..."
                sh '''
                    echo "Iniciando Checkov scan..."
                    
                    # Tu comando exacto de Checkov
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
                        echo "Primeras líneas del archivo:"
                        head -10 results.xml
                    else
                        echo "❌ ERROR: No se creó el archivo results.xml"
                        exit 1
                    fi
                '''
            }
        }
        
        stage('Mostrar Resultados') {
            steps {
                echo "Procesando y mostrando resultados..."
                sh '''
                    echo "=== ANÁLISIS DE RESULTADOS ==="
                    
                    if [ -f "results.xml" ]; then
                        # Extraer información básica del XML
                        TOTAL_TESTS=$(grep -o 'tests="[0-9]*"' results.xml | head -1 | grep -o '[0-9]*' || echo "0")
                        FAILURES=$(grep -o 'failures="[0-9]*"' results.xml | head -1 | grep -o '[0-9]*' || echo "0")
                        ERRORS=$(grep -o 'errors="[0-9]*"' results.xml | head -1 | grep -o '[0-9]*' || echo "0")
                        
                        echo "📊 RESUMEN DE SEGURIDAD:"
                        echo "   Total de verificaciones: $TOTAL_TESTS"
                        echo "   Fallas encontradas: $FAILURES"
                        echo "   Errores encontrados: $ERRORS"
                        
                        if [ "$FAILURES" -gt 0 ] || [ "$ERRORS" -gt 0 ]; then
                            echo "⚠️  SE ENCONTRARON PROBLEMAS DE SEGURIDAD"
                        else
                            echo "✅ NO SE ENCONTRARON PROBLEMAS DE SEGURIDAD"
                        fi
                        
                        echo "================================="
                        echo ""
                        echo "Contenido completo del archivo results.xml:"
                        cat results.xml
                    else
                        echo "❌ No se pudo procesar results.xml"
                    fi
                '''
            }
        }
    }
    
    post {
        always {
            echo "Limpieza y archivo de resultados..."
            
            // Publicar resultados de pruebas si existe el archivo
            script {
                if (fileExists('results.xml')) {
                    publishTestResults testResultsPattern: 'results.xml'
                    echo "✅ Resultados publicados en Jenkins Test Results"
                } else {
                    echo "⚠️ No se encontró results.xml para publicar"
                }
            }
            
            // Archivar el archivo results.xml
            archiveArtifacts artifacts: 'results.xml', allowEmptyArchive: true, fingerprint: true
        }
        
        success {
            echo "🎉 Pipeline completado exitosamente"
            echo "📋 Revisa los 'Test Results' en el sidebar de Jenkins para ver los detalles"
        }
        
        failure {
            echo "❌ Pipeline falló - revisa los logs arriba para más detalles"
        }
    }
}
