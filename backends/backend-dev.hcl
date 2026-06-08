bucket         = "opttimusprime-jenkins-tf-state"
key            = "jenkins/dev/terraform.tfstate"
dynamodb_table = "opttimusprime-jenkins-tf-lock"
region         = "us-east-1"
encrypt        = true