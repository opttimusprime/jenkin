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