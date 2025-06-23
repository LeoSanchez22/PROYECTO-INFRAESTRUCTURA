# Test Load Generator for Academic Scheduler

This script generates test load and metrics for the academic scheduler application monitoring system.

## Features

- HTTP API request simulation with different methods (GET, POST, PUT, PATCH, DELETE)
- CPU load simulation 
- Memory usage simulation
- Error simulation
- Connection tracking
- CloudWatch logging and metrics

## Setup

1. Install dependencies:
   ```
   npm install
   ```

2. Configure AWS credentials:
   ```
   export AWS_ACCESS_KEY_ID=your_access_key
   export AWS_SECRET_ACCESS_KEY=your_secret_key
   export AWS_REGION=us-east-1
   ```

3. Run the load generator:
   ```
   npm start
   ```

## Generated Metrics

The script generates the following metrics:

- **API Metrics**:
  - Request counts by method
  - Latency by method
  - Error rates
  
- **Resource Metrics**:
  - CPU utilization
  - Memory usage
  
- **Connection Metrics**:
  - Active connections
  - Session duration
  
- **Error Metrics**:
  - Error count by type
  - Error count by endpoint

## Log Structure

The script creates logs in CloudWatch with the following structure:

- **/academic-scheduler/api** - API request logs
- **/academic-scheduler/connection** - User connection logs
- **/academic-scheduler/resource** - Resource usage logs
- **/academic-scheduler/error** - Error logs

## Customization

You can customize the test behavior by modifying the variables at the top of the script:

- `API_ENDPOINT` - The target API endpoint
- `LOG_GROUP_NAME` - The CloudWatch log group name

