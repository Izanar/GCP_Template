# Usage

> Current cost-safe runbook and limitations: [completion.md](completion.md).
> Default scenario is now local-wsl; kubeconfig is `~/.kube/aws-template-k3s.yaml`.
> GitHub Deploy provisions infrastructure only and requires an existing S3 backend.
> EKS additionally requires Ansible and a published accessible application image.
> AWS Budget is an alert, not a spending cap. The `eks-ec2-s3` playbook uploads
> audio from the AI_Nginx repository to the scenario's private S3 bucket.


## Quick start

```bash
# 1. Install Terraform, Terragrunt and Python tooling (into ~/.local/bin)
make install-tools

# 2. Validate everything compiles (static checks only, no resources created)
make validate

# 3. Pick a scenario and deploy it
#    - Cloud scenarios (ec2, eks-fargate, eks-ec2-s3) require AWS credentials
#    - Local scenario (local-wsl) runs entirely on your machine
./scripts/deploy.sh <scenario>

# 4. When you are done, destroy the resources
./scripts/destroy.sh <scenario>
```

### Choosing a scenario

| Scenario | Command | Cloud resources? | What you need |
|---|---|---|---|
| `ec2` | `./scripts/deploy.sh ec2` | Yes (EC2 Spot) | AWS creds, `aws` CLI, SSH key pair |
| `eks-fargate` | `./scripts/deploy.sh eks-fargate` | Yes (EKS) | AWS creds, `aws` CLI, `kubectl` |
| `eks-ec2-s3` | `./scripts/deploy.sh eks-ec2-s3` | Yes (EKS + S3 + CloudFront) | AWS creds, `aws` CLI, `kubectl` |
| `local-wsl` | `./scripts/deploy.sh local-wsl` | **No** | WSL2, `kubectl` |

## Scenario run guides

