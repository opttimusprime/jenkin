data "terraform_remote_state" "roboshop_vpc" {
  backend = "s3"

  config = {
    bucket = "roboshop-tf-state"
    key    = "dev/bootstrap/vpc/terraform.tfstate"
    region = "us-east-1"
  }
}

data "aws_route53_zone" "optimusprime" {
  name         = "optimusprime.uno"
  private_zone = false
}

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}