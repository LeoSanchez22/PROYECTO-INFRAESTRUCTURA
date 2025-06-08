const crypto = require('crypto');
// Import AWS SDK v3 CloudWatch client
const { CloudWatchClient, PutMetricDataCommand } = require('@aws-sdk/client-cloudwatch');

// AWS CloudWatch configuration
const CLOUDWATCH_REGION = process.env.AWS_REGION || 'us-east-1';
const CLOUDWATCH_NAMESPACE = 'AcademicScheduler';
const ENVIRONMENT = process.env.ENVIRONMENT || 'development';

// Create CloudWatch client
const cloudWatchClient = new CloudWatchClient({ region: CLOUDWATCH_REGION });

// Configuration
const API_ENDPOINT = process.env.API_ENDPOINT || 'http://localhost:8080';

// Simulated metrics storage
const metrics = {
  apiRequests: {},
  errors: {},
  connections: {
    active: 0,
    total: 0
  },
  resources: {
    cpu: [],
    memory: []
  }
};

// CloudWatch metrics batch
let metricDataBatch = [];

// ANSI color codes for console output
const colors = {
  reset: "\x1b[0m",
  bright: "\x1b[1m",
  red: "\x1b[31m",
  green: "\x1b[32m",
  yellow: "\x1b[33m",
  blue: "\x1b[34m",
  magenta: "\x1b[35m",
  cyan: "\x1b[36m"
};

// Helper function to log with color
function colorLog(color, prefix, message) {
  console.log(`${color}${prefix}${colors.reset} ${message}`);
}

// Helper function to add a metric to the CloudWatch batch
async function addMetricToBatch(metricName, value, unit = 'Count', dimensions = []) {
  // Add standard dimensions
  const standardDimensions = [
    { Name: 'Environment', Value: ENVIRONMENT },
    { Name: 'Service', Value: 'AcademicSchedulerAPI' }
  ];
  
  // Combine with custom dimensions
  const allDimensions = [
    ...standardDimensions,
    ...dimensions
  ];

  // Add metric to batch
  metricDataBatch.push({
    MetricName: metricName,
    Dimensions: allDimensions,
    Unit: unit,
    Value: value,
    Timestamp: new Date()
  });
}

// Send metrics batch to CloudWatch
async function sendMetricBatch() {
  if (metricDataBatch.length === 0) {
    return;
  }

  try {
    const command = new PutMetricDataCommand({
      Namespace: CLOUDWATCH_NAMESPACE,
      MetricData: metricDataBatch
    });

    colorLog(colors.cyan, '[CLOUDWATCH]', `Sending batch of ${metricDataBatch.length} metrics to CloudWatch`);
    await cloudWatchClient.send(command);
    colorLog(colors.cyan, '[CLOUDWATCH]', 'Successfully sent metrics to CloudWatch');
    
    // Clear batch after successful send
    metricDataBatch = [];
  } catch (error) {
    colorLog(colors.red, '[CLOUDWATCH ERROR]', `Failed to send metrics to CloudWatch: ${error.message}`);
  }
}

// Helper function to simulate metrics logging and send to CloudWatch
function logMetric(category, name, value, dimensions = {}) {
  const timestamp = new Date().toISOString();
  const dimensionStr = Object.entries(dimensions)
    .map(([k, v]) => `${k}=${v}`)
    .join(', ');
  
  // Log to console
  colorLog(
    colors.cyan, 
    `[METRIC]`, 
    `${timestamp} | ${category}.${name} = ${value} ${dimensionStr ? `(${dimensionStr})` : ''}`
  );

  // Convert dimensions object to CloudWatch dimensions array
  const dimensionsArray = Object.entries(dimensions).map(([Name, Value]) => ({ Name, Value }));
  
  // Add to CloudWatch batch
  let unit = 'Count';
  if (name === 'latency' || name === 'duration') unit = 'Milliseconds';
  if (name === 'memory') unit = 'Megabytes';
  if (name === 'cpu') unit = 'Percent';
  
  // Add to CloudWatch batch with appropriate metric name
  addMetricToBatch(`${category.charAt(0).toUpperCase() + category.slice(1)}_${name}`, value, unit, dimensionsArray);
}

