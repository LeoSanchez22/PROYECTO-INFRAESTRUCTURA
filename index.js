// AWS Lambda function handler for academic schedule generation
// Integrates with S3 for file storage and DynamoDB for execution history

const AWS = require('aws-sdk');
const { v4: uuidv4 } = require('uuid');
const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

/**
 * Generates the Python script content for academic schedule
 * @param {string} executionId - Unique execution identifier
 * @param {string} timestamp - ISO timestamp
 * @returns {string} Python script content
 */
function generatePythonScript(executionId, timestamp) {
    return `
# Generated Python script for academic schedule
print("Hello World! This is an automatically generated academic schedule script.")
print("Execution ID: ${executionId}")
print("Timestamp: ${timestamp}")

# Here would be the actual schedule generation logic
class ScheduleGenerator:
    def __init__(self):
        self.courses = []
    
    def add_course(self, course_name, professor, hours):
        self.courses.append({
            "name": course_name,
            "professor": professor,
            "hours": hours
        })
    
    def generate_schedule(self):
        print("Generating academic schedule...")
        for course in self.courses:
            print(f"Course: {course['name']}, Professor: {course['professor']}, Hours: {course['hours']}")
        return "Schedule generated successfully"

# Example usage
if __name__ == "__main__":
    generator = ScheduleGenerator()
    generator.add_course("Mathematics 101", "Dr. Smith", 4)
    generator.add_course("Computer Science", "Prof. Johnson", 3)
    generator.add_course("Physics", "Dr. Brown", 5)
    generator.generate_schedule()
`;
}

/**
 * Writes script content to a file
 * @param {string} filePath - Path where to write the file
 * @param {string} content - Content to write
 */
function writeScriptToFile(filePath, content) {
    fs.writeFileSync(filePath, content);
}

/**
 * Uploads a file to S3
 * @param {Object} s3 - S3 client instance
 * @param {string} bucket - S3 bucket name
 * @param {string} key - S3 object key
 * @param {string} filePath - Local file path to upload
 * @returns {Promise<string>} S3 location URL
 */
async function uploadFileToS3(s3, bucket, key, filePath) {
    const fileContent = fs.readFileSync(filePath);
    
    await s3.putObject({
        Bucket: bucket,
        Key: key,
        Body: fileContent,
        ContentType: 'text/plain'
    }).promise();
    
    return `s3://${bucket}/${key}`;
}

/**
 * Records execution details in DynamoDB
 * @param {Object} dynamoDB - DynamoDB client instance
 * @param {string} tableName - DynamoDB table name
 * @param {Object} executionData - Execution data to record
 * @returns {Promise<void>}
 */
async function recordExecutionInDynamoDB(dynamoDB, tableName, executionData) {
    await dynamoDB.put({
        TableName: tableName,
        Item: executionData
    }).promise();
}

/**
 * Builds the Lambda response object
 * @param {string} status - Execution status ('SUCCESS' or 'FAILURE')
 * @param {Object} data - Response data
 * @returns {Object} Lambda response object
 */
function buildResponse(status, data) {
    return {
        statusCode: status === 'SUCCESS' ? 200 : 500,
        body: JSON.stringify(data)
    };
}

/**
 * Generates S3 key for the file
 * @param {string} userId - User identifier
 * @param {string} timestamp - ISO timestamp
 * @param {string} executionId - Execution identifier
 * @returns {string} S3 key
 */
function generateS3Key(userId, timestamp, executionId) {
    return `schedules/${userId}/${timestamp}-${executionId}.py`;
}

/**
 * Main Lambda handler function
 * @param {Object} event - Lambda event object
 * @param {Object} context - Lambda context object
 * @returns {Promise<Object>} Lambda response
 */
exports.handler = async (event, context) => {
    // Initialize AWS services
    const s3 = new AWS.S3();
    const dynamoDB = new AWS.DynamoDB.DocumentClient();
    
    // Read environment variables
    const S3_BUCKET_NAME = process.env.S3_BUCKET_NAME;
    const DYNAMODB_TABLE = process.env.DYNAMODB_TABLE;
    
    // Generate execution metadata
    const executionId = uuidv4();
    const timestamp = new Date().toISOString();
    const userId = event.userId || 'anonymous';
    
    // File paths
    const tempDir = '/tmp';
    const pythonScriptPath = path.join(tempDir, 'generated_script.py');
    
    let status = 'SUCCESS';
    let errorMessage = null;
    let s3Location = null;
    
    try {
        console.log('Starting schedule generation process');
        
        // Generate Python script content
        const pythonScript = generatePythonScript(executionId, timestamp);
        
        // Write script to file
        writeScriptToFile(pythonScriptPath, pythonScript);
        
        // Generate S3 key and upload file
        const s3Key = generateS3Key(userId, timestamp, executionId);
        s3Location = await uploadFileToS3(s3, S3_BUCKET_NAME, s3Key, pythonScriptPath);
        
        console.log(`File uploaded to S3: ${s3Location}`);
        
    } catch (error) {
        status = 'FAILURE';
        errorMessage = error.message;
        console.error('Error in schedule generation:', error);
    }
    
    // Record execution in DynamoDB
    try {
        const executionData = {
            ExecutionId: executionId,
            Timestamp: timestamp,
            UserId: userId,
            Status: status,
            S3Location: s3Location,
            ErrorMessage: errorMessage
        };
        
        await recordExecutionInDynamoDB(dynamoDB, DYNAMODB_TABLE, executionData);
        console.log('Execution recorded in DynamoDB:', executionData);
    } catch (dbError) {
        console.error('Error recording to DynamoDB:', dbError);
        // Don't change status if the main operation was successful
    }
    
    // Build and return response
    return buildResponse(status, {
        executionId,
        timestamp,
        status,
        s3Location,
        errorMessage
    });
};

// Export functions for testing
module.exports = {
    handler: exports.handler,
    generatePythonScript,
    writeScriptToFile,
    uploadFileToS3,
    recordExecutionInDynamoDB,
    buildResponse,
    generateS3Key
};
