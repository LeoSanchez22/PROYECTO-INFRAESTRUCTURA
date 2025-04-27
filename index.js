/**
 * Basic AWS Lambda function
 * This function logs a message to CloudWatch and returns a success response
 */
exports.handler = async (event, context) => {
  // Log the received event
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
  
  // Process your data here
  const timestamp = new Date().toISOString();
  console.log(`Function executed successfully at ${timestamp}`);
  
  // Return a success response
  const response = {
    statusCode: 200,
    body: JSON.stringify({
      message: 'Function executed successfully',
      timestamp: timestamp,
    }),
  };
  
  return response;
};

