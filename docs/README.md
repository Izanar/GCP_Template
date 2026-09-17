# Документация GCP_Template

Набор документов по проекту. Проект — GCP-версия шаблона, созданная на основе `AWS_Template`.

| Документ | Содержание |
|---|---|
| [usage.md](usage.md) | Как пользоваться: make-цели, deploy.sh, переменные окружения |
| [architecture.md](architecture.md) | Архитектура сценариев и модулей |
| [development.md](development.md) | Среда разработки, инструменты, конвенции |
| [e2e.md](e2e.md) | Что такое E2E и что нужно для «Живого E2E» |
| [completion.md](completion.md) | Отчёт о выполненной адаптации под GCP |
| [completion-context.md](completion-context.md) | Контекст для продолжения работы другими агентами |

## Сценарии

- `gce` — Compute Engine + nginx (дешёвый облачный).
- `gke-autopilot` — GKE Autopilot (код есть, в планах выполнения агентов НЕ значится).
- `gke-gcs-cdn` — GKE + приватный GCS + Cloud CDN (код есть, в планах НЕ значится).
- `local-wsl` — локальный k3s, бесплатно, дефолт для проверок.

Быстрый старт: `make install-tools`, `make validate`, `./scripts/deploy.sh local-wsl`.
