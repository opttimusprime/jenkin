output "roboshop_vpc_id" {
  value = data.terraform_remote_state.roboshop_vpc.outputs.vpc_id
}

output "jenkins_controller_private_ip" {
  value = aws_instance.jenkins_controller.private_ip
}

output "jenkins_agent_private_ip" {
  value = aws_instance.jenkins_agent.private_ip
}

output "jenkins_alb_dns_name" {
  value = aws_lb.jenkins.dns_name
}

output "jenkins_role_arn" {
  value = aws_iam_role.jenkins_role.arn
}

output "jenkins_url" {
  value = "http://${aws_route53_record.jenkins.fqdn}"
}