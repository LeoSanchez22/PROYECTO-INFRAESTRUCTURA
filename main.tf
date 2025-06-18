terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  # Para mantener el estado de Terraform
  backend "local" {}
}

# Main AWS provider configuration for us-east-1
provider "aws" {
  region = "us-east-1"  # Estandarizamos en us-east-1 para mantener consistencia con servicios como CloudFront
  
  default_tags {
    tags = {
      Environment = "production"
      Project     = "PROYECTO-INFRAESTRUCTURA"
      ManagedBy   = "terraform"
    }
  }
}

# Secondary provider for eu-west-1 region (needed for certain S3 buckets)
provider "aws" {
  alias  = "eu_west_1"
  region = "eu-west-1"
  
  default_tags {
    tags = {
      Environment = "production"
      Project     = "PROYECTO-INFRAESTRUCTURA"
      ManagedBy   = "terraform"
    }
  }
}

# Provider for replica region (used for S3 replication)
provider "aws" {
  alias  = "replica"
  region = "us-west-2" # Different region for disaster recovery
  
  default_tags {
    tags = {
      Environment = "production"
      Project     = "PROYECTO-INFRAESTRUCTURA"
      ManagedBy   = "terraform"
    }
  }
}

# Provider for replica region
provider "aws" {
  alias  = "replica"
  region = "us-west-2" # Different region for disaster recovery
}
