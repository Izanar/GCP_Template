# Контроль затрат, state и очистка

## Бесплатный путь

В WSL2 PID 1 должен быть `systemd`. Для включения добавьте в `/etc/wsl.conf`
секцию `[boot]` с `systemd=true` и выполните `wsl --shutdown` из Windows
PowerShell. Команда остановит все WSL-процессы; затем откройте WSL снова.
Для установки k3s нужен sudo. Установите make, curl, git, Python/venv заранее;
`make install-tools` не устанавливает AWS CLI, kubectl или системный make.

Из корня репозитория:

```bash
export PATH="$HOME/.local/bin:$HOME/venvs/tools/bin:$PATH"
make test
./scripts/deploy.sh local-wsl
export KUBECONFIG="$HOME/.kube/aws-template-k3s.yaml"
kubectl get pods -n ai-nginx-demo
curl --fail http://localhost:30080
./scripts/destroy.sh local-wsl
```

Destroy удаляет приложение и Terraform-маркеры, но сохраняет k3s и checkout.
На выделенном тестовом хосте для полной очистки кластера выполните
`sudo /usr/local/bin/k3s-uninstall.sh`; он удаляет **весь** локальный k3s,
включая чужие workload, если они есть. Checkout `/opt/ai-nginx`, отдельный
kubeconfig и ручные Windows portproxy/firewall правила удаляются отдельно.
Ни один из этих локальных компонентов не создаёт AWS-начислений.

## State: не потерять возможность удаления

Локально state расположен в `envs/<scenario>/terraform.tfstate`, не в
`.terragrunt-cache`. Старый state из кэша нужно сохранить и мигрировать
`terragrunt init -migrate-state` до удаления кэша или нового apply.
Не запускайте apply с пустым state поверх существующих ресурсов!

CI требует существующие encrypted/versioned S3 bucket и DynamoDB lock table:
repository variables `TF_STATE_BUCKET`, `TF_STATE_REGION`, `TF_LOCK_TABLE`.
Секреты: `AWS_ROLE_ARN`, для EC2 `AWS_SSH_PUBLIC_KEY`; `BUDGET_EMAIL` опционален.
Backend не создаётся автоматически и сам может стоить денег.
Ключ state включает регион и сценарий. Apply/destroy должны использовать
одинаковый аккаунт, backend, регион, сценарий и параметры.
GitHub Deploy создаёт **только инфраструктуру**; полный путь приложения — скрипт.

## Если AWS всё-таки использовался ранее

1. Найдите исходный state, аккаунт и регион. Сохраните защищённую резервную копию.
2. Просмотрите ресурсы через `terragrunt state list` в соответствующем env.
3. Запустите `scripts/destroy.sh <scenario>` или ручной workflow destroy с тем же backend.
   При ошибке устраните причину и повторите; ошибка destroy не означает очистку.
4. Проверьте пустой state и AWS Console/API во всех использованных регионах:
   EC2/Spot, EBS, EIP, NAT Gateways, EKS/node groups/Fargate, load balancers,
   S3 (версии и multipart uploads), CloudFront, CloudWatch logs, Secrets Manager.
   Ресурсы вне state нужно проверять отдельно; не удаляйте чужие ресурсы.
5. Проверьте Billing/Cost Explorer после задержки обновления данных. Destroy
   прекращает последующее потребление, но не отменяет уже начисленную стоимость.
6. Лишь после этого отдельно удаляйте выделенный backend и lock table, если они
   не нужны другим проектам, включая версии объектов state. Общий backend не удаляйте.

**Budget $5 — уведомление, не ограничитель и не автоматическое выключение.**
EKS control plane, NAT, public IPv4, storage и прочее оплачиваются даже без приложения.
Для нулевых новых облачных затрат не запускайте облачный apply.

## Требования к приложению

- EKS образы должны быть опубликованы и доступны без приватных pull credentials;
  образ содержит приложение и curl. Содержимое живых подов не модифицируется.
- Для EKS проверьте поддерживаемую версию Kubernetes, DNS и readiness.
- Только `eks-ec2-s3` создаёт S3/CloudFront для аудио. Плейбук `eks-s3-deploy`
  загружает `html/audio/` из репозитория AI_Nginx скриптом
  `scripts/sync-audio-to-s3.sh`; nginx отправляет `/audio/*` на CloudFront.
- Сквозная проверка и очистка описаны в [e2e.md](e2e.md).
