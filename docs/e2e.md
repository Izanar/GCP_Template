# E2E: что это и что нужно для «Живого E2E»

## Что значит E2E

**E2E (end-to-end)** — сквозной тест: проверяется весь путь от чистого состояния до
работающего приложения, как это сделал бы пользователь, а не отдельные модули.
В этом проекте E2E-цепочка выглядит так:

```
инструменты → terragrunt init/plan/apply → приложение (nginx/AI_Nginx) → smoke-тест curl → destroy
```

«Сухой E2E» — то же, но без создания облакных ресурсов: `make validate`, `terraform validate`,
pytest, деплой `local-wsl`. Это уже выполнено в рамках адаптации.

## Что нужно для Живого E2E (реальное облако GCP)

1. **Учётная запись GCP**: проект с включённым биллингом.
2. **gcloud SDK** (`gcloud`, `gsutil`) и аутентификация:
   ```bash
   gcloud auth login
   gcloud auth application-default login
   gcloud config set project <PROJECT_ID>
   ```
   Альтернатива — SA-ключ JSON (без интерактива): см. «Аутентификация» в
   `docs/usage.md` (`gcloud auth activate-service-account` +
   `GOOGLE_APPLICATION_CREDENTIALS`).
3. **Включённые API**: `compute.googleapis.com`, `container.googleapis.com`,
   `secretmanager.googleapis.com`, `monitoring.googleapis.com`
   (для бюджетов — `billingbudgets.googleapis.com`; для бюджетов и чтения
   проекта Terraform'ом — `cloudresourcemanager.googleapis.com`).
4. **SSH-ключ** `~/.ssh/id_rsa(.pub)` — для сценария `gce`.
5. **GitHub SSH-доступ** — уже настроен (пуш в `git@github.com:Izanar/GCP_Template.git`).
6. **kubectl** — для GKE-сценариев и local-wsl.
7. **Подтверждение расходов**: `deploy.sh` спросит проект, регион и yes на создание
   платных ресурсов. Дешёвый вариант — `gce` (`e2-micro` preemptible, < 1 USD/день).
   GKE-сценарии дороже — они сознательно не в планах агентов.

## Чек-лист живого прогона (пример для gce)

```bash
./scripts/deploy.sh gce        # ответить: project, region, email (опц.), yes
# ожидаемо: вывод public_ip, «Smoke test OK»
curl http://<PUBLIC_IP>
./scripts/destroy.sh gce       # ответить yes
```

Для `local-wsl` облако не нужно: `./scripts/deploy.sh local-wsl` → `http://localhost:30080`.

## Статус

**Живой E2E `gce` — проведён успешно** (сентябрь 2026, проект `main-483108`,
регион `europe-west1`):
```
SA-ключ (GOOGLE_APPLICATION_CREDENTIALS) → ./scripts/deploy.sh gce →
Ansible (nginx + AI_Nginx) → curl http://<public_ip> (Kyiv Skyline, Smoke test OK)
→ ./scripts/destroy.sh gce → 7 destroyed → в проекте чисто
```
Нюансы, отработанные на живом прогоне: SA нужна роль `Compute Admin`;
при выключенном Cloud Resource Manager API бюджет-блок автоматически не
создаётся, а `deploy.sh` только предупреждает. Живой E2E для `gke-*` не
проводился (дорого, «НЕ в планах»). Все «сухие» проверки проходят
(`make validate`).
