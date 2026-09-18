# Использование GCP_Template

## Быстрый старт (без облака)

```bash
make install-tools
./scripts/install-wsl-kubernetes.sh   # k3s в WSL2 (нужен systemd)
./scripts/deploy.sh local-wsl         # деплой AI_Nginx, NodePort 30080
# http://localhost:30080 (WSL) или http://<WSL-IP>:30080 (Windows)
./scripts/destroy.sh local-wsl
```

## Облачные сценарии

```bash
./scripts/deploy.sh gce            # Compute Engine + nginx (дешёвый)
./scripts/deploy.sh gke-autopilot  # GKE Autopilot (дорого; в планах агентов НЕ значится)
./scripts/deploy.sh gke-gcs-cdn    # GKE + приватный GCS + Cloud CDN (дорого; НЕ в планах)
./scripts/destroy.sh <scenario>
```

Скрипты интерактивно спрашивают: `GOOGLE_PROJECT`, `GOOGLE_REGION` (дефолт
`europe-west1`), email для бюджета (опционально) и подтверждение расходов.
Для `gce` дополнительно: путь к SSH-ключу; SSH открывается только с вашего IP (`/32`).

## Аутентификация: личный gcloud или сервисный аккаунт

Облачные сценарии работают с любым из двух способов:

1. **Личный аккаунт** (интерактивно):
   ```bash
   gcloud auth login
   gcloud auth application-default login   # ADC для Terraform
   gcloud config set project <PROJECT_ID>
   ```
2. **Сервисный аккаунт (SA-ключ JSON)** — без интерактива:
   ```bash
   gcloud auth activate-service-account --key-file=<путь/к/sa-key.json>
   export GOOGLE_APPLICATION_CREDENTIALS=<путь/к/sa-key.json>  # ADC для Terraform
   export GOOGLE_PROJECT=<PROJECT_ID>
   ```
   Ключ храните вне репозитория (например, `~/.config/gcloud/`), права на файл
   `600`. SA нужны роли `Compute Admin` (для `gce`) и `Service Usage Consumer`.

## Переменные окружения

| Переменная | Назначение | Дефолт |
|---|---|---|
| `GOOGLE_PROJECT` | ID проекта GCP | — (обязателен для облака) |
| `GOOGLE_REGION` | Регион | `europe-west1` |
| `GOOGLE_ZONE` | Зона (gce) | `europe-west1-b` |
| `BUDGET_EMAIL` + `BILLING_ACCOUNT` | Включают бюджет-алерт на 5 USD/мес | выключен |
| `GOOGLE_PROJECT_NUMBER` | Номер проекта для фильтра бюджета (gce) | — |
| `TF_STATE_BUCKET` | GCS-бакет для удалённого стейта (создаётся вне шаблона) | локальный стейт |
| `TF_STATE_PREFIX` | Префикс ключей стейта | `gcp-template` |
| `TF_VAR_public_key_path` | Публичный SSH-ключ (gce) | `~/.ssh/id_rsa.pub` |
| `TF_VAR_ssh_cidr_blocks` | JSON-список CIDR для SSH (gce) | `[]` |
| `APP_IMAGE_TAG` | Тег образа для GKE-деплоя | `latest` |

## Makefile

```bash
make install-tools              # terraform, terragrunt, ansible, линтеры
make install-tools SCENARIO=gce # + Google Cloud CLI (gcloud, gsutil)
make install-tools SCENARIO=gke-autopilot  # + gcloud, kubectl, gke-gcloud-auth-plugin
make install-tools SCENARIO=local-wsl      # только базовые инструменты (k3s ставится отдельно)
make validate                   # fmt + validate + yamllint + ansible-lint + shellcheck
make init ENV=gce               # terragrunt init
make plan ENV=gce               # terragrunt plan
make apply ENV=gce CONFIRM_COSTS=yes   # terragrunt apply (создаёт ресурсы!)
make destroy ENV=gce            # terragrunt destroy
make output ENV=gce             # показать outputs
```

Полный деплой сценария (init → plan → apply → Ansible → smoke-тест) выполняет
`./scripts/deploy.sh <scenario>`; `make apply/destroy` — тонкие обёртки над Terragrunt.

## Что где смотреть после деплоя

- `gce`: output `public_ip` → `http://<ip>`.
- `gke-*`: `gcloud container clusters get-credentials` выполняет deploy.sh;
  доступ к приложению — `kubectl port-forward -n ai-nginx-demo svc/ai-nginx-app 8080:80`.
- `gke-gcs-cdn`: output `cdn_ip` (глобальный IP CDN), output `audio_bucket_name`
  (приватный бакет; аудио заливается автоматически плейбуком).
