const AWS = require('aws-sdk');
const axios = require('axios');
const crypto = require('crypto');

// Configure AWS SDK
AWS.config.update({
  region: process.env.AWS_REGION || 'us-east-1',
  credentials: new AWS.Credentials({
    accessKeyId: process.env.AWS_ACCESS_KEY_ID || 'your_access_key',
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY || 'your_secret_key'
  })
});

// Initialize CloudWatch Logs
const cloudWatchLogs = new AWS.CloudWatchLogs();
const cloudWatch = new AWS.CloudWatch();

// Configuration
const API_ENDPOINT = process.env.API_ENDPOINT || 'http://localhost:8080';
const LOG_GROUP_NAME = '/academic-scheduler';
const LOG_STREAMS = {
  connection: `${LOG_GROUP_NAME}/connection`,
  resource: `${LOG_GROUP_NAME}/resource`,
  error: `${LOG_GROUP_NAME}/error`,
  api: `${LOG_GROUP_NAME}/api`
};

// Ensure log groups and streams exist
async function setupLogging() {
  try {
    // Create log group if it doesn't exist
    try {
      await cloudWatchLogs.createLogGroup({ logGroupName: LOG_GROUP_NAME }).promise();
      console.log(`Created log group: ${LOG_GROUP_NAME}`);
    } catch (error) {
      if (error.code !== 'ResourceAlreadyExistsException') {
        throw error;
      }
    }

    // Create log streams if they don't exist
    for (const streamName of Object.values(LOG_STREAMS)) {
      try {
        await cloudWatchLogs.createLogStream({
          logGroupName: LOG_GROUP_NAME,
          logStreamName: streamName.split('/')[2]
        }).promise();
        console.log(`Created log stream: ${streamName}`);
      } catch (error) {
        if (error.code !== 'ResourceAlreadyExistsException') {
          throw error;
        }
      }
    }
  } catch (error) {
    console.error('Error setting up logging:', error);
  }
}

// Helper function to log to CloudWatch
async function logToCloudWatch(logStream, message) {
  try {
    const params = {
      logGroupName: LOG_GROUP_NAME,
      logStreamName: logStream.split('/')[2],
      logEvents: [
        {
          message: JSON.stringify(message),
          timestamp: Date.now()
        }
      ]
    };

    // Get the sequence token if the stream already has events
    try {
      const streams = await cloudWatchLogs.describeLogStreams({
        logGroupName: LOG_GROUP_NAME,
        logStreamNamePrefix: logStream.split('/')[2]
      }).promise();
      
      if (streams.logStreams[0] && streams.logStreams[0].uploadSequenceToken) {
        params.sequenceToken = streams.logStreams[0].uploadSequenceToken;
      }
    } catch (error) {
      console.error('Error getting sequence token:', error);
    }

    await cloudWatchLogs.putLogEvents(params).promise();
    console.log(`Logged to ${logStream}: ${JSON.stringify(message)}`);
  } catch (error) {
    console.error(`Error logging to ${logStream}:`, error);
  }
}

// Helper function to put custom metrics to CloudWatch
async function putCustomMetric(metricName, value, unit = 'Count', dimensions = []) {
  try {
    const params = {
      MetricData: [
        {
          MetricName: metricName,
          Dimensions: dimensions,
          Unit: unit,
          Value: value,
          Timestamp: new Date()
        }
      ],
      Namespace: 'AcademicScheduler'
    };

    await cloudWatch.putMetricData(params).promise();
    console.log(`Published metric: ${metricName} = ${value} ${unit}`);
  } catch (error) {
    console.error(`Error publishing metric ${metricName}:`, error);
  }
}

// Generate a random user ID
function generateUserId() {
  return `user_${Math.floor(Math.random() * 1000)}`;
}

// Generate a random session ID
function generateSessionId() {
  return crypto.randomBytes(16).toString('hex');
}

