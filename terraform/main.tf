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
resource "aws_vpc" "final" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
}

# create internet gateway for internet access
resource "aws_internet_gateway" "final_igw" {
  vpc_id = aws_vpc.final.id
}

# create a route table to route subnets to internet
# by associating the route table to our internet gateway
resource "aws_route_table" "final_rt" {
  vpc_id = aws_vpc.final.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.final_igw.id
  }
}

# associate both subnets that need internet connection to the route table with internet connectivity (excludes the trusted host)
resource "aws_route_table_association" "gatekeeper_asso" {
  subnet_id      = aws_subnet.gatekeeper_subnet.id
  route_table_id = aws_route_table.final_rt.id
}

resource "aws_route_table_association" "proxy_cluster_asso" {
  subnet_id      = aws_subnet.proxy_cluster_subnet.id
  route_table_id = aws_route_table.final_rt.id
}

#resource "aws_route_table_association" "trustedhost_asso" {
#  subnet_id      = aws_subnet.trustedhost_subnet.id
#  route_table_id = aws_route_table.final_rt.id
#}

# just to make sure gatekeeper is in a different subnet than other nodes
resource "aws_subnet" "gatekeeper_subnet" {
  vpc_id                  = aws_vpc.final.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true    # want gatekeeper to be connected to internet freely
}

# Create a subnet for the trusted host
resource "aws_subnet" "trustedhost_subnet" {
  vpc_id                  = aws_vpc.final.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = false     # trusted host wont even have internet connectivity
}

# Create a subnet for the proxy and 4 MySQL Cluster nodes
resource "aws_subnet" "proxy_cluster_subnet" {
  vpc_id                  = aws_vpc.final.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true      # these need to download files from the internet so they need an IPv4 address
}

# create security group for all traffic
resource "aws_security_group" "final_security_group" {
  name        = "final_security_group"
  description = "Allow traffic"
  vpc_id      = aws_vpc.final.id

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

# create security group for gatekeeper
resource "aws_security_group" "gatekeeper_security_group" {
  name        = "gatekeeper_security_group"
  description = "Allow traffic"
  vpc_id      = aws_vpc.final.id
  
  # Define your security group rules here
  # Gatekeeper can only receive connections from the ports used for ssh and mysql
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp" # the default mysql and ssh protocols are tcp
    cidr_blocks = ["10.0.1.0/24"] # maps to the trusted host's subnet
  }

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]   # allow outgoing downloads
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]   # allow outgoing downloads
  }

  egress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp" # the default mysql and ssh protocols are tcp
    cidr_blocks = ["10.0.1.0/24"] # maps to the trusted host's subnet
  }
}

# create security group for trusted host
resource "aws_security_group" "trustedhost_security_group" {
  name        = "trustedhost_security_group"
  description = "Allow traffic only from gatekeeper"
  vpc_id      = aws_vpc.final.id

  # Define your security group rules here
  # Incoming connection can be from gatekeeper, and outgoing must be to the proxy
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [aws_security_group.gatekeeper_security_group.id] # only allow MySQL from gatekeeper
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [aws_security_group.gatekeeper_security_group.id] # only allow SSH from gatekeeper
  }

  egress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [aws_security_group.proxy_security_group.id] # only allow SSH to proxy
  }

  egress {
    from_port   = 6033
    to_port     = 6033
    protocol    = "tcp"
    security_groups = [aws_security_group.proxy_security_group.id] # only allow MySQL to proxy
  }

  egress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [aws_security_group.proxy_security_group.id] # allows trusted host to communicate with my implemented proxy
  }
}

