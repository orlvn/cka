terraform {
  required_providers {
    aws =  {
      version = "~> 4.0"
    }
  }
  backend "s3" {
    bucket  = "sb-tf-remote-state"
    key     = "norlov/cka"
    region  = "eu-central-1"
    profile = "sandbox"
    dynamodb_table = "terraform-locks"
  }
}

provider "aws" {
  region = "eu-central-1"
  profile = "sandbox"
  default_tags {
    tags = {
      Owner = "norlov"
    }
  }
}

provider "aws" {
  alias = "non-prod"
  region = "eu-central-1"
  profile = "terraform-dev"
  default_tags {
    tags = {
      Owner = "norlov"
    }
  }
} 