// Simulate CPU-intensive operation
function simulateCpuLoad(duration = 100) {
  const startTime = Date.now();
  while (Date.now() - startTime < duration) {
    // Calculate prime numbers or perform some CPU-intensive operation
    let primes = [];
    for (let i = 0; i < 1000; i++) {
      let isPrime = true;
      for (let j = 2; j < i; j++) {
        if (i % j === 0) {
          isPrime = false;
          break;
        }
      }
      if (isPrime) {
        primes.push(i);
      }
    }
  }
  return primes.length;
}

// Simulate memory allocation
const memoryBlocks = [];
function simulateMemoryUsage(sizeInMB = 10) {
  const bytesPerMB = 1024 * 1024;
  const buffer = Buffer.alloc(sizeInMB * bytesPerMB);
  
  // Fill buffer with random data
  for (let i = 0; i < buffer.length; i += 4096) {
    buffer.write(crypto.randomBytes(20).toString('hex'), i);
  }
  
  memoryBlocks.push(buffer);
  
  // Keep the last 10 buffers to simulate memory usage
  if (memoryBlocks.length > 10) {
    memoryBlocks.shift();
  }
  
  return process.memoryUsage();
}

// Simulate HTTP requests
async function simulateHttpRequest() {
  const methods = ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'];
  const method = methods[Math.floor(Math.random() * methods.length)];
  const userId = generateUserId();
  const resourcePath = `/api/schedules/${Math.floor(Math.random() * 100)}`;
  const startTime = Date.now();
  
  try {
    // Log API request
    await logToCloudWatch(LOG_STREAMS.api, {
      timestamp: new Date().toISOString(),
      level: 'info',
      event_type: 'api',
      request_id: crypto.randomBytes(8).toString('hex'),
      http_method: method,
      resource_path: resourcePath,
      status_code: 200,
      duration: 0, // Will be updated after request
      user_id: userId,
      ip_address: `192.168.1.${Math.floor(Math.random() * 255)}`,
      request_size: Math.floor(Math.random() * 1000),
      response_size: 0, // Will be updated after request
      message: `${method} request to ${resourcePath}`
    });

    // Simulate the request (not actually making it)
    let response;
    if (Math.random() < 0.9) {  // 90% success rate
      // Success case
      const responseSize = Math.floor(Math.random() * 5000);
      const duration = Math.floor(Math.random() * 500);
      
      // Log successful API request completion
      await logToCloudWatch(LOG_STREAMS.api, {
        timestamp: new Date().toISOString(),
        level: 'info',
        event_type: 'api',
        request_id: crypto.randomBytes(8).toString('hex'),
        http_method: method,
        resource_path: resourcePath,
        status_code: 200,
        duration: duration,
        user_id: userId,
        ip_address: `192.168.1.${Math.floor(Math.random() * 255)}`,
        request_size: Math.floor(Math.random() * 1000),
        response_size: responseSize,
        message: `${method} request to ${resourcePath} completed successfully`
      });
      
      // Put API metrics
      await putCustomMetric('APILatency', duration, 'Milliseconds', [
        { Name: 'Method', Value: method },
        { Name: 'ResourcePath', Value: resourcePath }
      ]);
      
      await putCustomMetric('APIRequests', 1, 'Count', [
        { Name: 'Method', Value: method },
        { Name: 'StatusCode', Value: '200' }
      ]);
      
    } else {
      // Error case
      const errorTypes = ['ValidationError', 'NotFoundError', 'AuthorizationError', 'ServerError'];
      const errorType = errorTypes[Math.floor(Math.random() * errorTypes.length)];
      const statusCode = errorType === 'ServerError' ? 500 : 400;
      
      // Log error
      await logToCloudWatch(LOG_STREAMS.error, {
        timestamp: new Date().toISOString(),
        level: 'error',
        event_type: 'error',
        error_code: statusCode,
        error_type: errorType,
        service: 'scheduler-api',
        request_id: crypto.randomBytes(8).toString('hex'),
        user_id: userId,
        stack_trace: `Error: ${errorType} at processRequest (api.js:42:5)`,
        message: `Error processing ${method} request to ${resourcePath}: ${errorType}`
      });
      
      // Put error metrics
      await putCustomMetric('ErrorCount', 1, 'Count', [
        { Name: 'ErrorType', Value: errorType },
        { Name: 'Method', Value: method }
      ]);
      
      await putCustomMetric('APIRequests', 1, 'Count', [
        { Name: 'Method', Value: method },
        { Name: 'StatusCode', Value: statusCode.toString() }
      ]);
    }
    
  } catch (error) {
    console.error('Error simulating HTTP request:', error);
  }
}

