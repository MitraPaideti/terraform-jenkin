terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

resource "aws_instance" "this" {
  ami           = var.ami
  instance_type = var.instance_type
  availability_zone    = var.availability_zone

  credit_specification {
    cpu_credits = "unlimited"
  }
}