# create security group for proxy
resource "aws_security_group" "proxy_security_group" {
  name        = "proxy_security_group"
  description = "Allow traffic"
  vpc_id      = aws_vpc.final.id

  # Define your security group rules here
  # Incoming connection can be from trustedhost, even if we need to download files, ingress rules don't apply if the instance establishes the connection
  # outgoing can be to anyone.
  ingress {
    from_port   = 6033
    to_port     = 6033
    protocol    = "tcp"
    cidr_blocks = ["10.0.1.0/24"] # maps to the trusted host's subnet
  }

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.1.0/24"] # maps to the trusted host's subnet
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.1.0/24"] # maps to the trusted host's subnet
  }

  ingress {
    from_port   = 6032
    to_port     = 6032
    protocol    = "tcp"
    cidr_blocks = ["10.0.2.0/24"] # maps to the proxy's subnet, allows to run administrative commands on itself
  }

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]   # allow outgoing downloads
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]   # allow outgoing downloads
  }

  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["10.0.2.0/24"]   # interact with cluster and itself
  }

  egress {
    from_port   = -1
    to_port     = -1        # ICMP protocol doesn't use ports
    protocol    = "icmp"    # protocol used by bash ping command
    cidr_blocks = ["10.0.2.0/24"]
  }
}

# create security group for cluster
resource "aws_security_group" "cluster_security_group" {
  name        = "cluster_security_group"
  description = "Allow traffic only from proxy"
  vpc_id      = aws_vpc.final.id

  # Define your security group rules here
  # Incoming connection can be from proxy or other cluster, even if we need to download files,
  # ingress rules don't apply if the instance establishes the connection, outgoing can be to anyone.
  # Don't know what ports MySQL Cluster uses internally so they're all allowed in the subnet
  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["10.0.2.0/24"] # interact with cluster and proxy only
  }

  ingress {
    from_port   = -1
    to_port     = -1        # ICMP protocol doesn't use ports
    protocol    = "icmp"    # protocol used by bash ping command
    cidr_blocks = ["10.0.2.0/24"]
  }

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # allow outgoing downloads
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]   # allow outgoing downloads
  }

  egress {
    from_port   = 0
    to_port     = 65535 # don't know what ports MySQL Cluster uses internally
    protocol    = "tcp"
    cidr_blocks = ["10.0.2.0/24"] # interact with cluster and itself
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
#resource "aws_instance" "standalone" {
##  count = 1
#  ami = "ami-0fc5d935ebf8bc3bc"
#  vpc_security_group_ids = [aws_security_group.final_security_group.id]
#  instance_type = "t2.micro"
#  key_name = "mysql_kp"
#  user_data = templatefile("standalone_script.tpl", {
#    runSysbench = 1     # 0 = true; 1 = false
#  }) # templatefile allows us to use terraform to pass instance information to another instance
#  tags = {
#    Name = "Standalone"
#  }
#}

#create an instance to execute benchmarking of cloud implementations
#resource "aws_instance" "tester" {
##  count = 1
#  ami = "ami-0fc5d935ebf8bc3bc"
#  vpc_security_group_ids = [aws_security_group.final_security_group.id]
#  instance_type = "t2.micro"
##  user_data = templatefile("tester_script.tpl", {
##    mysql_kp = file("mysql_kp.pem")
##    gatekeeperPrivateDNS = aws_instance.gatekeeper.private_dns
##  }) # templatefile allows us to use terraform to pass instance information to another instance
#  tags = {
#    Name = "Tester"
#  }
#}

# create the proxy instance if we want to use ProxySQL
#resource "aws_instance" "proxy" {
##  count = 1
#  ami = "ami-0fc5d935ebf8bc3bc"
#  vpc_security_group_ids = [aws_security_group.proxy_security_group.id]
#  subnet_id = aws_subnet.proxy_cluster_subnet.id
#  instance_type = "t2.micro"
#  key_name = "mysql_kp"
#  user_data = templatefile("proxy_script.tpl", {
#    accessKey = "${var.access_key}"
#    secretKey = "${var.secret_key}"
#    token = "${var.token}"
#    worker1privateDNS = aws_instance.worker1.private_dns
#    worker2privateDNS = aws_instance.worker2.private_dns
#    worker3privateDNS = aws_instance.worker3.private_dns
#    mysql_kp = file("mysql_kp.pem")
#  }) # templatefile allows us to use terraform to pass instance information to another instance
#  tags = {
#    Name = "Proxy"
#  }
#}

# create the proxySQL instance to test our python
resource "aws_instance" "proxy" {
#  count = 1
  ami = "ami-0fc5d935ebf8bc3bc"
  vpc_security_group_ids = [aws_security_group.proxy_security_group.id]
  subnet_id = aws_subnet.proxy_cluster_subnet.id
  instance_type = "t2.micro"
  key_name = "mysql_kp"
  user_data = templatefile("proxy_script2.tpl", {
    accessKey = "${var.access_key}"
    secretKey = "${var.secret_key}"
    token = "${var.token}"
    worker1privateDNS = aws_instance.worker1.private_dns
    worker2privateDNS = aws_instance.worker2.private_dns
    worker3privateDNS = aws_instance.worker3.private_dns
    mysql_kp = file("mysql_kp.pem")
    python_file = base64encode(templatefile("proxy_telnet.py", {
      worker1privateDNS = aws_instance.worker1.private_dns
      worker2privateDNS = aws_instance.worker2.private_dns
      worker3privateDNS = aws_instance.worker3.private_dns
    }))
  }) # templatefile allows us to use terraform to pass instance information to another instance
  tags = {
    Name = "Proxy"
  }
}

resource "aws_instance" "trustedhost" {
#  count = 1
  ami = "ami-0fc5d935ebf8bc3bc"
  vpc_security_group_ids = [aws_security_group.trustedhost_security_group.id]
  subnet_id = aws_subnet.trustedhost_subnet.id
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
  vpc_security_group_ids = [aws_security_group.gatekeeper_security_group.id]
  subnet_id = aws_subnet.gatekeeper_subnet.id
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
  vpc_security_group_ids = [aws_security_group.cluster_security_group.id]
  subnet_id = aws_subnet.proxy_cluster_subnet.id
  instance_type = "t2.micro"
  key_name = "mysql_kp"
  user_data = templatefile("manager_data_script.tpl", {
    worker1privateDNS = aws_instance.worker1.private_dns
    worker2privateDNS = aws_instance.worker2.private_dns
    worker3privateDNS = aws_instance.worker3.private_dns
  }) # templatefile allows us to use terraform to pass instance information to another instance
  tags = {
    Name = "Manager"
  }
}

# create 3 t2.micro worker instances
resource "aws_instance" "worker1" {
#  count         = 1
  ami           = "ami-0fc5d935ebf8bc3bc"
  vpc_security_group_ids = [aws_security_group.cluster_security_group.id]
  subnet_id = aws_subnet.proxy_cluster_subnet.id
  instance_type = "t2.micro"
  key_name = "mysql_kp"
  user_data = templatefile("worker_data_script.tpl", {
    accessKey = "${var.access_key}"
    secretKey = "${var.secret_key}"
    token = "${var.token}"
    mysql_kp = file("mysql_kp.pem")
  })
  tags = {
    Name = "Worker1"
  }
}

resource "aws_instance" "worker2" {
#  count         = 1
  ami           = "ami-0fc5d935ebf8bc3bc"
  vpc_security_group_ids = [aws_security_group.cluster_security_group.id]
  subnet_id = aws_subnet.proxy_cluster_subnet.id
  instance_type = "t2.micro"
  key_name = "mysql_kp"
  user_data = templatefile("worker_data_script.tpl", {
    accessKey = "${var.access_key}"
    secretKey = "${var.secret_key}"
    token = "${var.token}"
    mysql_kp = file("mysql_kp.pem")
  })
  tags = {
    Name = "Worker2"
  }
}

resource "aws_instance" "worker3" {
#  count         = 1
  ami           = "ami-0fc5d935ebf8bc3bc"
  vpc_security_group_ids = [aws_security_group.cluster_security_group.id]
  subnet_id = aws_subnet.proxy_cluster_subnet.id
  instance_type = "t2.micro"
  key_name = "mysql_kp"
  user_data = templatefile("worker_data_script.tpl", {
    accessKey = "${var.access_key}"
    secretKey = "${var.secret_key}"
    token = "${var.token}"
    mysql_kp = file("mysql_kp.pem")
  })
  tags = {
    Name = "Worker3"
  }
}

# output the instance ids for the workers
#output "t2_instance" {
#  value = [for instance in aws_instance.t2_workers: instance.id]
#}

# output the instance ids for the manager
# output "m4_orchestrator" {
#   value = aws_instance.m4_orchestrator.id
# }