// Simulate user connections
async function simulateUserConnection() {
  const userId = generateUserId();
  const sessionId = generateSessionId();
  const sessionDuration = Math.floor(Math.random() * 300) + 60; // 1-5 minutes
  
  try {
    // Log connection start
    await logToCloudWatch(LOG_STREAMS.connection, {
      timestamp: new Date().toISOString(),
      level: 'info',
      event_type: 'connection',
      connection_id: sessionId,
      user_id: userId,
      ip_address: `192.168.1.${Math.floor(Math.random() * 255)}`,
      user_agent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      status: 'active',
      session_duration: 0,
      message: `User ${userId} connected`
    });
    
    // Put active connection metric
    await putCustomMetric('ActiveConnections', 1, 'Count');
    
    // Schedule disconnect after session duration
    setTimeout(async () => {
      await logToCloudWatch(LOG_STREAMS.connection, {
        timestamp: new Date().toISOString(),
        level: 'info',
        event_type: 'connection',
        connection_id: sessionId,
        user_id: userId,
        ip_address: `192.168.1.${Math.floor(Math.random() * 255)}`,
        user_agent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        status: 'disconnected',
        session_duration: sessionDuration,
        message: `User ${userId} disconnected after ${sessionDuration} seconds`
      });
      
      // Decrement active connection metric
      await putCustomMetric('ActiveConnections', -1, 'Count');
      
    }, sessionDuration * 1000);
    
  } catch (error) {
    console.error('Error simulating user connection:', error);
  }
}

// Simulate resource usage
async function simulateResourceUsage() {
  try {
    // Simulate CPU usage
    const cpuIntensity = Math.floor(Math.random() * 100) + 20; // 20-120ms
    const cpuOps = simulateCpuLoad(cpuIntensity);
    
    // Simulate memory usage
    const memorySize = Math.floor(Math.random() * 5) + 1; // 1-5 MB
    const memoryUsage = simulateMemoryUsage(memorySize);
    
    // Log resource metrics
    await logToCloudWatch(LOG_STREAMS.resource, {
      timestamp: new Date().toISOString(),
      level: 'info',
      event_type: 'resource',
      service: 'scheduler-api',
      instance_id: 'i-' + crypto.randomBytes(8).toString('hex'),
      memory_total: Math.round(memoryUsage.heapTotal / (1024 * 1024)),
      memory_used: Math.round(memoryUsage.heapUsed / (1024 * 1024)),
      cpu_percent: Math.floor(Math.random() * 80) + 10, // Simulated CPU %
      disk_used_percent: Math.floor(Math.random() * 30) + 40, // Simulated disk usage 40-70%
      message: `Resource usage snapshot`
    });
    
    // Put memory metrics
    await putCustomMetric('MemoryUsage', memoryUsage.heapUsed / (1024 * 1024), 'Megabytes');
    
    // Put CPU metrics
    await putCustomMetric('CPUUtilization', Math.floor(Math.random() * 80) + 10, 'Percent');
    
  } catch (error) {
    console.error('Error simulating resource usage:', error);
  }
}

// Main function to run simulations
async function runSimulations() {
  // Setup logging first
  await setupLogging();
  
  // Run continuous simulations
  setInterval(() => {
    // Simulate HTTP requests (1-5 per interval)
    const requestCount = Math.floor(Math.random() * 5) + 1;
    for (let i = 0; i < requestCount; i++) {
      simulateHttpRequest();
    }
    
    // Simulate resource usage
    simulateResourceUsage();
    
  }, 5000); // Every 5 seconds
  
  // Simulate user connections (1 every 10-30 seconds)
  setInterval(() => {
    simulateUserConnection();
  }, Math.floor(Math.random() * 20000) + 10000);
  
  console.log('Test load generator started');
}

// Run the simulation
runSimulations().catch(error => {
  console.error('Error starting simulations:', error);
});

