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
make validate                   # fmt + validate + yamllint + ansible-lint + shellcheck + pytest
make deploy SCENARIO=gce        # обёртка над scripts/deploy.sh
make destroy SCENARIO=gce
```

## Что где смотреть после деплоя

- `gce`: output `public_ip` → `http://<ip>`.
- `gke-*`: `gcloud container clusters get-credentials` выполняет deploy.sh;
  доступ к приложению — `kubectl port-forward -n ai-nginx-demo svc/ai-nginx-app 8080:80`.
- `gke-gcs-cdn`: output `cdn_ip` (глобальный IP CDN), output `audio_bucket_name`
  (приватный бакет; аудио заливается автоматически плейбуком).
