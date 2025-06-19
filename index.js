// AWS Lambda function handler for academic schedule generation
// Integrates with S3 for file storage and DynamoDB for execution history

const AWS = require('aws-sdk');
const { v4: uuidv4 } = require('uuid');
const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

// Initialize AWS services
const s3 = new AWS.S3();
const dynamoDB = new AWS.DynamoDB.DocumentClient();

// Environment variables
const S3_BUCKET_NAME = process.env.S3_BUCKET_NAME;
const DYNAMODB_TABLE = process.env.DYNAMODB_TABLE;

exports.handler = async (event, context) => {
    // Generate a unique execution ID
    const executionId = uuidv4();
    const timestamp = new Date().toISOString();
    const userId = event.userId || 'anonymous';
    
    // Local paths for generated files
    const tempDir = '/tmp';
    const pythonScriptPath = path.join(tempDir, 'generated_script.py');
    
    let status = 'SUCCESS';
    let errorMessage = null;
    let s3Location = null;
    
    try {
        console.log('Starting schedule generation process');
        
        // This is where your Selenium script would run
        // For now, we're just generating a simple Hello World Python script
        const pythonScript = `
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
        
        // Write the generated Python script to a temporary file
        fs.writeFileSync(pythonScriptPath, pythonScript);
        
        // Execute the Python script (in a real scenario)
        // const output = execSync(`python ${pythonScriptPath}`).toString();
        // console.log('Script execution output:', output);
        
        // Upload the file to S3
        const s3Key = `schedules/${userId}/${timestamp}-${executionId}.py`;
        await s3.putObject({
            Bucket: S3_BUCKET_NAME,
            Key: s3Key,
            Body: fs.readFileSync(pythonScriptPath),
            ContentType: 'text/plain'
        }).promise();
        
        s3Location = `s3://${S3_BUCKET_NAME}/${s3Key}`;
        console.log(`File uploaded to S3: ${s3Location}`);
        
    } catch (error) {
        status = 'FAILURE';
        errorMessage = error.message;
        console.error('Error in schedule generation:', error);
    }
    
    // Record execution in DynamoDB
    try {
        const dynamoItem = {
            ExecutionId: executionId,
            Timestamp: timestamp,
            UserId: userId,
            Status: status,
            S3Location: s3Location,
            ErrorMessage: errorMessage
        };
        
        await dynamoDB.put({
            TableName: DYNAMODB_TABLE,
            Item: dynamoItem
        }).promise();
        
        console.log('Execution recorded in DynamoDB:', dynamoItem);
    } catch (dbError) {
        console.error('Error recording to DynamoDB:', dbError);
    }
    
    // Return the result
    return {
        statusCode: status === 'SUCCESS' ? 200 : 500,
        body: JSON.stringify({
            executionId,
            timestamp,
            status,
            s3Location,
            errorMessage
        })
    };
};
