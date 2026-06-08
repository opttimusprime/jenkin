resource "tls_private_key" "jenkins_agent" {
  algorithm = "ED25519"
}

resource "aws_ssm_parameter" "jenkins_agent_private_key" {
  name  = "/${var.project}/${var.environment}/jenkins/agent/private_key"
  type  = "SecureString"
  value = tls_private_key.jenkins_agent.private_key_openssh

  tags = {
    Name = "${var.project}-${var.environment}-jenkins-agent-private-key"
  }
}

resource "aws_ssm_parameter" "jenkins_agent_public_key" {
  name  = "/${var.project}/${var.environment}/jenkins/agent/public_key"
  type  = "String"
  value = tls_private_key.jenkins_agent.public_key_openssh

  tags = {
    Name = "${var.project}-${var.environment}-jenkins-agent-public-key"
  }
}