// Helper function to log events
function logEvent(stream, data) {
  const color = {
    'api': colors.green,
    'connection': colors.blue,
    'resource': colors.yellow,
    'error': colors.red
  }[stream] || colors.bright;
  
  const timestamp = new Date().toISOString();
  colorLog(color, `[${stream.toUpperCase()}]`, `${timestamp} | ${JSON.stringify(data)}`);
}

// Generate a random user ID
function generateUserId() {
  return `user_${Math.floor(Math.random() * 1000)}`;
}

// Generate a random session ID
function generateSessionId() {
  return crypto.randomBytes(8).toString('hex');
}

// Simulate CPU-intensive operation
function simulateCpuLoad(duration = 100) {
  const startTime = Date.now();
  let primes = [];
  
  while (Date.now() - startTime < duration) {
    // Calculate prime numbers
    primes = [];
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
function simulateHttpRequest() {
  const methods = ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'];
  const method = methods[Math.floor(Math.random() * methods.length)];
  const userId = generateUserId();
  const resourcePath = `/api/schedules/${Math.floor(Math.random() * 100)}`;
  
  // Log API request start
  logEvent('api', {
    level: 'info',
    event_type: 'api',
    request_id: crypto.randomBytes(8).toString('hex'),
    http_method: method,
    resource_path: resourcePath,
    user_id: userId,
    message: `${method} request to ${resourcePath}`
  });

  // Track API request by method
  if (!metrics.apiRequests[method]) {
    metrics.apiRequests[method] = 0;
  }
  metrics.apiRequests[method]++;

  // Simulate the request (90% success rate)
  if (Math.random() < 0.9) {
    // Success case
    const responseSize = Math.floor(Math.random() * 5000);
    const duration = Math.floor(Math.random() * 500);
    
    // Log successful API request completion
    logEvent('api', {
      level: 'info',
      event_type: 'api',
      request_id: crypto.randomBytes(8).toString('hex'),
      http_method: method,
      resource_path: resourcePath,
      status_code: 200,
      duration: duration,
      user_id: userId,
      response_size: responseSize,
      message: `${method} request to ${resourcePath} completed successfully`
    });
    
    // Log metric
    logMetric('api', 'latency', duration, { method, resourcePath });
    logMetric('api', 'requests', 1, { method, statusCode: '200' });
  } else {
    // Error case
    const errorTypes = ['ValidationError', 'NotFoundError', 'AuthorizationError', 'ServerError'];
    const errorType = errorTypes[Math.floor(Math.random() * errorTypes.length)];
    const statusCode = errorType === 'ServerError' ? 500 : 400;
    
    // Log error
    logEvent('error', {
      level: 'error',
      event_type: 'error',
      error_code: statusCode,
      error_type: errorType,
      service: 'scheduler-api',
      request_id: crypto.randomBytes(8).toString('hex'),
      user_id: userId,
      message: `Error processing ${method} request to ${resourcePath}: ${errorType}`
    });
    
    // Track error by type
    if (!metrics.errors[errorType]) {
      metrics.errors[errorType] = 0;
    }
    metrics.errors[errorType]++;
    
    // Log metrics
    logMetric('error', 'count', 1, { errorType, method });
    logMetric('api', 'requests', 1, { method, statusCode: statusCode.toString() });
  }
}

// Simulate user connections
function simulateUserConnection() {
  const userId = generateUserId();
  const sessionId = generateSessionId();
  const sessionDuration = Math.floor(Math.random() * 300) + 60; // 1-5 minutes
  
  // Increment active connections
  metrics.connections.active++;
  metrics.connections.total++;
  
  // Log connection start
  logEvent('connection', {
    level: 'info',
    event_type: 'connection',
    connection_id: sessionId,
    user_id: userId,
    status: 'active',
    message: `User ${userId} connected`
  });
  
  // Log metric
  logMetric('connection', 'active', metrics.connections.active);
  
  // Schedule disconnect after session duration
  setTimeout(() => {
    // Decrement active connections
    metrics.connections.active--;
    
    // Log disconnect
    logEvent('connection', {
      level: 'info',
      event_type: 'connection',
      connection_id: sessionId,
      user_id: userId,
      status: 'disconnected',
      session_duration: sessionDuration,
      message: `User ${userId} disconnected after ${sessionDuration} seconds`
    });
    
    // Log metric
    logMetric('connection', 'active', metrics.connections.active);
    logMetric('connection', 'duration', sessionDuration, { userId });
    
  }, sessionDuration * 1000);
}

// Simulate resource usage
function simulateResourceUsage() {
  // Simulate CPU usage
  const cpuIntensity = Math.floor(Math.random() * 100) + 20; // 20-120ms
  const cpuOps = simulateCpuLoad(cpuIntensity);
  
  // Simulate memory usage
  const memorySize = Math.floor(Math.random() * 5) + 1; // 1-5 MB
  const memoryUsage = simulateMemoryUsage(memorySize);
  
  // Calculate metrics
  const memoryUsedMB = Math.round(memoryUsage.heapUsed / (1024 * 1024));
  const memoryTotalMB = Math.round(memoryUsage.heapTotal / (1024 * 1024));
  const cpuPercent = Math.floor(Math.random() * 80) + 10; // Simulated CPU %
  
  // Store in metrics history (keep last 100 points)
  metrics.resources.cpu.push(cpuPercent);
  metrics.resources.memory.push(memoryUsedMB);
  
  if (metrics.resources.cpu.length > 100) metrics.resources.cpu.shift();
  if (metrics.resources.memory.length > 100) metrics.resources.memory.shift();
  
  // Log resource metrics
  logEvent('resource', {
    level: 'info',
    event_type: 'resource',
    service: 'scheduler-api',
    memory_total: memoryTotalMB,
    memory_used: memoryUsedMB,
    cpu_percent: cpuPercent,
    message: `Resource usage: CPU ${cpuPercent}%, Memory ${memoryUsedMB}/${memoryTotalMB} MB`
  });
  
  // Log metrics
  logMetric('resource', 'memory', memoryUsedMB, { unit: 'MB' });
  logMetric('resource', 'cpu', cpuPercent, { unit: 'percent' });
}

// Print summary stats periodically
function printStats() {
  console.log('\n' + colors.bright + '='.repeat(80) + colors.reset);
  console.log(colors.bright + '  SUMMARY STATISTICS' + colors.reset);
  console.log(colors.bright + '='.repeat(80) + colors.reset);
  
  // API requests by method
  console.log(colors.green + '  API REQUESTS:' + colors.reset);
  Object.entries(metrics.apiRequests).forEach(([method, count]) => {
    console.log(`    ${method}: ${count}`);
  });
  
  // Errors by type
  console.log(colors.red + '\n  ERRORS:' + colors.reset);
  Object.entries(metrics.errors).forEach(([type, count]) => {
    console.log(`    ${type}: ${count}`);
  });
  
  // Connection stats
  console.log(colors.blue + '\n  CONNECTIONS:' + colors.reset);
  console.log(`    Active: ${metrics.connections.active}`);
  console.log(`    Total: ${metrics.connections.total}`);
  
  // Resource stats
  console.log(colors.yellow + '\n  RESOURCES:' + colors.reset);
  const avgCpu = metrics.resources.cpu.length > 0 
    ? metrics.resources.cpu.reduce((a, b) => a + b, 0) / metrics.resources.cpu.length 
    : 0;
  const avgMem = metrics.resources.memory.length > 0 
    ? metrics.resources.memory.reduce((a, b) => a + b, 0) / metrics.resources.memory.length 
    : 0;
  console.log(`    CPU (avg): ${avgCpu.toFixed(2)}%`);
  console.log(`    Memory (avg): ${avgMem.toFixed(2)} MB`);
  
  console.log(colors.bright + '='.repeat(80) + colors.reset + '\n');
  
  // Send metrics batch to CloudWatch
  sendMetricBatch();
}

// Main function to run simulations
function runSimulations() {
  colorLog(colors.bright, '🚀 [LOAD GENERATOR]', 'Starting test load generator in CLOUDWATCH mode');
  colorLog(colors.bright, '🚀 [LOAD GENERATOR]', `Sending metrics to CloudWatch namespace: ${CLOUDWATCH_NAMESPACE} in region: ${CLOUDWATCH_REGION}`);
  colorLog(colors.bright, '🚀 [LOAD GENERATOR]', `Environment: ${ENVIRONMENT}`);
  
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
  
  // Print stats and send CloudWatch metrics every minute
  setInterval(printStats, 60000);
}

// Run the simulation
runSimulations();