Every scenario deploys the same [AI_Nginx](https://github.com/Izanar/AI_Nginx)
application: nginx is installed and started, the AI_Nginx content is served,
and a smoke test verifies the page responds. Each scenario is a Terragrunt
environment under `envs/`. Deploy creates real, billable resources (except
`local-wsl`, which is local only).

### 1. `ec2` — AWS EC2 + nginx (Ansible)

**Requirements:** AWS credentials, `aws` CLI, `ansible-playbook`, an SSH key
pair (`~/.ssh/id_rsa.pub` by default).

```bash
# Make sure your keys are present before you start
ls -l ~/.ssh/id_rsa ~/.ssh/id_rsa.pub
aws sts get-caller-identity          # verify AWS credentials

./scripts/deploy.sh ec2          # creates EC2, prints the nginx URL
#    -> asks region, budget email, SSH key path and your public IP (optional)
#    -> the runner's IP is added to the SSH security group automatically

# Re-run the nginx provisioning at any time against the same instance
ansible-playbook -i /tmp/aws-template-inventory.ini ansible/nginx.yml

# Inspect the deployed demo
curl "$(cd envs/ec2 && terragrunt output -raw nginx_url)"

./scripts/destroy.sh ec2         # destroys the instance and all wiring
```

**Outputs:** `public_ip`, `nginx_url`, `instance_id`.

### 2. `eks-fargate` — AWS EKS on Fargate

**Requirements:** AWS credentials, `aws` CLI, `kubectl`.

```bash
aws sts get-caller-identity

./scripts/deploy.sh eks-fargate  # creates the EKS control plane + profiles
#    -> takes 15-25 minutes; the kubeconfig snippet is printed at the end

# Connect kubectl to the new cluster (replace the printed values)
aws eks update-kubeconfig --name "$(terragrunt --working-dir envs/eks-fargate output -raw cluster_name)" --region eu-central-1
kubectl get nodes
kubectl apply -f kubernetes/base/          # deploy the demo workload

./scripts/destroy.sh eks-fargate # destroys the cluster (also 15-25 min)
```

**Outputs:** `cluster_name`, `cluster_endpoint`.

### 3. `eks-ec2-s3` — AWS EKS + S3 + CloudFront (OAC)

**Requirements:** AWS credentials, `aws` CLI, `kubectl`.

```bash
aws sts get-caller-identity

./scripts/deploy.sh eks-ec2-s3   # EKS + S3 + CloudFront with OAC
#    -> same 15-25 minutes; audio is uploaded to the private bucket automatically
#    -> the app image serves static files; /audio/* redirects to CloudFront
#    -> the playbook verifies an audio file through nginx -> CloudFront

./scripts/destroy.sh eks-ec2-s3  # destroys the cluster, bucket and CDN
```

**Outputs:** `cluster_name`, `cluster_endpoint`, `audio_bucket_name`, `cloudfront_domain`.

### 4. `local-wsl` — k3s on WSL2 (no cloud)

**Requirements:** WSL2 with `kubectl`. The install script sets up k3s for you.

> **Важно:** Это единственный сценарий, который не требует облачных ресурсов и не создаёт расходов. Его можно полностью протестировать локально.

#### Пошаговый алгоритм запуска (локальный сценарий)

Выполняйте команды по порядку. Каждая команда — это отдельный шаг, который можно проверить перед переходом к следующему.

**Шаг 0: Подготовка (один раз)**

Убедитесь, что у вас установлены требуемые инструменты:

```bash
# Проверка версий
terragrunt --version          # >= 0.68.0
terraform --version           # >= 1.9.0
kubectl version --client      # any recent version
```

Если инструменты не установлены, установите их:

```bash
make install-tools
```

**Шаг 1: Установка k3s в WSL2 (один раз)**

```bash
./scripts/install-wsl-kubernetes.sh
```

Эта команда:
- Скачивает и устанавливает k3s (Kubernetes lightweight) в ваше WSL2 окружение
- Если k3s уже установлен, покажет текущую версию и предложит варианты

После установки проверьте, что k3s работает:

```bash
k3s kubectl get nodes
```

Ожидаемый вывод: один узел в статусе `Ready`.

> **Примечание:** На WSL2 сервер k3s должен работать внутри сессии systemd. Если узел не появляется, запустите `systemctl start k3s`.

**Шаг 2: Настройка сетевого доступа (один раз)**

Сетевой доступ настраивается вручную при необходимости; Terraform не изменяет сеть Windows.
После запуска приложения сначала проверьте `http://localhost:30080` с Windows.
Если localhost forwarding недоступен, используйте инструкции ниже.

Суть настройки:
1. Найти IP-адрес WSL2: `ip -4 addr show eth0 | grep inet`
2. На Windows (PowerShell) добавить проброс порта:
   ```powershell
   netsh interface portproxy add v4tov4 listenport=30080 listenaddress=0.0.0.0 connectport=30080 connectaddress=<WSL2_IP>
   ```
3. Разрешить трафик в брандмауэре Windows:
   ```powershell
   netsh advfirewall firewall add rule name='k3s-30080' dir=in action=allow protocol=TCP localport=30080
   ```
4. Проверить доступность с Windows:
   ```powershell
   curl http://localhost:30080
   ```

**Шаг 3: Запуск демо-приложения**

```bash
./scripts/deploy.sh local-wsl
```

Эта команда:
- Клонирует репозиторий AI_Nginx (если ещё не склонирован) в `/opt/ai-nginx`
- Применяет Kubernetes манифесты из `kubernetes/local/`
- Дожидается, пока под приложения станет готовым (до 180 секунд)
- Выводит URL для доступа и запускает smoke-тест

**Шаг 4: Проверка результатов**

После успешного деплоя проверьте, что всё работает:

```bash
# Посмотреть узлы кластера
kubectl get nodes

# Посмотреть все поды во всех namespace
kubectl get pods -A

# Проверить конкретный под приложения
kubectl get pods -n ai-nginx-demo

# Посмотреть логи приложения
kubectl logs -n ai-nginx-demo -l app=ai-nginx-app

# Проверить сервис
kubectl get svc -n ai-nginx-demo
```

Ожидаемый результат:
- 1 узел (k3s) в статусе `Ready`
- Под `ai-nginx-app` в namespace `ai-nginx-demo` в статусе `Running`
- Сервис типа `NodePort` на порту `30080`

**Шаг 5: Доступ к приложению**

Приложение доступно по адресу:

```
http://localhost:30080
```

Если вы на Windows, убедитесь, что выполнили шаги из **Шага 2** для проброса порта.

Проверка из WSL2:

```bash
curl http://localhost:30080
```

Проверка с Windows (PowerShell):

```powershell
curl http://localhost:30080
```

**Шаг 6: Остановка и удаление**

Когда закончите тестирование, удалите ресурсы:

```bash
./scripts/destroy.sh local-wsl
```

Эта команда:
- Удаляет Kubernetes ресурсы (сервис, деплоймент, namespace)
- Оставляет клонированный репозиторий в `/opt/ai-nginx` (удалите вручную при необходимости: `sudo rm -rf /opt/ai-nginx`)

---

#### Полный цикл команд (для справки)

```bash
# === ПОДГОТОВКА (один раз) ===
make install-tools                          # установка инструментов
./scripts/install-wsl-kubernetes.sh         # установка k3s

# === ЗАПУСК ===
./scripts/deploy.sh local-wsl              # деплой приложения

# === ПРОВЕРКА ===
kubectl get nodes                           # проверить узлы
kubectl get pods -A                         # проверить поды
curl http://localhost:30080                 # проверить приложение

# === ОЧИСТКА ===
./scripts/destroy.sh local-wsl             # удалить ресурсы
sudo rm -rf /opt/ai-nginx                  # удалить клонированный репозиторий (опционально)
```

---

#### Отладка (troubleshooting)

**k3s не запускается:**
```bash
systemctl status k3s
journalctl -u k3s -n 50
```

**Под приложения не становится Ready:**
```bash
kubectl describe pod -n ai-nginx-demo -l app=ai-nginx-app
kubectl logs -n ai-nginx-demo -l app=ai-nginx-app --previous
```

**Порт не доступен с Windows:**
- Проверьте, что WSL2 IP корректен: `ip -4 addr show eth0 | grep inet`
- Проверьте проброс порта: `netsh interface portproxy show all`
- Проверьте правило брандмауэра: `netsh advfirewall firewall show rule name='k3s-30080'`

Nothing billable here; it runs entirely on your machine.

## Environment variables

Set them in the shell or let `deploy.sh` prompt you:

```bash
export AWS_DEFAULT_REGION=eu-central-1
export BUDGET_EMAIL=you@example.com   # optional
```

`BUDGET_EMAIL` enables an AWS Budget (COST, monthly) alert at 80% of
`monthly_budget_usd` (default 5 USD). AWS Billing permissions are required.

## Individual Terragrunt commands

```bash
make init   ENV=ec2        # terragrunt init
make plan   ENV=ec2        # terragrunt plan
make apply  ENV=ec2        # terragrunt apply (creates resources)
make output ENV=ec2        # print terraform outputs
make destroy ENV=ec2       # terragrunt destroy
```

Supported `ENV` values: `ec2`, `eks-fargate`, `eks-ec2-s3`,
`local-wsl`.

`make validate` checks Terraform, Ansible, Kubernetes YAML and Shell scripts.

> The `ec2` scenario needs an SSH key pair. `public_key_path` defaults to
> `~/.ssh/id_rsa.pub`; the corresponding private key is used by Ansible.

## GitHub Actions

The repository ships two workflows:

- `validate.yml` - runs on every push/PR: `terraform fmt` + `validate`,
  Ansible syntax check, yamllint, shellcheck.
- `deploy.yml` (manual) - choose a scenario and `apply` or `destroy`. Cloud
  scenarios assume an OIDC role announced by the `AWS_ROLE_ARN` secret.

### Required secrets (cloud scenarios)

- `AWS_ROLE_ARN` - role that trusts GitHub OIDC for this repository.
- `AWS_SSH_PRIVATE_KEY` / `AWS_SSH_PUBLIC_KEY` - SSH keys used by the `ec2`
  Ansible provisioning.
