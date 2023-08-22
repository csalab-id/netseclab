terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.48"
    }
  }
  required_version = ">= 1.3.0"
}

provider "aws" {
  region = var.region
}

resource "aws_key_pair" "paloalto" {
  key_name   = var.name
  public_key = file("paloalto.pub")
}

resource "aws_instance" "paloalto" {
  ami                    = "ami-0acf82986071d05e2" # Paloalto
  instance_type          = "c5n.xlarge"
  key_name               = aws_key_pair.paloalto.key_name

  tags = {
    Name = var.name
  }

  network_interface {
    network_interface_id = aws_network_interface.paloalto_public.id
    device_index         = 0
  }

  network_interface {
    network_interface_id = aws_network_interface.paloalto_mgmt.id
    device_index         = 1
  }

  network_interface {
    network_interface_id = aws_network_interface.paloalto_private.id
    device_index         = 2
  }

  root_block_device {
    volume_type           = "gp2"
    volume_size           = 60
    delete_on_termination = true
    encrypted             = false
  }
}

resource "aws_instance" "management" {
  ami                    = "ami-02045ebddb047018b" # Ubuntu 22.04
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.paloalto.key_name

  tags = {
    Name = "management"
  }

  network_interface {
    network_interface_id = aws_network_interface.mgmt.id
    device_index         = 0
  }

  root_block_device {
    volume_type           = "gp2"
    volume_size           = 30
    delete_on_termination = true
    encrypted             = false
  }
}

resource "aws_instance" "webserver" {
  ami                    = "ami-02045ebddb047018b" # Ubuntu 22.04
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.paloalto.key_name

  tags = {
    Name = "webserver"
  }

  network_interface {
    network_interface_id = aws_network_interface.webserver.id
    device_index         = 0
  }

  root_block_device {
    volume_type           = "gp2"
    volume_size           = 30
    delete_on_termination = true
    encrypted             = false
  }
}

resource "aws_instance" "database" {
  ami                    = "ami-02045ebddb047018b" # Ubuntu 22.04
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.paloalto.key_name

  tags = {
    Name = "database"
  }

  network_interface {
    network_interface_id = aws_network_interface.database.id
    device_index         = 0
  }

  root_block_device {
    volume_type           = "gp2"
    volume_size           = 60
    delete_on_termination = true
    encrypted             = false
  }
}

resource "aws_default_security_group" "paloalto" {
  vpc_id      = aws_vpc.paloalto.id

  tags = {
    Name = var.name
  }

  ingress {
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_vpc" "paloalto" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "paloalto"
  }
}

resource "aws_subnet" "paloalto_public" {
  vpc_id            = aws_vpc.paloalto.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = var.zone
  tags = {
    Name = "paloalto_public"
  }
}

resource "aws_subnet" "paloalto_mgmt" {
  vpc_id            = aws_vpc.paloalto.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = var.zone
  tags = {
    Name = "paloalto_mgmt"
  }
}

resource "aws_subnet" "paloalto_private" {
  vpc_id            = aws_vpc.paloalto.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = var.zone
  tags = {
    Name = "paloalto_private"
  }
}

resource "aws_network_interface" "paloalto_public" {
  subnet_id         = aws_subnet.paloalto_public.id
  private_ips       = ["10.0.1.10"]
  source_dest_check = false

  tags = {
    Name = "paloalto_public"
  }
}

resource "aws_network_interface" "paloalto_mgmt" {
  subnet_id         = aws_subnet.paloalto_mgmt.id
  private_ips       = ["10.0.2.10"]
  source_dest_check = false

  tags = {
    Name = "paloalto_private"
  }
}

resource "aws_network_interface" "paloalto_private" {
  subnet_id         = aws_subnet.paloalto_private.id
  private_ips       = ["10.0.3.10"]
  source_dest_check = false

  tags = {
    Name = "paloalto_mgmt"
  }
}

resource "aws_network_interface" "mgmt" {
  subnet_id   = aws_subnet.paloalto_public.id
  private_ips = ["10.0.1.100"]

  tags = {
    Name = "mgmt"
  }
}

resource "aws_network_interface" "webserver" {
  subnet_id   = aws_subnet.paloalto_private.id
  private_ips = ["10.0.3.100"]

  tags = {
    Name = "webserver"
  }
}

resource "aws_network_interface" "database" {
  subnet_id   = aws_subnet.paloalto_private.id
  private_ips = ["10.0.3.200"]

  tags = {
    Name = "database"
  }
}

resource "aws_default_route_table" "paloalto-public" {
  default_route_table_id =  aws_vpc.paloalto.default_route_table_id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.paloalto.id
  }
  tags = {
    Name = "paloalto-public"
  }
}

resource "aws_route_table" "paloalto-private" {
  vpc_id =  aws_vpc.paloalto.id
  route {
    cidr_block           = "0.0.0.0/0"
    network_interface_id = aws_network_interface.paloalto_mgmt.id
  }
  tags = {
    Name = "paloalto-private"
  }
}

resource "aws_route_table_association" "paloalto_public" {
  subnet_id      = aws_subnet.paloalto_public.id
  route_table_id = aws_default_route_table.paloalto-public.default_route_table_id
}

resource "aws_route_table_association" "paloalto_mgmt" {
  subnet_id      = aws_subnet.paloalto_mgmt.id
  route_table_id = aws_default_route_table.paloalto-public.default_route_table_id
}

resource "aws_route_table_association" "paloalto_private" {
  subnet_id      = aws_subnet.paloalto_private.id
  route_table_id = aws_route_table.paloalto-private.id
}

resource "aws_internet_gateway" "paloalto" {
  tags = {
    Name = var.name
  }
}

resource "aws_internet_gateway_attachment" "paloalto" {
  vpc_id              = aws_vpc.paloalto.id
  internet_gateway_id = aws_internet_gateway.paloalto.id
}

resource "aws_eip" "paloalto" {
  vpc               = true
  network_interface = aws_network_interface.paloalto_public.id
  tags = {
    Name = var.name
  }
}

resource "aws_eip_association" "paloalto" {
  network_interface_id = aws_network_interface.paloalto_public.id
  allocation_id        = aws_eip.paloalto.id
}

resource "aws_eip" "management" {
  instance = aws_instance.management.id
  tags = {
    Name = "management"
  }
}

resource "aws_eip_association" "management" {
  instance_id   = aws_instance.management.id
  allocation_id = aws_eip.management.id
}

resource "aws_eip" "webserver" {
  vpc               = true
  network_interface = aws_network_interface.paloalto_mgmt.id
  tags = {
    Name = "webserver"
  }
}

resource "aws_eip_association" "webserver" {
  network_interface_id = aws_network_interface.paloalto_mgmt.id
  allocation_id        = aws_eip.webserver.id
}

output "paloalto_server" {
  value = "https://${aws_eip.paloalto.public_ip}/"
}

output "paloalto_access" {
  value = "ssh -i paloalto -oHostKeyAlgorithms=+ssh-rsa admin@${aws_eip.paloalto.public_ip}"
}

output "mgmt_access" {
  value = "ssh -i paloalto ubuntu@${aws_eip.management.public_ip}"
}

output "webserver_ip" {
  value = "http://${aws_eip.webserver.public_ip}/"
}

variable "name" {
  type    = string
  default = "paloalto"
}

variable "region" {
  type    = string
  default = "ap-southeast-1"
}

variable "zone" {
  type    = string
  default = "ap-southeast-1c"
}