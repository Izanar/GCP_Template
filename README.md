# AWS_Template

[![Validate](https://github.com/Izanar/AWS_Template/actions/workflows/validate.yml/badge.svg)](https://github.com/Izanar/AWS_Template/actions/workflows/validate.yml)
![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.9-7B42BC?logo=terraform&logoColor=white)
![Terragrunt](https://img.shields.io/badge/Terragrunt-%3E%3D0.68-5C4EE5?logo=terraform&logoColor=white)
![Ansible](https://img.shields.io/badge/Ansible-EE0000?logo=ansible&logoColor=white)
![Kubernetes](https://img.shields.io/badge/Kubernetes-k3s%20%2F%20EKS-326CE5?logo=kubernetes&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-EC2%20%2F%20EKS%20%2F%20S3-232F3E?logo=amazonwebservices&logoColor=white)
![Platform](https://img.shields.io/badge/platform-WSL2%20%7C%20Linux-blue)
![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen)

A hands-on infrastructure template that deploys the [AI_Nginx](https://github.com/Izanar/AI_Nginx)
demo application (custom nginx site with the Kyiv Skyline static + audio page)
through four different setups using **Terraform**, **Terragrunt**, **Ansible**
and **Kubernetes**. Every scenario ends with the same app running: nginx
installed and configured, the AI_Nginx content served and a smoke test passed.

| Scenario | Infrastructure | Where |
|---|---|---|
| `ec2` | AWS Spot EC2 + nginx (Ansible) | Cloud (AWS) |
| `eks-fargate` | AWS EKS cluster (Fargate profiles) | Cloud (AWS) |
| `eks-ec2-s3` | AWS EKS + S3 + CloudFront (OAC) | Cloud (AWS) |
| `local-wsl` | k3s on WSL2 | Local |

## Repository layout

```text
├── root.hcl                  Shared settings + generated provider.tf
├── envs/                     One Terragrunt unit per scenario
├── src/                      Self-contained Terraform roots
├── ansible/                  Playbooks and roles (nginx, deploy_site, eks)
├── kubernetes/               Manifests (base/ for EKS, local/ for k3s)
├── scripts/                  deploy.sh, destroy.sh, WSL helpers
├── docs/                     Full documentation
└── .github/workflows/        validate.yml (CI) + deploy.yml (manual)
```

## Quick start

Requirements: Terraform >= 1.9, Terragrunt >= 0.68, Ansible, `aws` CLI for
cloud scenarios. `make install-tools` installs everything into your home
directory.

```bash
# 1. Install tools (Terraform, Terragrunt, Ansible, Python deps)
make install-tools

# 2. Validate everything compiles (static checks, no resources created)
make validate

# 3. Deploy a scenario
./scripts/deploy.sh <scenario>

# 4. Destroy when done
./scripts/destroy.sh <scenario>
```

### Доступные сценарии

| Сценарий | Команда | Облачные ресурсы? | Что нужно |
|---|---|---|---|
| `ec2` | `./scripts/deploy.sh ec2` | Да (EC2 Spot) | AWS creds, `aws` CLI, SSH-ключи |
| `eks-fargate` | `./scripts/deploy.sh eks-fargate` | Да (EKS) | AWS creds, `aws` CLI, `kubectl` |
| `eks-ec2-s3` | `./scripts/deploy.sh eks-ec2-s3` | Да (EKS + S3 + CloudFront) | AWS creds, `aws` CLI, `kubectl` |
| `local-wsl` | `./scripts/deploy.sh local-wsl` | **Нет** | WSL2, `kubectl` |

> **Локальный сценарий (`local-wsl`)** — единственный, который не требует облачных ресурсов и не создаёт расходов. Его можно полностью протестировать локально на WSL2. Подробная пошаговая инструкция с командами для проверки каждого шага есть в [docs/usage.md](docs/usage.md#4-local-wsl--k3s-on-wsl2-no-cloud).

See [docs/usage.md](docs/usage.md) for the complete guide, including the
manual GitHub Actions deployment and required secrets.

### Команды Makefile

```bash
make help                          # показать все доступные команды
make validate                      # статические проверки (Terraform, Ansible, K8s, Shell)
make install-tools                 # установить Terraform, Terragrunt, Ansible и Python-инструменты
make init ENV=<scenario>          # terragrunt init для выбранного сценария
make plan ENV=<scenario>          # terragrunt plan
make apply ENV=<scenario>         # terragrunt apply (создаёт ресурсы!)
make output ENV=<scenario>        # показать выходные данные Terraform
make destroy ENV=<scenario>       # terragrunt destroy
make fmt                           # отформатировать Terraform-код
make precommit                     # запустить pre-commit хуки
```

Поддерживаемые значения `ENV`: `ec2`, `eks-fargate`, `eks-ec2-s3`, `local-wsl`.
По умолчанию: `local-wsl`.

## Cloud credentials

The manual **Deploy** workflow provisions infrastructure using GitHub OIDC
(`AWS_ROLE_ARN`) and an existing state backend configured through `TF_STATE_BUCKET`,
`TF_STATE_REGION` and `TF_LOCK_TABLE` repository variables. EC2 also requires
`AWS_SSH_PUBLIC_KEY`. Application deployment through the local scripts uses your
local AWS profile and SSH key pair. Set `BUDGET_EMAIL` to enable budget alerts.

## Documentation

- [docs/README.md](docs/README.md) - overview
- [docs/architecture.md](docs/architecture.md) - layout and data flow
- [docs/usage.md](docs/usage.md) - local control and CI/CD
- [docs/development.md](docs/development.md) - validation and contribution
- [docs/e2e.md](docs/e2e.md) - what a live end-to-end run is and how to run it
- [docs/completion.md](docs/completion.md) - cost control, state management and cleanup runbook

> This template creates real, billable resources in AWS. Use the manual
> `destroy` action or `./scripts/destroy.sh` after testing.
