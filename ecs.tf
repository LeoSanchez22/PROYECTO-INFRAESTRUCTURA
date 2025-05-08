# ECS Cluster
resource "aws_ecs_cluster" "schedule_cluster" {
  name = "schedule-generator-cluster-${terraform.workspace}"
  
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
  
  tags = {
    Name        = "ScheduleGeneratorCluster"
    Environment = terraform.workspace
  }
}

# CloudWatch Log Group for ECS tasks
resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/schedule-generator-${terraform.workspace}"
  retention_in_days = 30
  
  tags = {
    Name        = "ScheduleGeneratorLogs"
    Environment = terraform.workspace
  }
}

# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs-task-execution-role-${terraform.workspace}"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
  
  tags = {
    Name        = "ECSTaskExecutionRole"
    Environment = terraform.workspace
  }
}

# Attach the ECS Task Execution Role Policy
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# IAM Role for ECS Task
resource "aws_iam_role" "ecs_task_role" {
  name = "ecs-task-role-${terraform.workspace}"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
  
  tags = {
    Name        = "ECSTaskRole"
    Environment = terraform.workspace
  }
}

# IAM Policy for ECS Task to access S3 and DynamoDB
resource "aws_iam_policy" "ecs_task_policy" {
  name        = "ecs-task-policy-${terraform.workspace}"
  description = "Policy for ECS tasks to access S3 and DynamoDB"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Effect   = "Allow"
        Resource = [
          aws_s3_bucket.schedule_pdfs.arn,
          "${aws_s3_bucket.schedule_pdfs.arn}/*"
        ]
      },
      {
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Effect   = "Allow"
        Resource = aws_dynamodb_table.schedule_history.arn
      }
    ]
  })
}

# Attach the policy to the ECS Task Role
resource "aws_iam_role_policy_attachment" "ecs_task_policy_attachment" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.ecs_task_policy.arn
}

# ECS Task Definition
resource "aws_ecs_task_definition" "schedule_generator" {
  family                   = "schedule-generator-${terraform.workspace}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.fargate_cpu
  memory                   = var.fargate_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  
  container_definitions = jsonencode([
    {
      name      = "schedule-generator"
      image     = "${aws_ecr_repository.schedule_generator.repository_url}:latest"
      essential = true
      
      environment = [
        {
          name  = "ENVIRONMENT"
          value = terraform.workspace
        },
        {
          name  = "S3_BUCKET"
          value = aws_s3_bucket.schedule_pdfs.id
        },
        {
          name  = "DYNAMODB_TABLE"
          value = aws_dynamodb_table.schedule_history.name
        }
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
      
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
          protocol      = "tcp"
        }
      ]
    }
  ])
  
  tags = {
    Name        = "ScheduleGeneratorTask"
    Environment = terraform.workspace
  }
}

# Security Group for ECS Tasks
resource "aws_security_group" "ecs_tasks" {
  name        = "ecs-tasks-sg-${terraform.workspace}"
  description = "Allow outbound traffic from ECS tasks"
  vpc_id      = aws_vpc.main.id
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name        = "ECSTasksSecurityGroup"
    Environment = terraform.workspace
  }
}

# ECS Service
resource "aws_ecs_service" "schedule_service" {
  name            = "schedule-generator-service-${terraform.workspace}"
  cluster         = aws_ecs_cluster.schedule_cluster.id
  task_definition = aws_ecs_task_definition.schedule_generator.arn
  desired_count   = 0  # Set to 0 as we'll run tasks on-demand
  launch_type     = "FARGATE"
  
  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }
  
  tags = {
    Name        = "ScheduleGeneratorService"
    Environment = terraform.workspace
  }
}

# Lambda function to trigger ECS task
resource "aws_lambda_function" "trigger_ecs_task" {
  function_name = "trigger-schedule-generator-${terraform.workspace}"
  filename      = "lambda_trigger_ecs.zip"
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  role          = aws_iam_role.lambda_ecs_role.arn
  timeout       = 30
  
  environment {
    variables = {
      CLUSTER_NAME        = aws_ecs_cluster.schedule_cluster.name
      TASK_DEFINITION     = aws_ecs_task_definition.schedule_generator.arn
      SUBNET_IDS          = join(",", aws_subnet.private[*].id)
      SECURITY_GROUP_ID   = aws_security_group.ecs_tasks.id
    }
  }
  
  tags = {
    Name        = "TriggerECSTaskLambda"
    Environment = terraform.workspace
  }
}

# IAM Role for Lambda to run ECS tasks
resource "aws_iam_role" "lambda_ecs_role" {
  name = "lambda-ecs-role-${terraform.workspace}"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
  
  tags = {
    Name        = "LambdaECSRole"
    Environment = terraform.workspace
  }
}

# IAM Policy for Lambda to run ECS tasks
resource "aws_iam_policy" "lambda_ecs_policy" {
  name        = "lambda-ecs-policy-${terraform.workspace}"
  description = "Policy for Lambda to run ECS tasks"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ecs:RunTask"
        ]
        Effect   = "Allow"
        Resource = aws_ecs_task_definition.schedule_generator.arn
      },
      {
        Action = [
          "iam:PassRole"
        ]
        Effect   = "Allow"
        Resource = [
          aws_iam_role.ecs_task_execution_role.arn,
          aws_iam_role.ecs_task_role.arn
        ]
      },
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Attach the policy to the Lambda role
resource "aws_iam_role_policy_attachment" "lambda_ecs_policy_attachment" {
  role       = aws_iam_role.lambda_ecs_role.name
  policy_arn = aws_iam_policy.lambda_ecs_policy.arn
}