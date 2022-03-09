terraform {
  required_providers {
    aws =  {
      version = "~> 4.0"
    }
  }
  backend "s3" {
    bucket  = "hb-sb-tf-remote-state"
    key     = "norlov/cka"
    region  = "eu-west-1"
    profile = "sandbox"
    dynamodb_table = "tf-state-lock"
  }
}

provider "aws" {
  region = "eu-west-1"
  profile = "sandbox"
  default_tags {
    tags = {
      Owner = "norlov"
    }
  }
}

provider "aws" {
  alias = "non-prod"
  region = "eu-west-1"
  profile = "terraform-dev"
  default_tags {
    tags = {
      Owner = "norlov"
    }
  }
} 
