aws_region  = "us-east-1"
project     = "roboshop"
environment = "dev"

jenkins_vpc_cidr = "10.50.0.0/16"

public_subnet_cidrs = [
  "10.50.1.0/24",
  "10.50.2.0/24"
]

private_subnet_cidrs = [
  "10.50.11.0/24",
  "10.50.12.0/24"
]

availability_zones = [
  "us-east-1a",
  "us-east-1b"
]

key_name   = "roboshop-dev-keypair"
my_ip_cidr = "0.0.0.0/0"

