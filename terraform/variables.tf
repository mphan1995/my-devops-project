variable "aws_account_id" {
  type = string
}

variable "region" {
  type    = string
  default = "ap-southeast-1"
}

variable "project" {
  type    = string
  default = "my-devops-project"
}

variable "vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "public_subnets" {
  type    = list(string)
  default = ["10.20.1.0/24", "10.20.2.0/24", "10.20.3.0/24"]
}

variable "private_subnets" {
  type    = list(string)
  default = ["10.20.11.0/24", "10.20.12.0/24", "10.20.13.0/24"]
}

variable "node_instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}

variable "tags" {
  type = map(string)
  default = {
    Owner    = "Max Phan"
    ManagedBy = "Terraform"
  }
}
