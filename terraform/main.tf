#----------------------------------------------------------
#Build Infrastruce using Terraform 
#----------------------------------------------------------

#  Define the provider
provider "aws" {
  region = "us-east-1"
}

# Data source for AMI id
data "aws_ami" "latest_amazon_linux" {
  owners      = ["amazon"]
  most_recent = true
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}


# Data source for availability zones in us-east-1
data "aws_availability_zones" "available" {
  state = "available"
}

# Data block to retrieve the default VPC id
data "aws_vpc" "default" {
  default = true
}

# Define tags locally
locals {
  default_tags = merge(module.globalvars.default_tags, { "env" = var.env })
  prefix       = module.globalvars.prefix
  name_prefix  = "${local.prefix}-${var.env}"
}

# Retrieve global variables from the Terraform module
module "globalvars" {
  source = "../modules/globalvars"
}

# Reference subnet provisioned by 01-Networking 
resource "aws_instance" "my_amazon" {
  ami                         = data.aws_ami.latest_amazon_linux.id
  instance_type               = lookup(var.instance_type, var.env)
  key_name                    = aws_key_pair.assignment2.key_name
  vpc_security_group_ids      = [aws_security_group.Assignment1.id]
  associate_public_ip_address = false
  iam_instance_profile        = data.aws_iam_instance_profile.lab_profile.name
  user_data                   = <<-EOF
#!/bin/bash

# Update packages
sudo yum update -y

# Install Docker
sudo yum install docker -y
sudo service docker start
sudo usermod -aG docker ec2-user

# Install kubectl
sudo curl --silent --location -o /usr/local/bin/kubectl https://s3.us-west-2.amazonaws.com/amazon-eks/1.21.5/2022-01-21/bin/linux/amd64/kubectl
sudo chmod +x /usr/local/bin/kubectl

# Install kind
sudo curl -sLo kind "https://kind.sigs.k8s.io/dl/v0.11.0/kind-linux-amd64"
sudo install -o root -g root -m 0755 kind /usr/local/bin/kind
rm -f ./kind

EOF

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.default_tags,
    {
      "Name" = "${local.name_prefix}-Amazon-Linux"
    }
  )
}

# Elastic IP
resource "aws_eip" "static_eip" {
  instance = aws_instance.my_amazon.id
  tags = merge(local.default_tags,
    {
      "Name" = "${local.name_prefix}-eip"
    }
  )
}
# ECR Repository Create
resource "aws_ecr_repository" "my_repository_webapp" {
  name                 = "webapp-repo-assignment1"
  

  image_scanning_configuration {
    scan_on_push = true
  }
}

# ECR Repository Create
resource "aws_ecr_repository" "my_repository_mysql" {
  name                 = "mysql-repo-assignment1"

  image_scanning_configuration {
    scan_on_push = true
  }
}

data "aws_iam_instance_profile" "lab_profile" {
  name = "LabInstanceProfile"
}



# Adding SSH key to Amazon EC2
resource "aws_key_pair" "assignment2"{
  key_name   = local.name_prefix
  public_key = file("assignment2.pub")
}

# Security Group
resource "aws_security_group" "Assignment2" {
  name        = "allow_ssh"
  description = "Allow inbound SSH and HTTP traffic"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description      = "SSH from everywhere"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = merge(local.default_tags,
    {
      "Name" = "${local.name_prefix}-sg"
    }
  )
}

