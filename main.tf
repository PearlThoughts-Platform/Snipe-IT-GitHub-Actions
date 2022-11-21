# terraform {
#   cloud {
#     organization = "project-demo-17-11-2022"

#     workspaces {
#       name = "snipe-git-actions"
#     }
#   }
# }

# use ubuntu 20 AMI for EC2 instance
data "aws_ami" "ubuntu" {
    most_recent = true
filter {
        name   = "name"
        values = ["ubuntu/images/hvm-ssd/*20.04-amd64-server-*"]
    }
filter {
        name   = "virtualization-type"
        values = ["hvm"]
    }
owners = ["099720109477"] # Canonical
}

provider "aws" {
  region  = "ap-south-1"
}
resource "aws_instance" "app_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  key_name      = "app-ssh-key"
tags = {
    Name = var.ec2_name
  }
}

variable "ec2_name" {
  type = string
}


# #######################
terraform {
    required_providers {
        aws = {
            source = "hashicorp/aws"
            # optional
            version = "~> 3.0"
       }
    }
}

# Creating a VPC
resource "aws_vpc" "test-vpc" {
    cidr_block = "10.0.0.0/16"
}

# Create an Internet Gateway
resource "aws_internet_gateway" "test-ig" {
    vpc_id = aws_vpc.test-vpc.id
    tags = {
        Name = "gateway1"
    }
}

# Setting up the route table
resource "aws_route_table" "test-rt" {
    vpc_id = aws_vpc.test-vpc.id
    route {
        # pointing to the internet
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.test-ig.id
    }
    route {
        ipv6_cidr_block = "::/0"
        gateway_id = aws_internet_gateway.test-ig.id
    }
    tags = {
        Name = "rt1"
    }
}

# Setting up the subnet
resource "aws_subnet" "test-subnet" {
    vpc_id = aws_vpc.test-vpc.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "ap-south-1"
    tags = {
        Name = "subnet1"
    }
}

# Associating the subnet with the route table
resource "aws_route_table_association" "test-rt-sub-assoc" {
    subnet_id = aws_subnet.test-subnet.id
    route_table_id = aws_route_table.test-rt.id
}

# Creating a Security Group
resource "aws_security_group" "test-sg" {
    name = "test-sg"
    description = "Enable web traffic for the project"
    vpc_id = aws_vpc.test-vpc.id
    ingress {
        description = "HTTPS traffic"
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        description = "HTTP traffic"
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        description = "SSH port"
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
        ipv6_cidr_blocks = ["::/0"]
    }
    tags = {
        Name = "test-sg1"
    }
}

# Creating a new network interface
resource "aws_network_interface" "test-ni" {
    subnet_id = aws_subnet.test-subnet.id
    private_ips = ["10.0.1.10"]
    security_groups = [aws_security_group.test-sg.id]
}

# Attaching an elastic IP to the network interface
resource "aws_eip" "test-eip" {
    vpc = true
    network_interface = aws_network_interface.test-ni.id
    associate_with_private_ip = "10.0.1.10"
}

# Creating an Ubuntu EC2 instance
resource "aws_instance" "test-instance" {
    ami = "ami-08161112e301e70b4"
    instance_type = "t2.micro"
    availability_zone = "ap-south-1"
    key_name = "<your-aws-key>"
    network_interface {
        device_index = 0
        network_interface_id = aws_network_interface.test-ni.id
    }
    user_data = <<-EOF
            #!/bin/bash
            sudo apt update -y
            sudo apt-get install \
                    ca-certificates \
                    curl \
                    gnupg \
                    lsb-release;
            sudo mkdir -p /etc/apt/keyrings;
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg;
            echo \
            "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
            $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null ;
            sudo apt-get update;
            sudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin docker-compose;
            git clone https://github.com/AkshayV30/Snipe-IT-GitHub-Actions.git
            cd /Snipe-IT-GitHub-Actions
            docker compose up 
            
    EOF
    tags = {
        Name = "test-instance"
    }
}   
