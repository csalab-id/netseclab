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

resource "aws_key_pair" "checkpoint" {
  key_name   = var.name
  public_key = file("checkpoint.pub")
}

resource "aws_instance" "checkpoint" {
  ami           = "ami-05dfd2c03f1d36ad1" # Checkpoint
  instance_type = "c5.xlarge"
  key_name      = aws_key_pair.checkpoint.key_name

  tags = {
    Name = var.name
  }

  network_interface {
    network_interface_id = aws_network_interface.checkpoint_public.id
    device_index         = 0
  }

  network_interface {
    network_interface_id = aws_network_interface.checkpoint_mgmt.id
    device_index         = 1
  }

  network_interface {
    network_interface_id = aws_network_interface.checkpoint_private.id
    device_index         = 2
  }

  root_block_device {
    volume_type           = "gp2"
    volume_size           = 100
    delete_on_termination = true
    encrypted             = false
  }
}

resource "aws_instance" "management" {
  ami               = "ami-092f412f4c07be0db" # Windows Server 2016
  instance_type     = "t2.medium"
  key_name          = aws_key_pair.checkpoint.key_name
  get_password_data = "true"

  tags = {
    Name = "management"
  }

  network_interface {
    network_interface_id = aws_network_interface.mgmt.id
    device_index         = 0
  }

  root_block_device {
    volume_type           = "gp2"
    volume_size           = 60
    delete_on_termination = true
    encrypted             = false
  }
}

resource "aws_instance" "webserver" {
  ami           = "ami-02045ebddb047018b" # Ubuntu 22.04
  instance_type = "t2.micro"
  key_name      = aws_key_pair.checkpoint.key_name

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
  ami           = "ami-02045ebddb047018b" # Ubuntu 22.04
  instance_type = "t2.micro"
  key_name      = aws_key_pair.checkpoint.key_name

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

resource "aws_default_security_group" "checkpoint" {
  vpc_id      = aws_vpc.checkpoint.id

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
    from_port   = 3389
    to_port     = 3389
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

resource "aws_vpc" "checkpoint" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "checkpoint"
  }
}

resource "aws_subnet" "checkpoint_public" {
  vpc_id            = aws_vpc.checkpoint.id
  cidr_block        = "10.0.10.0/24"
  availability_zone = var.zone
  tags = {
    Name = "checkpoint_public"
  }
}

resource "aws_subnet" "checkpoint_mgmt" {
  vpc_id            = aws_vpc.checkpoint.id
  cidr_block        = "10.0.20.0/24"
  availability_zone = var.zone
  tags = {
    Name = "checkpoint_mgmt"
  }
}

resource "aws_subnet" "checkpoint_private" {
  vpc_id            = aws_vpc.checkpoint.id
  cidr_block        = "10.0.30.0/24"
  availability_zone = var.zone
  tags = {
    Name = "checkpoint_private"
  }
}

resource "aws_network_interface" "checkpoint_public" {
  subnet_id         = aws_subnet.checkpoint_public.id
  private_ips       = ["10.0.10.10"]
  source_dest_check = false

  tags = {
    Name = "checkpoint_public"
  }
}

resource "aws_network_interface" "checkpoint_mgmt" {
  subnet_id         = aws_subnet.checkpoint_mgmt.id
  private_ips       = ["10.0.20.10"]
  source_dest_check = false

  tags = {
    Name = "checkpoint_private"
  }
}

resource "aws_network_interface" "checkpoint_private" {
  subnet_id         = aws_subnet.checkpoint_private.id
  private_ips       = ["10.0.30.10"]
  source_dest_check = false

  tags = {
    Name = "checkpoint_mgmt"
  }
}

resource "aws_network_interface" "mgmt" {
  subnet_id   = aws_subnet.checkpoint_public.id
  private_ips = ["10.0.10.100"]

  tags = {
    Name = "mgmt"
  }
}

resource "aws_network_interface" "webserver" {
  subnet_id   = aws_subnet.checkpoint_private.id
  private_ips = ["10.0.30.100"]

  tags = {
    Name = "webserver"
  }
}

resource "aws_network_interface" "database" {
  subnet_id   = aws_subnet.checkpoint_private.id
  private_ips = ["10.0.30.200"]

  tags = {
    Name = "database"
  }
}

resource "aws_default_route_table" "checkpoint-public" {
  default_route_table_id =  aws_vpc.checkpoint.default_route_table_id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.checkpoint.id
  }
  tags = {
    Name = "checkpoint-public"
  }
}

resource "aws_route_table" "checkpoint-private" {
  vpc_id =  aws_vpc.checkpoint.id
  route {
    cidr_block           = "0.0.0.0/0"
    network_interface_id = aws_network_interface.checkpoint_mgmt.id
  }
  tags = {
    Name = "checkpoint-private"
  }
}

resource "aws_route_table_association" "checkpoint_public" {
  subnet_id      = aws_subnet.checkpoint_public.id
  route_table_id = aws_default_route_table.checkpoint-public.default_route_table_id
}

resource "aws_route_table_association" "checkpoint_mgmt" {
  subnet_id      = aws_subnet.checkpoint_mgmt.id
  route_table_id = aws_default_route_table.checkpoint-public.default_route_table_id
}

resource "aws_route_table_association" "checkpoint_private" {
  subnet_id      = aws_subnet.checkpoint_private.id
  route_table_id = aws_route_table.checkpoint-private.id
}

resource "aws_internet_gateway" "checkpoint" {
  tags = {
    Name = var.name
  }
}

resource "aws_internet_gateway_attachment" "checkpoint" {
  vpc_id              = aws_vpc.checkpoint.id
  internet_gateway_id = aws_internet_gateway.checkpoint.id
}

resource "aws_eip" "checkpoint" {
  vpc               = true
  network_interface = aws_network_interface.checkpoint_public.id
  tags = {
    Name = var.name
  }
}

resource "aws_eip_association" "checkpoint" {
  network_interface_id = aws_network_interface.checkpoint_public.id
  allocation_id        = aws_eip.checkpoint.id
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
  network_interface = aws_network_interface.checkpoint_mgmt.id
  tags = {
    Name = "webserver"
  }
}

resource "aws_eip_association" "webserver" {
  network_interface_id = aws_network_interface.checkpoint_mgmt.id
  allocation_id        = aws_eip.webserver.id
}

output "checkpoint_server" {
  value = "https://${aws_eip.checkpoint.public_ip}/"
}

output "checkpoint_access" {
  value = "ssh -i checkpoint admin@${aws_eip.checkpoint.public_ip}"
}

output "mgmt_access" {
  value = "rdp://${aws_eip.management.public_ip}:3389"
}

output "mgmt_password" {
  value = rsadecrypt(aws_instance.management.password_data, file("checkpoint.pem"))
}

output "webserver_ip" {
  value = "http://${aws_eip.webserver.public_ip}/"
}

variable "name" {
  type    = string
  default = "checkpoint"
}

variable "region" {
  type    = string
  default = "ap-southeast-1"
}

variable "zone" {
  type    = string
  default = "ap-southeast-1b"
}