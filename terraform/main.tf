provider "aws" {
  region = "us-east-1"
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["137112412989"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_security_group" "jenkins_sg" {
  name        = "jenkins-sg"
  description = "Allow SSH and Jenkins access"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "jenkins" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.micro"
  key_name               = "tonykey"
  subnet_id              = data.aws_subnets.default.ids[0]
  vpc_security_group_ids = [aws_security_group.jenkins_sg.id]

  root_block_device {
    volume_size = 16
    volume_type = "gp2"
    delete_on_termination = true
  }

  user_data = <<-EOF
              #!/bin/bash
              dnf update -y

              # Install Java for Jenkins
              dnf install java-17-amazon-corretto -y

              # Install Jenkins
              dnf install wget -y
              wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
              rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
              dnf install jenkins git -y
              systemctl enable jenkins
              systemctl start jenkins

              # Install Terraform
              dnf install -y dnf-plugins-core
              dnf config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
              dnf install -y terraform

              # Install AWS CLI v2
              curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
              dnf install unzip -y
              unzip awscliv2.zip
              ./aws/install
              EOF

  tags = {
    Name = "JenkinsServer"
  }
}

output "jenkins_public_ip" {
  value = aws_instance.jenkins.public_ip
}

output "jenkins_url" {
  value = "http://${aws_instance.jenkins.public_ip}:8080"
}
