variable "aws_region" {}
variable "project" {}
variable "environment" {}

variable "jenkins_vpc_cidr" {}
variable "public_subnet_cidrs" {}
variable "private_subnet_cidrs" {}

variable "availability_zones" {
  type = list(string)
}

variable "key_name" {}
variable "my_ip_cidr" {}

variable "jenkins_dns_name" {
  default = "jenkins.optimusprime.uno"
}