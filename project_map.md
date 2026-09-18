# Карта проекта GCP_Template

## Корень

| Путь | Назначение |
|---|---|
| `root.hcl` | Общий Terragrunt-конфиг: провайдер `google`, GCS/локальный backend |
| `CONTEXT.md` | Контекст и правила для ИИ-агентов |
| `README.md` | Описание проекта для людей |
| `Makefile` | `make install-tools SCENARIO=…`, `make validate`, `make init/plan/apply/destroy/output ENV=…` |
| `project_map.md` | Этот файл |

## Окружения Terragrunt (envs/)

| Путь | Сценарий |
|---|---|
| `envs/gce/terragrunt.hcl` | Compute Engine + nginx |
| `envs/gke-autopilot/terragrunt.hcl` | GKE Autopilot |
| `envs/gke-gcs-cdn/terragrunt.hcl` | GKE + GCS + Cloud CDN |
| `envs/local-wsl/terragrunt.hcl` | Локальный k3s (WSL2) |

## Terraform-модули (src/)

| Модуль | Ключевые ресурсы |
|---|---|
| `src/gce` | `google_compute_instance`, firewall'ы ssh/web, опциональный бюджет |
| `src/gke-autopilot` | `google_container_cluster` (autopilot), Secret Manager, бюджет |
| `src/gke-gcs-cdn` | GKE Standard, приватный `google_storage_bucket` (аудио), backend bucket + Cloud CDN, глобальный IP |
| `src/local-wsl` | null/random: установка k3s и локальный NodePort-деплой |

## Скрипты (scripts/)

| Скрипт | Назначение |
|---|---|
| `deploy.sh [gce\|gke-autopilot\|gke-gcs-cdn\|local-wsl]` | Полный деплой сценария |
| `destroy.sh [scenario]` | Уничтожение ресурсов сценария |
| `install-wsl-kubernetes.sh` | k3s в WSL2, kubeconfig → `~/.kube/gcp-template-k3s.yaml` |
| `sync-audio-to-gcs.sh <repo> <bucket>` | Заливка аудио из AI_Nginx в приватный GCS |

## Ansible (ansible/)

| Плейбук | Роль | Где применяется |
|---|---|---|
| `playbooks/gce.yml` | `roles/nginx` | Настройка nginx на VM |
| `playbooks/gke-deploy.yml` | `roles/gke` | Деплой манифестов `kubernetes/base` в GKE |
| `playbooks/gke-gcs-deploy.yml` | `roles/gke_gcs` | Вариант с приватным GCS-аудио через CDN |

## Kubernetes (kubernetes/)

- `base/` — манифесты для GKE (namespace `ai-nginx-demo`, deployment, service).
- `local/` — манифесты для локального k3s (hostPath, NodePort 30080).

## CI (.github/workflows/)

| Workflow | Назначение |
|---|---|
| `validate.yml` | fmt/validate/линтеры/pytest на PR |
| `build-images.yml` | Сборка и публикация `ghcr.io/izanar/gcp-template-kubernetes` |
| `deploy.yml` | Ручной/автоматический деплой (требует секреты GCP) |

## Прочее

- `tests/` — pytest-проверки структуры и конфигурации.
- `docs/` — документация (usage, architecture, development, e2e, completion).
