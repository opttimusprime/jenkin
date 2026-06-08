module "jenkins_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.project}-${var.environment}-jenkins-vpc"
  cidr = var.jenkins_vpc_cidr

  azs             = var.availability_zones
  public_subnets  = var.public_subnet_cidrs
  private_subnets = var.private_subnet_cidrs

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_vpc_peering_connection" "jenkins_to_dev" {
  vpc_id      = module.jenkins_vpc.vpc_id
  peer_vpc_id = data.terraform_remote_state.roboshop_vpc.outputs.vpc_id
  auto_accept = true

  tags = {
    Name = "${var.project}-${var.environment}-jenkins-to-dev-peering"
  }
}

resource "aws_route" "jenkins_private_to_dev" {
  count = length(module.jenkins_vpc.private_route_table_ids)

  route_table_id            = module.jenkins_vpc.private_route_table_ids[count.index]
  destination_cidr_block    = data.terraform_remote_state.roboshop_vpc.outputs.vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.jenkins_to_dev.id
}

resource "aws_route" "dev_to_jenkins" {
  count = length(data.terraform_remote_state.roboshop_vpc.outputs.private_route_table_ids)

  route_table_id            = data.terraform_remote_state.roboshop_vpc.outputs.private_route_table_ids[count.index]
  destination_cidr_block    = var.jenkins_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.jenkins_to_dev.id
}

resource "aws_security_group" "alb" {
  name        = "${var.project}-${var.environment}-jenkins-alb-sg"
  description = "Allow Jenkins UI from my IP"
  vpc_id      = module.jenkins_vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-${var.environment}-jenkins-alb-sg"
  }
}

resource "aws_security_group" "jenkins_controller" {
  name        = "${var.project}-${var.environment}-jenkins-controller-sg"
  description = "Jenkins controller security group"
  vpc_id      = module.jenkins_vpc.vpc_id

  ingress {
    description     = "Jenkins UI from ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  ingress {
    description = "Jenkins agent communication"
    from_port   = 50000
    to_port     = 50000
    protocol    = "tcp"
    cidr_blocks = [var.jenkins_vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-${var.environment}-jenkins-controller-sg"
  }
}

resource "aws_security_group" "jenkins_agent" {
  name        = "${var.project}-${var.environment}-jenkins-agent-sg"
  description = "Jenkins agent security group"
  vpc_id      = module.jenkins_vpc.vpc_id

  ingress {
    description     = "SSH from Jenkins controller"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.jenkins_controller.id]
  }

  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-${var.environment}-jenkins-agent-sg"
  }
}

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_instance" "jenkins_controller" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "c7i-flex.large"
  subnet_id              = module.jenkins_vpc.private_subnets[0]
  vpc_security_group_ids = [aws_security_group.jenkins_controller.id]
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.jenkins.name

  user_data_replace_on_change = true

  user_data = templatefile("${path.module}/userdata/jenkins-controller.sh", {
    project     = var.project
    environment = var.environment
    aws_region  = var.aws_region
  })

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = {
    Name = "${var.project}-${var.environment}-jenkins-controller"
  }

  depends_on = [
    aws_ssm_parameter.jenkins_agent_private_key,
    aws_ssm_parameter.jenkins_agent_public_key
  ]
}

resource "aws_instance" "jenkins_agent" {
  count = 2

  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "c7i-flex.large"
  subnet_id              = module.jenkins_vpc.private_subnets[count.index]
  vpc_security_group_ids = [aws_security_group.jenkins_agent.id]
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.jenkins.name

  user_data_replace_on_change = true

  user_data = templatefile("${path.module}/userdata/jenkins-agent.sh", {
    project     = var.project
    environment = var.environment
    aws_region  = var.aws_region
  })

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = {
    Name = "${var.project}-${var.environment}-jenkins-agent-${count.index + 1}"
  }

  depends_on = [
    aws_ssm_parameter.jenkins_agent_public_key
  ]
}

resource "aws_lb" "jenkins" {
  name               = "${var.project}-${var.environment}-jenkins-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = module.jenkins_vpc.public_subnets

  tags = {
    Name = "${var.project}-${var.environment}-jenkins-alb"
  }
}

resource "aws_lb_target_group" "jenkins" {
  name     = "${var.project}-${var.environment}-jenkins-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = module.jenkins_vpc.vpc_id

  health_check {
    path                = "/login"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${var.project}-${var.environment}-jenkins-tg"
  }
}

resource "aws_lb_target_group_attachment" "jenkins" {
  target_group_arn = aws_lb_target_group.jenkins.arn
  target_id        = aws_instance.jenkins_controller.id
  port             = 8080
}

resource "aws_lb_listener" "jenkins" {
  load_balancer_arn = aws_lb.jenkins.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.jenkins.arn
  }
}

resource "aws_route53_record" "jenkins" {
  zone_id = data.aws_route53_zone.optimusprime.zone_id
  name    = var.jenkins_dns_name
  type    = "A"

  alias {
    name                   = aws_lb.jenkins.dns_name
    zone_id                = aws_lb.jenkins.zone_id
    evaluate_target_health = true
  }
}