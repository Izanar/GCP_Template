# GCP_Template

[![Validate](https://github.com/Izanar/GCP_Template/actions/workflows/validate.yml/badge.svg)](https://github.com/Izanar/GCP_Template/actions/workflows/validate.yml)
![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.9-7B42BC?logo=terraform&logoColor=white)
![Terragrunt](https://img.shields.io/badge/Terragrunt-%3E%3D0.68-5C4EE5?logo=terraform&logoColor=white)
![Ansible](https://img.shields.io/badge/Ansible-EE0000?logo=ansible&logoColor=white)
![Kubernetes](https://img.shields.io/badge/Kubernetes-k3s%20%2F%20GKE-326CE5?logo=kubernetes&logoColor=white)
![GCP](https://img.shields.io/badge/GCP-GCE%20%2F%20GKE%20%2F%20GCS-4285F4?logo=googlecloud&logoColor=white)
![Platform](https://img.shields.io/badge/platform-WSL2%20%7C%20Linux-blue)
![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen)

A hands-on infrastructure template that deploys the [AI_Nginx](https://github.com/Izanar/AI_Nginx)
demo application (custom nginx site with the Kyiv Skyline static + audio page)
through four different setups using **Terraform**, **Terragrunt**, **Ansible**
and **Kubernetes**. Every scenario ends with the same app running: nginx
installed and configured, the AI_Nginx content served and a smoke test passed.

| Scenario | Infrastructure | Where |
|---|---|---|
| `gce` | GCP Compute Engine + nginx (Ansible) | Cloud (GCP) |
| `gke-autopilot` | GCP GKE Autopilot | Cloud (GCP) |
| `gke-gcs-cdn` | GCP GKE + private GCS + Cloud CDN | Cloud (GCP) |
| `local-wsl` | k3s on WSL2 | Local |

## Repository layout

```text
├── root.hcl                  Shared settings + generated provider/backend
├── envs/                     One Terragrunt unit per scenario
├── src/                      Self-contained Terraform roots
├── ansible/                  Playbooks and roles (nginx, gke, gke_gcs)
├── kubernetes/               Manifests (base/ for GKE, local/ for k3s)
├── scripts/                  deploy.sh, destroy.sh, WSL helpers
├── docs/                     Full documentation
└── .github/workflows/        validate.yml (CI) + deploy.yml (manual)
```

## Quick start

Requirements: Terraform >= 1.9, Terragrunt >= 0.68, Ansible and gcloud,
kubectl and gsutil for cloud scenarios.
`make install-tools` installs everything you need into your home directory
(Terraform, Terragrunt, Google Cloud CLI, kubectl, Ansible, linters).
Use `make install-tools SCENARIO=<scenario>` to install only what a scenario
needs: `gce` adds gcloud/gsutil, `gke-*` add gcloud + kubectl +
gke-gcloud-auth-plugin, `local-wsl` adds kubectl. Default `SCENARIO=all`
installs the full set.

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
| `gce` | `./scripts/deploy.sh gce` | Да (GCE + budget) | gcloud, `ansible-playbook`, SSH-ключи |
| `gke-autopilot` | `./scripts/deploy.sh gke-autopilot` | Да (GKE Autopilot + budget) | gcloud, `kubectl`, `ansible-playbook` |
| `gke-gcs-cdn` | `./scripts/deploy.sh gke-gcs-cdn` | Да (GKE + GCS + Cloud CDN + budget) | gcloud, `kubectl`, `gsutil`, `git`, `ansible-playbook` |
| `local-wsl` | `./scripts/deploy.sh local-wsl` | **Нет** | WSL2, `kubectl` |

> **Локальный сценарий (`local-wsl`)** — единственный, который не требует облачных ресурсов и не создаёт расходов. Его можно полностью протестировать локально на WSL2. Подробная пошаговая инструкция с командами для проверки каждого шага есть в [docs/usage.md](docs/usage.md#local-wsl--k3s-on-wsl2).

See [docs/usage.md](docs/usage.md) for the complete guide, including the
manual GitHub Actions deployment and required secrets.

### Команды Makefile

```bash
make help                          # показать все доступные команды
make install-tools                 # установить все инструменты (SCENARIO=all)
make install-tools SCENARIO=gce    # или: gke-autopilot | gke-gcs-cdn | local-wsl
make validate                      # статические проверки (Terraform, Ansible, K8s, Shell)
make init ENV=<scenario>          # terragrunt init для выбранного сценария
make plan ENV=<scenario>          # terragrunt plan
make apply ENV=<scenario>         # terragrunt apply (создаёт ресурсы!)
make output ENV=<scenario>        # показать выходные данные Terraform
make destroy ENV=<scenario>       # terragrunt destroy
make fmt                           # отформатировать Terraform-код
make precommit                     # запустить pre-commit хуки
```

Поддерживаемые значения `ENV`: `gce`, `gke-autopilot`, `gke-gcs-cdn`, `local-wsl`.
По умолчанию: `local-wsl`.

## Cloud credentials

The manual **Deploy** workflow provisions infrastructure using GitHub OIDC
(`GCP_WORKLOAD_IDENTITY_POOL` / `GCP_SERVICE_ACCOUNT`) and an existing GCS state
backend configured through repository variables (`TF_STATE_BUCKET`,
`TF_STATE_PREFIX`, `GOOGLE_PROJECT`, `GOOGLE_REGION`). The GCE scenario also
uses `BUDGET_EMAIL` / `BILLING_ACCOUNT` and rails SSH through the runner's IP.
Application deployment through the local scripts uses your local gcloud
credentials and SSH key pair. Set `BUDGET_EMAIL` to enable budget alerts.

## Documentation

- [docs/README.md](docs/README.md) - overview
- [docs/architecture.md](docs/architecture.md) - layout and data flow
- [docs/usage.md](docs/usage.md) - local control and CI/CD
- [docs/development.md](docs/development.md) - validation and contribution
- [docs/e2e.md](docs/e2e.md) - what a live end-to-end run is and how to run it
- [docs/completion.md](docs/completion.md) - cost control, state management and cleanup runbook

> This template creates real, billable resources in GCP. Use the manual
> `destroy` action or `./scripts/destroy.sh` after testing.

