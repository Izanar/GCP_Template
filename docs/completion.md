# Отчёт о выполнении: адаптация AWS_Template → GCP_Template

## Выполнено

1. **Terraform-модули** (`src/`): `gce`, `gke-autopilot`, `gke-gcs-cdn`, `local-wsl` —
   все на провайдере `google ~> 8.3`. Проверены `terraform validate` по каждому.
2. **Terragrunt**: `root.hcl` (GCS/локальный backend, провайдер), `envs/*` под GCP.
   Проверено: `hclfmt`, `validate-inputs` по всем средам, полный `init + plan`
   для `local-wsl` (`Plan: 1 to add`), `terragrunt init` для облачных сред.
3. **Скрипты**: `deploy.sh`, `destroy.sh` (интерактив: project/region/budget/подтверждение
   расходов), `sync-audio-to-gcs.sh` (gsutil rsync, только добавление),
   `install-wsl-kubernetes.sh` (kubeconfig `~/.kube/gcp-template-k3s.yaml`).
   Пройден `bash -n` всех скриптов.
4. **Ansible**: плейбуки `gce.yml`, `gke-deploy.yml`, `gke-gcs-deploy.yml`; роли
   `nginx`, `gke`, `gke_gcs` (валидация env-переменных, заливка аудио в GCS,
   деплой манифестов, smoke-тесты).
5. **Kubernetes**: `kubernetes/base` (GKE) и `kubernetes/local` (k3s) — образ
   `ghcr.io/izanar/gcp-template-kubernetes`.
6. **CI**: `validate.yml`, `build-images.yml`, `deploy.yml` — под GCP/GHCR.
7. **Документация**: `README.md`, `CONTEXT.md`, `project_map.md`, `docs/*` — переписаны
   под GCP. Дорогие сценарии (`gke-*`) исключены из планов выполнения агентов, но
   код, README и сценарии сохранены (требование пользователя).
8. **Git**: история — `73055f4` (initial), `4f0c189` (convert to GCP), далее коммит
   документации. Remote `origin` = `git@github.com:Izanar/GCP_Template.git`, пуш по SSH.

## Валидация

- `make validate`: fmt/validate/линтеры/pytest — проходит.
- Lock-файлы `.terraform.lock.hcl` (google 8.3.0) совпадают с constraint `~> 8.3`,
  в git не попадают (`.gitignore`).

## Что осталось (осознанно)

- **Живой E2E на GCP** не проводился: нужны реальный проект, биллинг и явное
  разрешение на расходы (см. `docs/e2e.md`).
- Секреты для `deploy.yml` (workload identity / service account key) заполняются
  при первом реальном использовании.
