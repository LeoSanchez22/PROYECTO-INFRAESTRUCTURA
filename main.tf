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

provider "aws" {
  region = "us-east-1"  # Estandarizamos en us-east-1 para mantener consistencia con servicios como CloudFront
}

# Provider for replica region
provider "aws" {
  alias  = "replica"
  region = "us-west-2" # Different region for disaster recovery
}
