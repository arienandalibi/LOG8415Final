terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# connect to aws
provider "aws" {
  region = "us-east-1"
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  token = "${var.token}"
}

# create vpc
data "aws_vpc" "default" {
  default = true
}

# create security group
resource "aws_security_group" "final_security_group" {
  name        = "final_security_group"
  description = "Allow traffic"
  vpc_id      = data.aws_vpc.default.id
  
  # Define your security group rules here
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# create 1 t2.micro manager instance
resource "aws_instance" "manager" {
#  count = 1
  ami = "ami-0fc5d935ebf8bc3bc"
  vpc_security_group_ids = [aws_security_group.final_security_group.id]
  instance_type = "t2.micro"
  user_data = templatefile("manager_data_script.tpl", {
    worker1hostID = aws_instance.worker1.host_id
    worker1privateDNS = aws_instance.worker1.private_dns
    worker1privateIP = aws_instance.worker1.private_ip
  }) # templatefile allows us to use terraform to pass instance information to another instance
  tags = {
    Name = "Manager"
  }
}

# create 3 t2.micro worker instances
resource "aws_instance" "worker1" {
#  count         = 1
  ami           = "ami-0fc5d935ebf8bc3bc"
  vpc_security_group_ids = [aws_security_group.final_security_group.id]
  instance_type = "t2.micro"
#  root_block_device {
#    volume_size = 30
#  }
  user_data = file("slave_data.sh")
  tags = {
    Name = "Worker1"
  }
}
#
#resource "aws_instance" "worker2" {
##  count         = 1
#  ami           = "ami-0fc5d935ebf8bc3bc"
#  vpc_security_group_ids = [aws_security_group.final_security_group.id]
#  instance_type = "t2.micro"
##  root_block_device {
##    volume_size = 30
##  }
#  user_data = file("slave_data.sh")
#  tags = {
#    Name = "Worker2"
#  }
#}
#
#resource "aws_instance" "worker3" {
##  count         = 1
#  ami           = "ami-0fc5d935ebf8bc3bc"
#  vpc_security_group_ids = [aws_security_group.final_security_group.id]
#  instance_type = "t2.micro"
##  root_block_device {
##    volume_size = 30
##  }
#  user_data = file("slave_data.sh")
#  tags = {
#    Name = "Worker3"
#  }
#}

# output the instance ids for the workers
#output "t2_instance" {
#  value = [for instance in aws_instance.t2_workers: instance.id]
#}

# output the instance ids for the manager
# output "m4_orchestrator" {
#   value = aws_instance.m4_orchestrator.id
# }