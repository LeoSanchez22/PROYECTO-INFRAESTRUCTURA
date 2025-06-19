pipeline {
    agent any
    
    environment {
        AWS_ACCESS_KEY_ID = credentials('aws-access-key-id')
        AWS_SECRET_ACCESS_KEY = credentials('aws-secret-access-key')
        AWS_DEFAULT_REGION = 'us-east-1'  // Región de AWS principal
        TERRAFORM_VERSION = '1.5.0'       // Versión de Terraform a utilizar
        // Configuration for Checkov results handling
        CHECKOV_RESULTS_PATH = 'results.xml'
        CHECKOV_REPORT_DIR = 'results'
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
                sh 'git log -1'
                sh 'ls -la'
            }
        }
        
        stage('Setup Environment') {
            steps {
                sh 'echo "Setting up environment..."'
                
                // Instalar Terraform si no está disponible
                sh '''
                    if ! command -v terraform &> /dev/null; then
                        echo "Installing Terraform ${TERRAFORM_VERSION}"
                        wget -q https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip
                        unzip -o terraform_${TERRAFORM_VERSION}_linux_amd64.zip
                        sudo mv terraform /usr/local/bin/
                        rm terraform_${TERRAFORM_VERSION}_linux_amd64.zip
                    fi
                    terraform --version
                    
                    # Instalar AWS CLI si no está disponible
                    if ! command -v aws &> /dev/null; then
                        echo "Installing AWS CLI..."
                        curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
                        unzip -q awscliv2.zip
                        sudo ./aws/install
                        rm -rf aws awscliv2.zip
                    fi
                    aws --version
                '''
            }
        }
        
        stage('Terraform Init and Plan') {
            steps {
                sh '''
                    echo "Running Terraform Init and Plan..."
                    terraform init
                    terraform validate
                    terraform plan -out=tfplan
                '''
            }
        }
        
        stage('Validate Static Files') {
            steps {
                sh '''
                    echo "Validating static files..."
                    if [ -f index.html ]; then
                        echo "✅ index.html exists"
                    else
                        echo "❌ ERROR: index.html not found!"
                        exit 1
                    fi
                    
                    # Verifica si hay otros archivos estáticos (CSS, JS, imágenes)
                    find . -name "*.css" -o -name "*.js" -o -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.gif" | while read file; do
                        echo "Found static file: $file"
                    done
                '''
            }
        }

        stage('Security Scanning') {
            steps {
                echo "Running security scanning with Checkov..."
                
                // Create results directory with proper permissions
                sh 'mkdir -p results'
                
                // Run Checkov with simpler command focused on JUnit output
                sh '''
                    echo "Starting Checkov security scan..."
                    
                    # Basic Checkov command that focuses on generating proper JUnit XML
                    docker run --rm -v $(pwd):/app --workdir /app bridgecrew/checkov \
                        --directory /app \
                        -o junitxml \
                        --output-file-path results.xml \
                        --soft-fail
                    
                    # Verify that the XML file was created successfully
                    if [ -f "results.xml" ]; then
                        echo "✅ Checkov scan completed and results.xml was generated"
                        # Check if file is valid XML
                        if grep -q "<?xml" results.xml && grep -q "</testsuites>" results.xml; then
                            echo "✅ results.xml appears to be valid XML"
                        else
                            echo "⚠️ Warning: results.xml may not be valid XML"
                            # Create a basic valid XML file as fallback
                            echo '<?xml version="1.0" encoding="UTF-8"?><testsuites><testsuite name="Checkov" tests="1"><testcase name="Checkov_Scan" classname="Security"><skipped message="Could not generate valid XML report"/></testcase></testsuite></testsuites>' > results.xml
                        fi
                    else
                        echo "❌ Error: results.xml was not generated"
                        # Create an empty valid XML file for Jenkins to process
                        echo '<?xml version="1.0" encoding="UTF-8"?><testsuites><testsuite name="Checkov" tests="1"><testcase name="Checkov_Scan" classname="Security"><failure message="Failed to run Checkov or generate results"/></testcase></testsuite></testsuites>' > results.xml
                    fi
                    
                    # Run Checkov again for detailed CLI output to include in the report
                    echo "Generating detailed CLI report..."
                    CHECKOV_OUTPUT=$(docker run --rm -v $(pwd):/app --workdir /app bridgecrew/checkov \
                        --directory /app \
                        -o cli \
                        --soft-fail)
                    
                    # Create a detailed HTML report
                    echo "<html><head><title>Checkov Security Scan Results</title>" > results/detailed-report.html
                    echo "<style>body{font-family:Arial,sans-serif;margin:20px;line-height:1.6} h1{color:#2c3e50} h2{color:#3498db} pre{background:#f8f8f8;border:1px solid #ddd;padding:10px;overflow:auto;border-radius:3px} .summary{background:#e7f4ff;padding:10px;border-radius:3px;margin-bottom:20px} .passed{color:#27ae60} .failed{color:#e74c3c}</style>" >> results/detailed-report.html
                    echo "</head><body>" >> results/detailed-report.html
                    echo "<h1>Checkov Security Scan Results</h1>" >> results/detailed-report.html
                    echo "<div class='summary'>" >> results/detailed-report.html
                    echo "<h2>Summary</h2>" >> results/detailed-report.html
                    echo "<p>Scan completed at $(date)</p>" >> results/detailed-report.html
                    
                    # Count passed/failed checks for summary
                    PASSED=$(echo "$CHECKOV_OUTPUT" | grep -c "PASSED" || echo "0")
                    FAILED=$(echo "$CHECKOV_OUTPUT" | grep -c "FAILED" || echo "0")
                    TOTAL=$((PASSED + FAILED))
                    
                    echo "<p><strong>Total checks:</strong> $TOTAL</p>" >> results/detailed-report.html
                    echo "<p><strong class='passed'>Passed checks:</strong> $PASSED</p>" >> results/detailed-report.html
                    echo "<p><strong class='failed'>Failed checks:</strong> $FAILED</p>" >> results/detailed-report.html
                    echo "</div>" >> results/detailed-report.html
                    
                    echo "<h2>Detailed Results</h2>" >> results/detailed-report.html
                    echo "<pre>" >> results/detailed-report.html
                    # Escape HTML characters and add the output
                    echo "$CHECKOV_OUTPUT" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&#39;/g' >> results/detailed-report.html
                    echo "</pre>" >> results/detailed-report.html
                    echo "</body></html>" >> results/detailed-report.html
                    
                    # Create a simple summary file for Jenkins dashboard
                    echo "<h2>Checkov Security Scan Results</h2>" > results/summary.html
                    echo "<p>Scan completed at $(date)</p>" >> results/summary.html
                    echo "<p><strong>Total checks:</strong> $TOTAL</p>" >> results/summary.html
                    echo "<p><strong>Passed checks:</strong> $PASSED</p>" >> results/summary.html
                    echo "<p><strong>Failed checks:</strong> $FAILED</p>" >> results/summary.html
                    echo "<p><a href='detailed-report.html' target='_blank'>View Detailed Report</a></p>" >> results/summary.html
                    echo "<p>JUnit report also available in 'Test Result' view.</p>" >> results/summary.html
                '''
                
                // Display security results summary in the pipeline UI
                publishHTML([
                    allowMissing: true,
                    alwaysLinkToLastBuild: true,
                    keepAll: true,
                    reportDir: 'results',
                    reportFiles: 'summary.html',
                    reportName: 'Security Scan Summary',
                    reportTitles: 'Checkov Results'
                ])
                
                // Display detailed results in a separate report
                publishHTML([
                    allowMissing: true,
                    alwaysLinkToLastBuild: true,
                    keepAll: true,
                    reportDir: 'results',
                    reportFiles: 'detailed-report.html',
                    reportName: 'Detailed Security Report',
                    reportTitles: 'Checkov Detailed Results'
                ])
                
                // Explicitly publish test results as part of the steps
                // This may show up in the build steps directly
                junit(
                    allowEmptyResults: true, 
                    testResults: 'results.xml',
                    healthScaleFactor: 1.0,
                    keepLongStdio: true
                )
                
                // Add an extra script to generate a test summary that will show up in Jenkins
                script {
                    def summary = load("${WORKSPACE}/scripts/generateTestSummary.groovy") || null
                    if (summary) {
                        summary.generateSummary('results.xml', 'Checkov Security Scan')
                    } else {
                        echo "No generateTestSummary.groovy found, skipping test summary generation"
                    }
                }
            }
            post {
                always {
                    // Create a basic test summary file for Jenkins if the script didn't run
                    script {
                        def summaryFile = new File("${WORKSPACE}/results/test-summary.md")
                        if (!summaryFile.exists()) {
                            writeFile file: 'results/test-summary.md', text: """# Checkov Security Scan Results

Check the detailed reports in 'Detailed Security Report' view.

The XML results are available in the 'Test Results' view.
"""
                        }
                    }
                    
                    // Archive the test results
                    archiveArtifacts(
                        artifacts: 'results.xml, results/*.html, results/*.md', 
                        allowEmptyArchive: true,
                        fingerprint: true
                    )
                    
                    // Publish test results again to make sure they appear
                    junit(
                        allowEmptyResults: true, 
                        testResults: 'results.xml',
                        healthScaleFactor: 1.0,
                        keepLongStdio: true
                    )
                    
                    echo '''
                    ========================================
                    CHECKOV RESULTS ARE AVAILABLE IN JENKINS AT:
                    
                    1. Click "Security Scan Summary" in the build page
                    2. Click "Detailed Security Report" for full results
                    3. Check "Test Result" link in the build page
                    
                    NOTE: The "Test Results" link in the sidebar may not 
                    appear until after the first successful run with valid results.
                    ========================================
                    '''
                }
                failure {
                    echo 'Security scanning found issues. Review the results for details.'
                    // Create directory for scripts if it doesn't exist
                    sh 'mkdir -p scripts'
                    
                    // Create a simple Groovy script to generate test summary
                    writeFile file: 'scripts/generateTestSummary.groovy', text: '''
def generateSummary(xmlFile, title) {
    echo "Generating test summary from ${xmlFile}"
    if (fileExists(xmlFile)) {
        def xml = readFile(xmlFile)
        def summary = "# ${title} Results\\n\\n"
        
        if (xml.contains("<failure") || xml.contains("<error")) {
            summary += "⚠️ **Security Issues Found!** Review the detailed report.\\n\\n"
        } else {
            summary += "✅ **No Security Issues Found** - All tests passed!\\n\\n"
        }
        
        writeFile file: 'results/test-summary.md', text: summary
        return true
    } else {
        echo "XML file ${xmlFile} not found"
        return false
    }
}
return this
'''
                    
                    // You can add Slack/Email notifications here for security failures
                }
                success {
                    echo 'Security scanning passed successfully!'
                }
            }
        }
        
        stage('Deploy Infrastructure') {
            steps {
                sh '''
                    echo "Deploying infrastructure with Terraform..."
                    terraform apply -auto-approve tfplan
                '''
            }
        }
        
        stage('Deploy Static Content') {
            steps {
                sh '''
                    echo "Deploying static content to AWS..."
                    # Obtenemos el nombre del bucket de S3 desde outputs de Terraform
                    BUCKET_NAME=$(terraform output -raw frontend_bucket_name || echo "leocorp-frontend-default")
                    
                    # Sincronizamos los archivos estáticos al bucket
                    echo "Syncing static files to S3 bucket: $BUCKET_NAME"
                    
                    # Subir index.html
                    echo "Uploading index.html to S3..."
                    aws s3 cp index.html s3://$BUCKET_NAME/
                    
                    # Subir otros archivos estáticos si existen
                    STATIC_FILES=$(find . -maxdepth 1 -type f \( -name "*.css" -o -name "*.js" -o -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.gif" \))
                    if [ ! -z "$STATIC_FILES" ]; then
                        echo "Uploading additional static files..."
                        for file in $STATIC_FILES; do
                            aws s3 cp $file s3://$BUCKET_NAME/
                        done
                    fi
                    
                    # Invalidamos la caché de CloudFront
                    CLOUDFRONT_ID=$(terraform output -raw cloudfront_distribution_id || echo "")
                    if [ ! -z "$CLOUDFRONT_ID" ]; then
                        echo "Invalidating CloudFront cache for distribution: $CLOUDFRONT_ID"
                        aws cloudfront create-invalidation --distribution-id $CLOUDFRONT_ID --paths "/*"
                    fi
                '''
            }
        }
    }
    
    post {
        always {
            // Archive security scan results before cleaning workspace
            archiveArtifacts(
                artifacts: "${CHECKOV_RESULTS_PATH}, ${CHECKOV_REPORT_DIR}/*.html", 
                allowEmptyArchive: true,
                fingerprint: true
            )
            
            // Publish test results again at pipeline level to ensure visibility
            junit(
                allowEmptyResults: true, 
                testResults: "${CHECKOV_RESULTS_PATH}",
                healthScaleFactor: 1.0,
                keepLongStdio: true
            )
            
            // Display a reminder about where to find security results
            echo '''
            =======================================================
            SECURITY SCANNING RESULTS LOCATION IN JENKINS:
            
            1. In the left sidebar menu, click "Test Results" to see 
               all security checks with pass/fail status
               
            2. In the build details page, click "Test Result" to see
               detailed reports of each security check
               
            3. In the build details page, click "Security Scan Summary"
               for a high-level overview
               
            4. In the project dashboard, look for the "Test Result Trend"
               graph to track security compliance over time
            =======================================================
            '''
            
            // Clean workspace but retain test results
            cleanWs(cleanWhenNotBuilt: false,
                    deleteDirs: true,
                    disableDeferredWipeout: true,
                    patterns: [
                        [pattern: "${CHECKOV_RESULTS_PATH}", type: 'INCLUDE'],
                        [pattern: "${CHECKOV_REPORT_DIR}/**", type: 'INCLUDE']
                    ])
        }
        success {
            echo 'Pipeline ejecutado correctamente!'
            echo 'La infraestructura y el contenido estático han sido desplegados.'
            sh '''
                CLOUDFRONT_DOMAIN=$(terraform output -raw cloudfront_domain_name || echo "")
                if [ ! -z "$CLOUDFRONT_DOMAIN" ]; then
                    echo "El sitio web está disponible en: https://$CLOUDFRONT_DOMAIN"
                fi
            '''
        }
        failure {
            echo 'Pipeline falló. Por favor, revise los logs para más detalles.'
        }
    }
}

