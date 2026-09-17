# AWS_Template documentation

Welcome to the AWS_Template documentation. This project is a hands-on,
reusable infrastructure template that demonstrates the
[AI_Nginx](https://github.com/Izanar/AI_Nginx) demo application deployed with
four different setups:

| Scenario | Infrastructure | Applies to |
|---|---|---|
| `ec2` | AWS Spot EC2 + nginx, configured with Ansible | Cloud (AWS) |
| `eks-fargate` | AWS EKS cluster (Fargate profiles) | Cloud (AWS) |
| `eks-ec2-s3` | AWS EKS + S3 + CloudFront with OAC | Cloud (AWS) |
| `local-wsl` | k3s on WSL2, no cloud required | Local (WSL2) |

Terraform defines the infrastructure, Terragrunt supplies per-environment
values, Ansible configures the running servers/clusters, and Kubernetes
manifests describe the deployed workload.

## Table of contents

- [Architecture](architecture.md) - repository layout and data flow
- [Usage](usage.md) - local control, CI/CD, requirements
- [Development](development.md) - validation, testing, contributing

## Prerequisites

- Terraform `>= 1.9.0`
- Terragrunt `>= 0.68.0`
- Ansible `core 2.15+` (only for `ec2` / EKS deploys)
- AWS CLI (only for cloud scenarios)

`make install-tools` installs Terraform, Terragrunt and the Python tooling
into `~/.local/bin` and `~/venvs/tools` (latest releases).
