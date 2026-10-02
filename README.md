# Ansible + Terraform Assignments

This repository contains two DevOps assignments completed on AWS using an
Ansible Control Node and Worker Node architecture.

## Architecture

```text
                    AWS Mumbai
                         |
              +----------+----------+
              |                     |
       Ansible Control Node    Worker Node
              |                     |
              | SSH                 |
              +-------------------->|
                                    |
                              Node.js App
                                Port 3000

Assignment 1 - Ansible
- EC2 Control Node and Worker Node
- SSH public/private key authentication
- Ansible inventory
- Ansible variables
- Node.js installation
- Git repository deployment
- npm dependency installation
- Node.js application startup
Application repository:
https://github.com/HiteshGupta03/ansible-node-app
Assignment 2 - Terraform + Ansible
- Terraform AWS provider
- EC2 Worker Node creation
- Security Group creation
- SSH configuration
- Dynamic Worker IP
- Terraform local-exec provisioner
- Automatic Ansible execution
- Node.js application deployment
AWS Region
ap-south-1 (Mumbai)
Instance Type
t3.micro
