# ========================================
# KMS CONFIGURATION - OPTIMIZED FOR DEV
# ========================================
# USANDO CLAVES AWS GRATUITAS ($0/mes)
# Las claves AWS-managed son gratuitas y se gestionan automáticamente
# ========================================

# CLAVES KMS PERSONALIZADAS COMENTADAS PARA AHORRAR COSTOS
# Descomenta si necesitas claves personalizadas en producción

/*
# KMS Key for CloudWatch Logs encryption
resource "aws_kms_key" "logs_key" {
  description             = "KMS key for CloudWatch Logs encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CloudWatch Logs"
        Effect = "Allow"
        Principal = {
          Service = "logs.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "cloudwatch-logs-key"
    Description = "KMS key for CloudWatch Logs encryption"
  }
}

resource "aws_kms_alias" "logs_key_alias" {
  name          = "alias/cloudwatch-logs-key-v2-${random_id.bucket_suffix.hex}"
  target_key_id = aws_kms_key.logs_key.key_id
}

# KMS Key for Lambda encryption
resource "aws_kms_key" "lambda_key" {
  description             = "KMS key for Lambda environment variables encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow Lambda Service"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "lambda-encryption-key"
    Description = "KMS key for Lambda encryption"
  }
}

resource "aws_kms_alias" "lambda_key_alias" {
  name          = "alias/lambda-encryption-key-v2-${random_id.bucket_suffix.hex}"
  target_key_id = aws_kms_key.lambda_key.key_id
}

# KMS Key for DynamoDB encryption
resource "aws_kms_key" "dynamodb_key" {
  description             = "KMS key for DynamoDB encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow DynamoDB Service"
        Effect = "Allow"
        Principal = {
          Service = "dynamodb.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "dynamodb-encryption-key"
    Description = "KMS key for DynamoDB encryption"
  }
}

resource "aws_kms_alias" "dynamodb_key_alias" {
  name          = "alias/dynamodb-encryption-key-v2-${random_id.bucket_suffix.hex}"
  target_key_id = aws_kms_key.dynamodb_key.key_id
}
*/

# ========================================
# CONFIGURACIÓN GRATUITA PARA DESARROLLO
# ========================================
# No se declaran recursos KMS - se usan claves AWS automáticamente

locals {
  # Configuración de encriptación gratuita para desarrollo
  encryption_config = {
    # Para S3 - AES256 es gratuito
    s3_algorithm = "AES256"
    
    # Para servicios que requieren KMS - usar claves AWS-managed (gratuitas)
    # No se referencian aquí, se usan directamente en los recursos
    cost_per_month = "$0.00"
    mode = "aws-managed-keys"
  }
}

# Output para confirmar configuración
output "kms_cost_optimization" {
  description = "Configuración de encriptación optimizada para desarrollo"
  value = {
    mode             = local.encryption_config.mode
    monthly_cost     = local.encryption_config.cost_per_month
    s3_encryption    = local.encryption_config.s3_algorithm
    kms_keys_custom  = "disabled (commented out)"
    kms_keys_aws     = "enabled (free)"
  }
}
