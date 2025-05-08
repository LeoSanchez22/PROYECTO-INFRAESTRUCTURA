# DynamoDB table for schedule history
resource "aws_dynamodb_table" "schedule_history" {
  name           = "schedule-history-${terraform.workspace}"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"
  range_key      = "timestamp"
  
  attribute {
    name = "id"
    type = "S"
  }
  
  attribute {
    name = "timestamp"
    type = "S"
  }
  
  attribute {
    name = "userId"
    type = "S"
  }
  
  # Global Secondary Index for querying by userId
  global_secondary_index {
    name               = "UserIdIndex"
    hash_key           = "userId"
    range_key          = "timestamp"
    projection_type    = "ALL"
  }
  
  # Enable point-in-time recovery
  point_in_time_recovery {
    enabled = true
  }
  
  # Enable server-side encryption
  server_side_encryption {
    enabled = true
  }
  
  tags = {
    Name        = "ScheduleHistoryTable"
    Environment = terraform.workspace
  }
}
