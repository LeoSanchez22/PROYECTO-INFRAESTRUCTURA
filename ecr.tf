# ECR Repository for the Python Selenium Docker image
resource "aws_ecr_repository" "schedule_generator" {
  name                 = "schedule-generator-${terraform.workspace}"
  image_tag_mutability = "MUTABLE"
  force_delete         = true  # Add this line to allow deletion of non-empty repositories

  image_scanning_configuration {
    scan_on_push = true
  }
  
  tags = {
    Name        = "ScheduleGenerator"
    Environment = terraform.workspace
  }
}

# ECR Lifecycle Policy to manage image versions
resource "aws_ecr_lifecycle_policy" "schedule_generator_policy" {
  repository = aws_ecr_repository.schedule_generator.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 5 images"
        selection = {
          tagStatus     = "any"
          countType     = "imageCountMoreThan"
          countNumber   = 5
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
