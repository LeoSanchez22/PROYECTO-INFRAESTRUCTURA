# Academic Scheduler Monitoring

This directory contains the monitoring setup for the academic scheduler platform, including:

1. Grafana configuration for dashboards and visualization
2. CloudWatch integration for metrics and logs
3. Test load generator for simulating application activity

## Setup Instructions

### 1. Configure Grafana

```bash
# Start Grafana container
cd monitoring
docker-compose up -d
```

Access Grafana at http://localhost:3000 with:
- Username: admin
- Password: admintest123

### 2. Configure AWS Credentials

Copy the .env-example file and add your AWS credentials:

```bash
cp .env-example .env
```

Edit the .env file with your AWS credentials:
```
AWS_ACCESS_KEY_ID=your_access_key_here
AWS_SECRET_ACCESS_KEY=your_secret_key_here
AWS_REGION=us-east-1
```

### 3. Run Test Load Generator

The test load generator can run in two modes:

#### Local Mode (Console Output)

This mode runs without sending data to CloudWatch - useful for initial testing:

```bash
# Set LOCAL_MODE=true in .env file
npm run start-local
```

#### CloudWatch Mode

This mode sends all metrics and logs to CloudWatch:

```bash
# Set LOCAL_MODE=false in .env file
npm start
```

## Components

### Grafana Dashboards

Pre-configured dashboards include:
- Connection Monitoring
- Resource Management
- Error Management
- API Request Monitoring

### Test Load Generator

Simulates:
- HTTP API requests (GET, POST, PUT, PATCH, DELETE)
- CPU and memory usage
- User connections/sessions
- Error scenarios

### CloudWatch Integration

Logs are organized into:
- /academic-scheduler/api
- /academic-scheduler/connection
- /academic-scheduler/resource
- /academic-scheduler/error

## Troubleshooting

If dashboards show "No Data":
1. Verify AWS credentials are correct
2. Check that test load generator is running in CloudWatch mode
3. Ensure the CloudWatch data source in Grafana is configured correctly
4. Wait a few minutes for data to appear (CloudWatch has some delay)

# Monitoring Setup for Academic Scheduler Platform

This directory contains the configuration for Grafana and CloudWatch integration to monitor the academic scheduler platform.

## Features

- Real-time monitoring of system metrics
- Connection handling metrics (concurrent users, connection status)
- RAM resource management metrics
- Error tracking and alerts
- HTTP REST API usage metrics (POST, PUT, PATCH, DELETE)
- Pre-configured dashboards

## Setup Instructions

1. Copy the `.env-example` file to `.env` and fill in your credentials:
   ```
   cp .env-example .env
   ```

2. Edit the `.env` file with your AWS credentials and preferred Grafana admin password.

3. Start the Grafana container:
   ```
   docker-compose up -d
   ```

4. Access Grafana at http://localhost:3000

## Dashboard Information

The pre-configured dashboard includes:

- **Connection Monitoring**: Tracks concurrent users and connection status
- **Resource Management**: Monitors RAM utilization and memory usage over time
- **Error Management**: Displays Lambda errors, error type distribution, and 5XX errors
- **HTTP REST API Usage**: Shows API method usage and latency by method

## Log Structure

CloudWatch logs are structured to capture:

1. Connection events
2. Resource utilization
3. Error events with stack traces
4. API request details

## Queries

Example queries for common monitoring tasks:

### Error Rate Analysis
```
filter @message like "ERROR"
| stats count(*) as errorCount by bin(5m)
```

### Resource Usage Trends
```
filter @message like "MEMORY"
| stats avg(memoryUsedMB) as avgMemory by bin(15m)
```

### API Performance
```
filter httpMethod in ["POST", "PUT", "PATCH", "DELETE"]
| stats avg(duration) as avgLatency by httpMethod, resourcePath
| sort avgLatency desc
```

