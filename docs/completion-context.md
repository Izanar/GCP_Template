# Контекст завершения для следующих агентов

## Состояние

Репозиторий `GCP_Template` полностью переведён с AWS-бейзлайна на GCP.
Remote: `git@github.com:Izanar/GCP_Template.git` (SSH). Ветка `main`.

## Что уже сделано (не повторять)

- Модули `src/{gce,gke-autopilot,gke-gcs-cdn,local-wsl}`, провайдер `google ~> 8.3`.
- `root.hcl`: GCS-backend по `TF_STATE_BUCKET`, иначе локальный стейт.
- Скрипты `scripts/{deploy,destroy}.sh`, `sync-audio-to-gcs.sh`, `install-wsl-kubernetes.sh`.
- Ansible: `playbooks/{gce,gke-deploy,gke-gcs-deploy}.yml`, роли `nginx`, `gke`, `gke_gcs`.
- k8s: `kubernetes/base`, `kubernetes/local`; CI: `validate.yml`, `build-images.yml`, `deploy.yml`.
- Документация `README.md`, `CONTEXT.md`, `project_map.md`, `docs/*` — под GCP.

## Правила (из CONTEXT.md, обязательны)

1. Сначала фактическое состояние (`git status`, файлы), потом действия.
2. `AWS_Template` не трогать.
3. Дорогие сценарии (`gke-*`) не включать в планы и не запускать без явной команды.
4. Код, README, сценарии не удалять.
5. После изменений — коммит и пуш, проверка `git ls-remote origin`.
6. `.terraform.lock.hcl`, `venvs/` — не коммитить.

## Как проверить, что всё в порядке

```bash
make validate                       # линтеры + terraform validate + pytest
bash -n scripts/*.sh
cd envs/local-wsl && terragrunt init -input=false && terragrunt plan -input=false
```

## Оставшиеся шаги (по желанию пользователя)

- **Живой E2E** — см. `docs/e2e.md`: нужен gcloud-логин, проект с биллингом,
  включённые API, SSH-ключ и подтверждение расходов. Дешёвый вариант — `gce`.
- Заполнение секретов `deploy.yml` при первом реальном деплое из CI.
