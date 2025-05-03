/**
 * AWS Lambda function that handles S3 events and stores data in DynamoDB
 * This function processes S3 object creation events and stores metadata in DynamoDB
 */
const AWS = require('aws-sdk');
const s3 = new AWS.S3();
const dynamoDB = new AWS.DynamoDB.DocumentClient();
const crypto = require('crypto');

// Get environment variables or set defaults
const TABLE_NAME = process.env.DYNAMODB_TABLE || 'data-table-default';
const MAX_FILE_SIZE = parseInt(process.env.MAX_FILE_SIZE || '10485760', 10); // 10MB default

/**
 * Main Lambda handler function
 */
exports.handler = async (event, context) => {
  try {
    console.log('Event received:', JSON.stringify(event, null, 2));
    
    // Log the Lambda function context
    console.log('Context:', JSON.stringify({
      functionName: context.functionName,
      functionVersion: context.functionVersion,
      invokedFunctionArn: context.invokedFunctionArn,
      memoryLimitInMB: context.memoryLimitInMB,
      awsRequestId: context.awsRequestId,
      logGroupName: context.logGroupName,
      logStreamName: context.logStreamName,
    }, null, 2));
    
    // Process each S3 event record
    const results = await Promise.allSettled(
      event.Records.map(record => processS3Event(record))
    );
    
    // Analyze results
    const successful = results.filter(r => r.status === 'fulfilled').length;
    const failed = results.filter(r => r.status === 'rejected').length;
    
    // Log failures if any
    results
      .filter(r => r.status === 'rejected')
      .forEach((r, i) => console.error(`Error in record ${i}:`, r.reason));
    
    // Return a response
    return {
      statusCode: failed > 0 ? 500 : 200,
      body: JSON.stringify({
        message: `Processed ${successful} events successfully, ${failed} failed.`,
        timestamp: new Date().toISOString(),
      }),
    };
  } catch (error) {
    console.error('Error in Lambda handler:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({
        message: 'Error executing Lambda function',
        error: error.message,
        timestamp: new Date().toISOString(),
      }),
    };
  }
};

/**
 * Process a single S3 event record
 * @param {Object} record - S3 event record
 * @returns {Promise}
 */
async function processS3Event(record) {
  // Validate record is an S3 event
  if (record.eventSource !== 'aws:s3') {
    throw new Error(`Unsupported event source: ${record.eventSource}`);
  }

  // Extract bucket and key from the record
  const bucket = record.s3.bucket.name;
  const key = decodeURIComponent(record.s3.object.key.replace(/\+/g, ' '));
  const size = record.s3.object.size;
  const eventTime = record.eventTime;
  const eventName = record.eventName;
  
  console.log(`Processing S3 event ${eventName} for ${bucket}/${key}`);
  
  // Check if file size is not too large
  if (size > MAX_FILE_SIZE) {
    console.warn(`File size (${size} bytes) exceeds maximum allowed size (${MAX_FILE_SIZE} bytes)`);
    // Still process metadata but don't download the object
    return storeDynamoDBRecord(bucket, key, { 
      fileSize: size,
      eventTime,
      eventName,
      tooLarge: true 
    });
  }
  
  // Get object metadata from S3
  const headParams = {
    Bucket: bucket,
    Key: key
  };
  
  const metadata = await s3.headObject(headParams).promise();
  console.log('Object metadata:', metadata);
  
  // For certain file types, we might want to read the actual content
  // This is just an example for text files, adjust based on your needs
  let content = null;
  const contentType = metadata.ContentType || '';
  
  if (contentType.startsWith('text/') && size < 1048576) { // 1MB limit for text files
    const getParams = {
      Bucket: bucket,
      Key: key
    };
    
    const data = await s3.getObject(getParams).promise();
    content = data.Body.toString('utf-8');
    console.log(`File content length: ${content.length} characters`);
  }
  
  // Store record in DynamoDB
  return storeDynamoDBRecord(bucket, key, {
    fileSize: size,
    eventTime,
    eventName,
    contentType: metadata.ContentType,
    lastModified: metadata.LastModified.toISOString(),
    metadata: metadata.Metadata || {},
    contentSample: content ? content.substring(0, 1000) : null
  });
}

/**
 * Store file metadata in DynamoDB
 * @param {string} bucket - S3 bucket name
 * @param {string} key - S3 object key
 * @param {Object} details - Additional details to store
 * @returns {Promise}
 */
async function storeDynamoDBRecord(bucket, key, details) {
  // Generate a unique ID
  const id = crypto.createHash('md5').update(`${bucket}:${key}:${details.eventTime}`).digest('hex');
  
  const item = {
    id: id,
    bucket: bucket,
    key: key,
    timestamp: new Date().toISOString(),
    ...details
  };
  
  const params = {
    TableName: TABLE_NAME,
    Item: item
  };
  
  console.log('Storing item in DynamoDB:', JSON.stringify(item, null, 2));
  await dynamoDB.put(params).promise();
  console.log(`Successfully stored record for ${bucket}/${key} with ID ${id}`);
  
  return id;
}
