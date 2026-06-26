terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend config is passed via -backend-config at init time
  # so staging and production get separate state files.
  # See README for the exact init commands.
  backend "s3" {
    bucket         = "devsecops-tfstate-630596767614"
    region         = "us-east-1"
    encrypt        = true
    # key is intentionally omitted — passed via -backend-config
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "devsecops-demo"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

module "vpc" {
  source = "./modules/vpc"

  project     = var.project
  environment = var.environment
  vpc_cidr    = var.vpc_cidr
  azs         = var.azs
}

module "ecr" {
  source = "./modules/ecr"

  project     = var.project
  environment = var.environment
}

module "ssm" {
  source = "./modules/ssm"

  project     = var.project
  environment = var.environment
  jwt_secret  = var.jwt_secret
}

module "alb" {
  source = "./modules/alb"

  project           = var.project
  environment       = var.environment
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
}

module "ecs" {
  source = "./modules/ecs"

  project              = var.project
  environment          = var.environment
  vpc_id               = module.vpc.vpc_id
  private_subnet_ids   = module.vpc.private_subnet_ids
  ecr_repository_url   = module.ecr.repository_url
  alb_target_group_arn = module.alb.target_group_arn
  alb_security_group   = module.alb.security_group_id
  jwt_secret_arn       = module.ssm.jwt_secret_arn
  image_tag            = var.image_tag
  demo_password_arn    = var.demo_password_arn
}
