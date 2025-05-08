# Schedule Generator Docker Container

This directory contains the Docker configuration for the schedule generator application.

## Overview

The schedule generator is a Python application that uses Selenium to automate the generation of schedules. It currently implements a simple "Hello World" example, which will be replaced with the actual schedule generation logic in the future.

## Components

- `Dockerfile`: Defines the container image with Python, Chrome, and necessary dependencies
- `requirements.txt`: Lists Python package dependencies
- `schedule_generator.py`: Main Python script that runs the schedule generation process

## Building and Testing Locally

To build and test the Docker image locally:

```bash
# Build the Docker image
docker build -t schedule-generator .

# Run the Docker image locally
docker run -e S3_BUCKET=my-test-bucket -e DYNAMODB_TABLE=my-test-table schedule-generator
```

## Environment Variables

The application uses the following environment variables:

- `S3_BUCKET`: Name of the S3 bucket to store generated PDFs
- `DYNAMODB_TABLE`: Name of the DynamoDB table to store schedule history
- `ENVIRONMENT`: Deployment environment (dev, staging, prod)

## AWS Integration

When deployed to AWS:

1. The Docker image is stored in Amazon ECR
2. The container runs in AWS Fargate
3. Generated schedules are stored in Amazon S3
4. Schedule history is recorded in Amazon DynamoDB

## Development Notes

- The current implementation is a placeholder that generates a simple text file
- In the future, this will be replaced with actual schedule generation logic
- Selenium is configured to run in headless mode for server environments