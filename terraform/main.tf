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

#create ssm to store manager's private DNS
resource "aws_ssm_parameter" "manager_private_dns" {
  name        = "/myapp/manager_private_dns"
  description = "Private DNS of the Manager instance"
  type        = "String"
  value       = aws_instance.manager.private_dns
}

#create the standalone instance
resource "aws_instance" "standalone" {
#  count = 1
  ami = "ami-0fc5d935ebf8bc3bc"
  vpc_security_group_ids = [aws_security_group.final_security_group.id]
  instance_type = "t2.micro"
#  user_data = templatefile("standalone_script.tpl", {
#    runSysbench = 1     # 0 = true; 1 = false
#  }) # templatefile allows us to use terraform to pass instance information to another instance
  tags = {
    Name = "Standalone"
  }
}

#create an instance to execute benchmarking of cloud implementations
resource "aws_instance" "tester" {
#  count = 1
  ami = "ami-0fc5d935ebf8bc3bc"
  vpc_security_group_ids = [aws_security_group.final_security_group.id]
  instance_type = "t2.micro"
  user_data = templatefile("tester_script.tpl", {
    mysql_kp = file("mysql_kp.pem")
    gatekeeperPrivateDNS = aws_instance.gatekeeper.private_dns
  }) # templatefile allows us to use terraform to pass instance information to another instance
  tags = {
    Name = "Tester"
  }
}

#create the proxy instance
resource "aws_instance" "proxy" {
#  count = 1
  ami = "ami-0fc5d935ebf8bc3bc"
  vpc_security_group_ids = [aws_security_group.final_security_group.id]
  instance_type = "t2.micro"
  key_name = "mysql_kp"
  user_data = templatefile("proxy_script.tpl", {
    accessKey = "${var.access_key}"
    secretKey = "${var.secret_key}"
    token = "${var.token}"
    worker1privateDNS = aws_instance.worker1.private_dns
  }) # templatefile allows us to use terraform to pass instance information to another instance
  tags = {
    Name = "Proxy"
  }
}

resource "aws_instance" "trustedhost" {
#  count = 1
  ami = "ami-0fc5d935ebf8bc3bc"
  vpc_security_group_ids = [aws_security_group.final_security_group.id]
  instance_type = "t2.micro"
  key_name = "mysql_kp"
  user_data = templatefile("trustedhost_script.tpl", {
    mysql_kp = file("mysql_kp.pem")
    proxyPrivateDNS = aws_instance.proxy.private_dns
  }) # templatefile allows us to use terraform to pass instance information to another instance
  tags = {
    Name = "Trusted Host"
  }
}

resource "aws_instance" "gatekeeper" {
#  count = 1
  ami = "ami-0fc5d935ebf8bc3bc"
  vpc_security_group_ids = [aws_security_group.final_security_group.id]
  instance_type = "t2.micro"
  key_name = "mysql_kp"
  user_data = templatefile("gatekeeper_script.tpl", {
    mysql_kp = file("mysql_kp.pem")
    trustedhostPrivateDNS = aws_instance.trustedhost.private_dns
  }) # templatefile allows us to use terraform to pass instance information to another instance
  tags = {
    Name = "Gatekeeper"
  }
}

# create 1 t2.micro manager instance
resource "aws_instance" "manager" {
#  count = 1
  ami = "ami-0fc5d935ebf8bc3bc"
  vpc_security_group_ids = [aws_security_group.final_security_group.id]
  instance_type = "t2.micro"
#  key_name = "mysql_kp"
  user_data = templatefile("manager_data_script.tpl", {
    worker1privateDNS = aws_instance.worker1.private_dns
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
#  key_name = "mysql_kp"
  user_data = templatefile("worker_data_script.tpl", {
    accessKey = "${var.access_key}"
    secretKey = "${var.secret_key}"
    token = "${var.token}"
    serverID = "51"
  })
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
#  user_data = file("worker_data_script.tpl")
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
#  user_data = file("worker_data_script.tpl")
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