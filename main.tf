provider "aws" {
  region = "us-east-1"
  access_key = "AKIATPSZT6L4X5LXOSGG"
  secret_key = "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"
}

#1 Create a VPC

resource "aws_vpc" "prod_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    "Name" = "production"
  }
}

#2 Internet Gateway

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.prod_vpc.id

  tags = {
    Name = "IGW"
  }
}

#3 Custom route table

resource "aws_route_table" "prod_route_table" {
  vpc_id = aws_vpc.prod_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    "Name" = "prod"
  }


}

#4 Subnet

resource "aws_subnet" "Subnet-1" {
  vpc_id     = aws_vpc.prod_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "Subnet-1"
  }
}

#5 Associate subnet to route table (Route table association)

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.Subnet-1.id
  route_table_id = aws_route_table.prod_route_table.id
}

#6 Create security group

resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.prod_vpc.id

  ingress {
    description = "HTTPS "
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP "
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH "
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_web"
  }
}



#7 Creating a network interface with an IP in the subnet that was created in step 4

resource "aws_network_interface" "web_server_NIC" {
  subnet_id       = aws_subnet.Subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]

}

#8 Assign a public IP

resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.web_server_NIC.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.gw]
  
}

#9 Ubuntu server

resource "aws_instance" "web_server" {
  ami = "ami-042e8287309f5df03"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  key_name = "New_ec2"
  network_interface {
    network_interface_id = aws_network_interface.web_server_NIC.id
    device_index = 0 
  }
  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install apache2 -y
              sudo systemctl start apache2
              sudo bash -c 'echo your very first web server >  /var/www/html/index.html'
              EOF

  tags = {
    "Name" = "Web Server"
  }
  
}