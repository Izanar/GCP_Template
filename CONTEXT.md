# GCP_Template — контекст проекта для ИИ-агентов

## Что это

Terraform/Terragrunt-шаблон для Google Cloud, созданный как копия-аналог `AWS_Template`.
`AWS_Template` — эталон, его не трогать.

## Сценарии (envs/*)

| Сценарий | Что разворачивает | Статус в планах |
|---|---|---|
| `gce` | Compute Engine `e2-micro` (preemptible) + nginx через Ansible | в планах |
| `gke-autopilot` | GKE Autopilot + Secret Manager | НЕ в планах (дорого) |
| `gke-gcs-cdn` | GKE Standard + приватный GCS + Cloud CDN | НЕ в планах (дорого) |
| `local-wsl` | k3s в WSL2, NodePort 30080 | дефолтный, бесплатный |

Код, README и все четыре сценария сохраняются независимо от планов. «НЕ в планах» значит:
не запускать `apply` для этих сценариев без явной команды пользователя, и не включать их
в планы выполнения агентов. Из кода и README они не удаляются.

## Правила работы (обязательно к прочтению перед любым действием)

1. Сначала факты, потом действия: `git status`, `git log`, фактическое содержимое файлов.
   Не полагаться на память о прошлых шагах и на предыдущие выводы инструментов.
2. README.md, код и сценарии не удалять — только адаптировать под GCP.
3. Дорогие облачные сценарии (`gke-*`) в планы выполнения не включать.
4. После завершения изменений — коммит и пуш в `origin`
   (`git@github.com:Izanar/GCP_Template.git`, SSH), затем проверка `git ls-remote origin`.
5. Валидация — `make validate` (fmt, validate, yamllint, ansible-lint, shellcheck, pytest).
   Тяжёлые прогоны и установки инструментов согласовывать с пользователем.
6. `.terraform.lock.hcl` и `venvs/` игнорируются `.gitignore` — не коммитить.

## Технические факты

- Terraform `>= 1.9`, провайдер `google ~> 8.3` ( constraints в `src/*/versions.tf`).
- `root.hcl`: GCS-backend только при заданном `TF_STATE_BUCKET`, иначе локальный стейт;
  `local-wsl` всегда локальный. Стейт не создаётся шаблоном.
- kubeconfig для local-wsl: `~/.kube/gcp-template-k3s.yaml`.
- Образ приложения: `ghcr.io/izanar/gcp-template-kubernetes` (собирает `build-images.yml`).
- Переменные окружения: `GOOGLE_PROJECT`, `GOOGLE_REGION` (по умолчанию `europe-west1`),
  `GOOGLE_ZONE`, `BUDGET_EMAIL`, `BILLING_ACCOUNT`, `GOOGLE_PROJECT_NUMBER`,
  `TF_VAR_public_key_path`, `TF_VAR_ssh_cidr_blocks`.
- Бюджет-алерт (`google_billing_budget`) опционален: создаётся только при заданных
  `BUDGET_EMAIL` и `BILLING_ACCOUNT`.

## Статус

- Код, скрипты, Ansible, k8s-манифесты, CI приведены к GCP (коммит `4f0c189`).
- README.md переписан под GCP.
- Документация `docs/`, `project_map.md`, этот файл — переписаны под GCP.
- Живой E2E не проводился: нужны реальные учётные данные GCP (см. `docs/e2e.md`).
