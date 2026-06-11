#!/bin/bash
set -e

dnf update -y
dnf install -y java-21-amazon-corretto git wget docker awscli amazon-ssm-agent

systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

systemctl enable docker
systemctl start docker

wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key

dnf install -y jenkins

usermod -aG docker jenkins

mkdir -p /var/lib/jenkins/.ssh
chmod 700 /var/lib/jenkins/.ssh

aws ssm get-parameter \
  --name "/${project}/${environment}/jenkins/agent/private_key" \
  --with-decryption \
  --region "${aws_region}" \
  --query "Parameter.Value" \
  --output text > /var/lib/jenkins/.ssh/jenkins_agent

aws ssm get-parameter \
  --name "/${project}/${environment}/jenkins/agent/public_key" \
  --region "${aws_region}" \
  --query "Parameter.Value" \
  --output text > /var/lib/jenkins/.ssh/jenkins_agent.pub

chmod 600 /var/lib/jenkins/.ssh/jenkins_agent
chmod 644 /var/lib/jenkins/.ssh/jenkins_agent.pub

ssh-keygen -R github.com -f /var/lib/jenkins/.ssh/known_hosts 2>/dev/null || true
ssh-keyscan -t ed25519 github.com >> /var/lib/jenkins/.ssh/known_hosts
chmod 600 /var/lib/jenkins/.ssh/known_hosts

chown -R jenkins:jenkins /var/lib/jenkins/.ssh

systemctl enable jenkins
systemctl start jenkins