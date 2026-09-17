# Архитектура GCP_Template

## Общая схема

Terragrunt-репозиторий: `root.hcl` задаёт провайдера и backend, `envs/*` — точки входа
сценариев, `src/*` — Terraform-модули, `scripts/` и `ansible/` — пост-настройка и деплой
приложения.

## Сценарии

### gce (дешёвый облачный)

- `google_compute_instance` `e2-micro`, `pd-balanced` 10 GB, Ubuntu 22.04, preemptible
  (аналог Spot).
- Firewall: SSH только из `TF_VAR_ssh_cidr_blocks` (ваш IP/32), HTTP/HTTPS — 0.0.0.0/0.
- Публичный ephemeral IP → output `public_ip`.
- Ansible (`roles/nginx`) ставит nginx и выкладывает AI_Nginx из
  `github.com/Izanar/AI_Nginx`.
- Опционально: `google_billing_budget` + email-канал уведомлений.

### gke-autopilot

- `google_container_cluster` с `enable_autopilot = true` (Google управляет нодами),
  Workload Identity, региональный кластер.
- Пароль приложения: `random_password` → Secret Manager.
- Деплой приложения — плейбук `gke-deploy.yml` (манифесты `kubernetes/base`,
  образ `ghcr.io/izanar/gcp-template-kubernetes`).

### gke-gcs-cdn

- GKE Standard: regional cluster, node pool `e2-small` (Spot, autoscaling 1–2),
  default node pool удаляется.
- Приватный `google_storage_bucket` (uniform bucket-level access, public access
  prevention, versioning, lifecycle Delete через 7 дней) — аудио приложения.
- Доступ CDN к приватному бакету — `google_storage_bucket_iam_member`
  (`roles/storage.objectViewer` сервис-аккаунту Cloud CDN `service-<PROJECT_NUMBER>@cloud-cdn.gserviceaccount.com`).
- Раздача: `google_compute_backend_bucket` (enable_cdn) → url_map → http-proxy →
  global forwarding rule :80 → статический `cdn_ip`.
- Аудио заливает `scripts/sync-audio-to-gcs.sh` (gsutil rsync, только добавление).

### local-wsl

- Без облака: `scripts/install-wsl-kubernetes.sh` ставит k3s (systemd в WSL2),
  kubeconfig → `~/.kube/gcp-template-k3s.yaml`.
- Деплой манифестов `kubernetes/local` (hostPath, NodePort 30080), smoke-тест curl.

## Стейт и доступ

- Backend: локальный по умолчанию; GCS при `TF_STATE_BUCKET`
  (`<prefix>/<region>/<env>`), лочится версионированием объектов GCS.
- Провайдер `google` генерируется в `root.hcl` (`project`, `region` из окружения);
  `local-wsl` получает минимальный провайдер без учётных данных.

## CI/CD

- `validate.yml` — fmt/validate/линтеры/pytest на PR и push.
- `build-images.yml` — сборка образа приложения в GHCR.
- `deploy.yml` — деплой по секретам GCP (заполняются при первом реальном использовании).
