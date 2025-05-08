#!/bin/bash
# create_lambda_packages.sh

# Create main Lambda function package
cd lambda_function
zip -j ../lambda_function.zip index.js
cd ..

# Create ECS trigger Lambda function package
cd lambda_trigger_ecs
zip -j ../lambda_trigger_ecs.zip index.js
cd ..

