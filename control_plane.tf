locals {
  cka_bastion_subnet_id   = "subnet-8534f8c8"  
  cka_bastion_cidr_blocks = [
    "82.214.91.66/32",
  ]
  cka_cp_subnet_id        = "subnet-06b024af0b4242aa8"
  curr_state = "0: [${aws_instance.cka_cp[0].instance_state}] | 1: [${aws_instance.cka_cp[1].instance_state}] | 2: [${aws_instance.cka_cp[2].instance_state}]"

  #instance_state = "stop-instances"
  instance_state = "start-instances"
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_key_pair" "norlov" {
  key_name   = "norlov@happiestbaby.com"
  public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICzv5oRU54WzKGUPKcYEdPPNqp+nzDmOh5EYFWOlD/Kq"
}

### Bastion Host

resource "aws_eip" "cka_bastion" {
  instance = aws_instance.cka_bastion.id
  vpc      = true
}

resource "aws_security_group" "cka_bastion" {
  name          = "SG-cka-bastion"
  description   = "SG for cka bastion host"
  ingress {
    from_port   = "22"
    to_port     = "22"
    protocol    = "tcp"
    cidr_blocks = local.cka_bastion_cidr_blocks
  }
}

resource "aws_instance" "cka_bastion" {
  ami                     = data.aws_ami.ubuntu.id
  instance_type           = "t3.micro"
  key_name                = aws_key_pair.norlov.id
  vpc_security_group_ids  = [ "${aws_security_group.cka_bastion.id}" ]
  subnet_id               = local.cka_bastion_subnet_id
  tags                    = {
    Name  = "CKA-Bastion"
  }
}

output "cka_bastion_eip" {
  description = "Public IP address of bastion host"
  value       = aws_eip.cka_bastion.public_ip
}

### Control Plane Cluster

resource "aws_instance" "cka_cp" {
  count = 3
    ami             = data.aws_ami.ubuntu.id
    instance_type   = "t3.micro"
    key_name        = aws_key_pair.norlov.id
    vpc_security_group_ids = [ "${aws_security_group.cka_cp.id}" ]
    subnet_id       = local.cka_bastion_subnet_id
    tags            = {
      Name  = "CKA-Control-Plane-${count.index}"
    }
}

resource "aws_security_group" "cka_cp" {
  name          = "SG-cka-cp"
  description   = "SG for cka contol plane hosts"
  ingress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    security_groups = [ aws_security_group.cka_bastion.id ]
  }
}

output "cp_instances_state" {
  description = "Control plane instance state"
  value       = local.curr_state
}

### Helper
resource "null_resource" "this" {
  triggers = {
    always_run = "${timestamp()}"
  }
  provisioner "local-exec" {
    command = "aws --profile sandbox ec2 ${local.instance_state} --instance-ids ${aws_instance.cka_bastion.id} ${aws_instance.cka_cp[0].id} ${aws_instance.cka_cp[1].id} ${aws_instance.cka_cp[2].id}"
  }
}
