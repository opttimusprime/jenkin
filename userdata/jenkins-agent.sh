#!/bin/bash
set -e

dnf update -y
dnf install -y java-21-amazon-corretto amazon-ssm-agent git docker maven nodejs npm unzip wget tar gzip jq libatomic awscli

systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

systemctl enable docker
systemctl start docker

useradd -m -s /bin/bash jenkins || true
usermod -aG docker jenkins
usermod -aG docker ec2-user

JENKINS_AGENT_PUBLIC_KEY=$(aws ssm get-parameter \
  --name "/${project}/${environment}/jenkins/agent/public_key" \
  --region "${aws_region}" \
  --query "Parameter.Value" \
  --output text)

mkdir -p /home/jenkins/.ssh
chmod 700 /home/jenkins/.ssh

echo "$JENKINS_AGENT_PUBLIC_KEY" > /home/jenkins/.ssh/authorized_keys
chmod 600 /home/jenkins/.ssh/authorized_keys

ssh-keygen -R github.com -f /home/jenkins/.ssh/known_hosts 2>/dev/null || true
ssh-keyscan -t ed25519 github.com >> /home/jenkins/.ssh/known_hosts
chmod 600 /home/jenkins/.ssh/known_hosts

chown -R jenkins:jenkins /home/jenkins/.ssh

cd /tmp
wget https://releases.hashicorp.com/terraform/1.12.2/terraform_1.12.2_linux_amd64.zip
unzip -o terraform_1.12.2_linux_amd64.zip
mv terraform /usr/local/bin/
chmod +x /usr/local/bin/terraform

curl -LO "https://dl.k8s.io/release/v1.33.1/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

rpm --import https://aquasecurity.github.io/trivy-repo/rpm/public.key

cat <<'EOF' | tee /etc/yum.repos.d/trivy.repo
[trivy]
name=Trivy repository
baseurl=https://aquasecurity.github.io/trivy-repo/rpm/releases/$basearch/
gpgcheck=1
enabled=1
gpgkey=https://aquasecurity.github.io/trivy-repo/rpm/public.key
EOF

dnf install -y trivy

trivy --version
docker --version
java --version
mvn --version
node --version
npm --version