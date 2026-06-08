output "jenkins_vpc_id" {
  value = module.jenkins_vpc.vpc_id
}

output "jenkins_controller_private_ip" {
  value = aws_instance.jenkins_controller.private_ip
}

output "jenkins_agent_private_ips" {
  value = aws_instance.jenkins_agent[*].private_ip
}

output "jenkins_alb_dns_name" {
  value = aws_lb.jenkins.dns_name
}

output "vpc_peering_connection_id" {
  value = aws_vpc_peering_connection.jenkins_to_dev.id
}

output "jenkins_role_arn" {
  value = aws_iam_role.jenkins_role.arn
}

output "jenkins_url" {
  value = "http://${aws_route53_record.jenkins.fqdn}"
}