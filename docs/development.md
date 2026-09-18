# Разработка в GCP_Template

## Предварительные требования (WSL2 Ubuntu)

```bash
sudo apt install make curl git python3-venv
```

Инструменты Terraform/Terragrunt/линтеры ставятся через `make install-tools`
(terraform, terragrunt, ansible, ansible-lint, shellcheck, yamllint, pre-commit).

## Основные команды

```bash
make install-tools              # установить инструменты (SCENARIO=all|gce|gke-*|local-wsl)
make validate                   # fmt + validate + линтеры
make fmt                        # форматирование terraform/hcl/yaml
make deploy ENV=local-wsl       # полный сценарий: инфра + AI_Nginx + smoke-тест
make init ENV=local-wsl         # только terragrunt init
make plan ENV=local-wsl         # только terragrunt plan
make apply ENV=local-wsl        # только инфраструктура (приложение ставит deploy)
make destroy ENV=local-wsl      # снять инфраструктуру
pre-commit run -a               # хуки вручную
```

## Структура и конвенции

- Один сценарий = одна пара `envs/<name>/terragrunt.hcl` + `src/<name>/`.
- Провайдер и версии — в `src/<name>/versions.tf` (`google ~> 8.3`).
- Общий конфиг — `root.hcl`; inputs окружений дублируют дефолты осознанно.
- Стейт: локальный по умолчанию; GCS — через `TF_STATE_BUCKET` (бакет создаётся вне шаблона).
- Скрипты — bash с `set -euo pipefail`, проверяются shellcheck.
- Python-тесты в `tests/` проверяют структуру и конфигурацию, не требуют облака.

## Добавление нового сценария

1. `src/<name>/`: `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`.
2. `envs/<name>/terragrunt.hcl` с `include "root"` и `inputs`.
3. Если нужен Ansible — плейбук в `ansible/playbooks/`, роль в `ansible/roles/`.
4. Обновить `project_map.md`, `README.md`, `docs/`.
5. `make validate`, затем коммит и пуш.

## Правила

- `AWS_Template` не трогать.
- Дорогие сценарии (`gke-*`) не запускать без явной команды пользователя.
- Lock-файлы и `venvs/` не коммитятся (см. `.gitignore`).
