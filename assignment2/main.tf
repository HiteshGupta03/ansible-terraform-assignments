terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region = "ap-south-1"
}

# Default VPC
data "aws_vpc" "default" {
  default = true
}

# Subnets in the default VPC
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Latest Ubuntu 24.04 LTS AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Existing Control Node security group
data "aws_security_group" "control_sg" {
  id = "sg-03470ec5ea0727a69"
}

# Security group for Terraform-created Worker Node
resource "aws_security_group" "app_sg" {
  name        = "terraform-worker-sg"
  description = "Security group for Terraform Worker Node"
  vpc_id      = data.aws_vpc.default.id

  # SSH from Control Node
  ingress {
    description     = "SSH from Ansible Control Node"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [data.aws_security_group.control_sg.id]
  }

  # Node.js application
  ingress {
    description = "Node.js application"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "terraform-worker-sg"
  }
}

# Terraform creates the Worker Node
resource "aws_instance" "worker" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  key_name                    = "ssh-for-ansible"
  subnet_id                   = data.aws_subnets.default.ids[0]
  vpc_security_group_ids      = [aws_security_group.app_sg.id]
  associate_public_ip_address = true

  # Add Control Node public key to Worker Node
  user_data = <<-USERDATA
    #!/bin/bash
    mkdir -p /home/ubuntu/.ssh
    chmod 700 /home/ubuntu/.ssh
    echo '${trimspace(file("/home/ubuntu/.ssh/id_rsa.pub"))}' >> /home/ubuntu/.ssh/authorized_keys
    chmod 600 /home/ubuntu/.ssh/authorized_keys
    chown -R ubuntu:ubuntu /home/ubuntu/.ssh
  USERDATA

  tags = {
    Name = "terraform-worker-node"
  }

  # Wait until SSH key authentication is actually available
  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for Worker SSH authentication..."

      for i in {1..30}; do
        if ssh \
          -o StrictHostKeyChecking=no \
          -o UserKnownHostsFile=/dev/null \
          -o ConnectTimeout=5 \
          -o BatchMode=yes \
          -i /home/ubuntu/.ssh/id_rsa \
          ubuntu@${self.private_ip} "echo SSH_READY" 2>/dev/null | grep -q SSH_READY; then

          echo "Worker SSH authentication is ready."
          break
        fi

        echo "Worker is not ready yet... attempt $i/30"
        sleep 10
      done

      echo "Creating Ansible inventory..."

      cat > inventory.ini <<INVENTORY
[webservers]
worker-node ansible_host=${self.private_ip}

[webservers:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=/home/ubuntu/.ssh/id_rsa
INVENTORY

      echo "Running Ansible playbook..."

      ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i inventory.ini playbook.yml
    EOT
  }
}

output "worker_private_ip" {
  value = aws_instance.worker.private_ip
}

output "worker_public_ip" {
  value = aws_instance.worker.public_ip
}
