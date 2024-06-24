locals {
  cka_bastion_subnet_id = "subnet-8534f8c8"
  cka_bastion_cidr_blocks = [
    "82.214.91.66/32",
    "34.199.203.217/32"
  ]
  cka_cp_subnet_id = "subnet-06b024af0b4242aa8"
  worker_ip        = ["172.31.10.101", "172.31.10.102"]
  cp_ip            = "172.31.10.100"

  #curr_state = "0: [${aws_instance.cka_cp[0].instance_state}] | 1: [${aws_instance.cka_worker[0].instance_state}] | 2: [${aws_instance.cka_worker[1].instance_state}]"
  #instance_state = "stop-instances"
  #instance_state = "start-instances"
}

data "aws_ami" "ubuntu" {

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-20240514"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

### "personal" key pair

resource "aws_key_pair" "norlov" {
  key_name   = "norlov@happiestbaby.com"
  public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINQRjf+yBbKDR2m3UAZbV8AAAgnHZsT3VIkgBJrAflx3"
}

### Bastion Host

resource "aws_eip" "cka_bastion" {
  instance = aws_instance.cka_bastion.id
  vpc      = true
}

resource "aws_security_group" "cka_bastion" {
  name        = "SG-cka-bastion"
  description = "SG for cka bastion host"
  ingress {
    from_port   = "22"
    to_port     = "22"
    protocol    = "tcp"
    cidr_blocks = local.cka_bastion_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "cka_bastion" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  key_name               = aws_key_pair.norlov.id
  vpc_security_group_ids = ["${aws_security_group.cka_bastion.id}"]
  subnet_id              = local.cka_bastion_subnet_id
  tags = {
    Name = "CKA-Bastion"
  }
}

### Control Plane Cluster

resource "aws_instance" "cka_cp" {
  count                  = 1
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.small"
  user_data              = base64encode(templatefile("${path.module}/cp_user_data.bash", {}))
  key_name               = aws_key_pair.norlov.id
  vpc_security_group_ids = ["${aws_security_group.cka_cp.id}"]
  subnet_id              = local.cka_bastion_subnet_id
  private_ip             = local.cp_ip
  tags = {
    Name      = "CKA-Control-Plane-${count.index}"
    Terraform = "True"
  }
}

resource "aws_instance" "cka_worker" {
  count                  = 2
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.small"
  user_data              = base64encode(templatefile("${path.module}/worker_user_data.bash", { worker_index = count.index + 1 }))
  key_name               = aws_key_pair.norlov.id
  vpc_security_group_ids = ["${aws_security_group.cka_cp.id}"]
  subnet_id              = local.cka_bastion_subnet_id
  private_ip             = element(local.worker_ip, count.index)
  tags = {
    Name      = "CKA-Worker-${count.index}"
    Terraform = "True"
  }
}


resource "aws_security_group" "cka_cp" {
  name        = "SG-cka-cp"
  description = "SG for cka contol plane hosts"
  ingress {
    from_port       = "0"
    to_port         = "0"
    protocol        = "-1"
    security_groups = [aws_security_group.cka_bastion.id]
    self            = true
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

output "cka_bastion_eip" {
  description = "Public IP address of bastion host"
  value       = aws_eip.cka_bastion.public_ip
}

#output "cp_instances_state" {
#  description = "Control plane instance state"
#  value       = local.curr_state
#}

output "cp_private_ip" {
  description = "Control Plane private IP"
  value       = "ssh -J ubuntu@${aws_eip.cka_bastion.public_ip} ubuntu@${aws_instance.cka_cp[0].private_ip}"
}

output "worker_private_ips" {
  description = "Worker nodes private IPs"
  value       = aws_instance.cka_worker[*].private_ip
}

output "start_instances" {
  description = "Use this command to start instances"
  value       = "terraform apply -var=\"instance_state=start-instances\""
}

### Helper to stop or start the EC2 instances
resource "null_resource" "this" {
  triggers = {
    always_run = "${timestamp()}"
  }
  provisioner "local-exec" {
    command = "aws --profile terraform-sb --region eu-central-1 ec2 ${var.instance_state} --instance-ids ${aws_instance.cka_bastion.id} ${aws_instance.cka_cp[0].id} ${aws_instance.cka_worker[0].id} ${aws_instance.cka_worker[1].id}"
  }
}
