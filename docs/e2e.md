# Живой E2E: что это и как провести

## Что такое E2E

**E2E (end-to-end, «сквозной»)** — проверка всей цепочки на реальной инфраструктуре,
а не статических файлов:

1. `terragrunt apply` создаёт **реальные** ресурсы (облачные или локальные).
2. Приложение реально установлено и запущено (Ansible / kubectl), поды проходят
   readiness-пробы.
3. **Трафик проходит через весь стек снаружи**: HTTP-запрос возвращает содержимое
   приложения (Kyiv Skyline, а не заглушку nginx); для аудио-сценария — скачивается
   файл через CDN.
4. Ресурсы удаляются; очистка подтверждается через API/`kubectl` и пустой state.

Статические проверки (`make test`) и `terragrunt plan` E2E **не заменяют**: они не
создают ресурсы и не проверяют трафик.

## `ec2` — чек-лист живого прогона

Предварительно:
- AWS-аккаунт и credentials в профиле (`aws configure --profile aws-template`):
  права на `sts`, EC2 (инстансы, SG, key pairs).
- Подтверждение затрат: Spot t3.micro ≈ $0.0056/ч + публичный IPv4 ≈ $0.005/ч.
  Budget — уведомление, а не лимит. Типовая длительность теста — минуты.
- Инструменты: `make install-tools` (Terraform, Terragrunt, Ansible), AWS CLI,
  SSH-пара `~/.ssh/id_ed25519(.pub)`, `git`, `curl`.

Шаги: `terragrunt plan` → явное подтверждение → `apply` сохранённого плана →
Ansible (nginx + AI_Nginx) → `curl http://<ip>/` возвращает страницу →
`destroy` → проверка через AWS API, что инстанс/volume/SG/keypair/Spot-request
отсутствуют и state пуст.

## `local-wsl` — бесплатный живой E2E (чек-лист)

Однократная подготовка:
- Включить systemd в WSL2: в `/etc/wsl.conf` добавить
  `[boot]` и `systemd=true`, затем из Windows PowerShell выполнить `wsl --shutdown`
  (остановит все WSL-процессы) и снова открыть WSL.
- Sudo-пароль пользователя; системные пакеты `make`, `curl`, `git`,
  `python3-venv` (`sudo apt install make curl git python3-venv`).
- `make install-tools` — Terraform, Terragrunt, Ansible (AWS CLI и k3s не нужны).

Прогон из корня репозитория:

```bash
export PATH="$HOME/.local/bin:$HOME/venvs/tools/bin:$PATH"
make test
./scripts/deploy.sh local-wsl        # ставит k3s + kubectl, деплоит приложение
export KUBECONFIG="$HOME/.kube/aws-template-k3s.yaml"
kubectl get nodes                    # узел в состоянии Ready
kubectl get pods -n ai-nginx-demo    # под ai-nginx-app Ready (readiness-проба)
curl --fail http://localhost:30080   # ожидаем Kyiv Skyline
./scripts/destroy.sh local-wsl
```

Критерий успеха: узел Ready, под Ready, curl отдаёт страницу; после destroy
манифесты удалены, Terraform-маркеры сняты. k3s остаётся установленным —
полная очистка кластера (`sudo k3s-uninstall.sh`) только на выделенном хосте.

## EKS

Сценарии описаны в [usage.md](usage.md). Создание control plane, NAT и других
облачных ресурсов требует явного согласия на затраты. Для аудио-сценария
дополнительно проверяют загрузку из AI_Nginx в S3 и доставку через CloudFront.
