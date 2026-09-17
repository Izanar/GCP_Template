# Карта проекта AWS_Template

## Обновление 2026-09-17

Добавлены `tests/test_template.py`, `docs/completion.md` и
`docs/completion-context.md`. По умолчанию выбирается local-wsl; root.hcl
сохраняет state вне кэша и поддерживает существующий S3 backend. GitHub Deploy
управляет только облачной инфраструктурой. CI включает бесплатные unittest.
Старое дерево ниже не показывает `.github/workflows/` и новые файлы полностью.


## Project structure

```
AWS_Template/
├── .github/workflows/          # CI (validate), manual deploy, image builds
├── ansible/
│   ├── playbooks/              # ec2.yml, eks-deploy.yml, eks-s3-deploy.yml
│   └── roles/                  # deploy_site, eks, eks_s3, nginx
├── docs/                       # architecture, usage, development, completion
├── envs/                       # Terragrunt units: ec2, eks-ec2-s3, eks-fargate, local-wsl
├── kubernetes/
│   ├── base/                   # Manifests for EKS scenarios
│   └── local/                  # Manifests for local k3s
├── root.hcl                    # Shared Terragrunt config (state, provider)
├── scripts/                    # deploy/destroy, audio sync, WSL k3s installer
├── src/                        # Self-contained Terraform roots
└── tests/                      # Offline unittest regressions
```

## Описание
Шаблон инфраструктуры AWS, включающий Terraform, Terragrunt, Ansible и Kubernetes-манифесты для развёртывания EC2, EKS (EC2/S3, Fargate) и локального WSL-окружения.

---

## Структура проекта

```
AWS_Template/
├── .ansible-lint              # Конфигурация линтера Ansible
├── .gitignore                 # Исключения для Git
├── .pre-commit-config.yaml    # Конфигурация pre-commit хуков
├── .yamllint.yaml             # Конфигурация линтера YAML
├── CONTEXT.md                 # Контекст проекта
├── Makefile                   # Автоматизация задач (Make)
├── README.md                  # Описание проекта
├── root.hcl                   # Корневой конфиг Terragrunt
│
├── ansible/                   # Ansible playbooks и роли
│   ├── playbooks/
│   │   ├── ec2.yml            # Playbook для EC2
│   │   └── eks-deploy.yml     # Playbook для развёртывания EKS
│   └── roles/
│       ├── deploy_site/       # Роль развёртывания сайта
│       │   └── tasks/
│       │       └── main.yml
│       ├── eks/               # Роль EKS
│       │   └── tasks/
│       │       └── main.yml
│       └── nginx/             # Роль Nginx
│           ├── handlers/
│           │   └── main.yml
│           └── tasks/
│               └── main.yml
│
├── docs/                      # Документация
│   ├── architecture.md        # Архитектура проекта
│   ├── development.md         # Руководство по разработке
│   ├── README.md              # Описание документации
│   └── usage.md               # Инструкция по использованию
│
├── envs/                      # Конфигурации сред Terragrunt
│   ├── ec2/
│   │   └── terragrunt.hcl
│   ├── eks-ec2-s3/
│   │   └── terragrunt.hcl
│   ├── eks-fargate/
│   │   └── terragrunt.hcl
│   └── local-wsl/
│       └── terragrunt.hcl
│
├── kubernetes/                # Kubernetes-манифесты
│   ├── base/                  # Базовые манифесты
│   │   ├── deployment.yaml
│   │   ├── namespace.yaml
│   │   └── service.yaml
│   └── local/                 # Локальные манифесты
│       ├── deployment.yaml
│       ├── namespace.yaml
│       └── service.yaml
│
└── src/                       # Исходный код Terraform-модулей
    ├── ec2/                   # Модуль EC2
    │   ├── main.tf
    │   ├── outputs.tf
    │   └── variables.tf
    ├── eks-ec2-s3/           # Модуль EKS (EC2 + S3)
    │   ├── main.tf
    │   ├── outputs.tf
    │   └── variables.tf
    ├── eks-fargate/          # Модуль EKS Fargate
    │   ├── main.tf
    │   ├── outputs.tf
    │   └── variables.tf
    └── local-wsl/            # Модуль локального WSL
        ├── main.tf
        ├── outputs.tf
        └── variables.tf
```

---

## Скрипты

```
scripts/
├── deploy.sh                     # Скрипт развёртывания
├── destroy.sh                    # Скрипт удаления ресурсов
├── install-wsl-kubernetes.sh     # Установка Kubernetes в WSL
└── sync-audio-to-s3.sh           # Загрузка аудио в приватный S3 (eks-ec2-s3)
```

---

## Технологии

| Компонент       | Описание                                      |
|-----------------|-----------------------------------------------|
| Terraform       | Инфраструктура как код (IaC) для AWS         |
| Terragrunt      | Обёртка над Terraform для управления состоянием |
| Ansible         | Автоматизация конфигурации и развёртывания   |
| Kubernetes      | Оркестрация контейнеров                       |
| WSL             | Локальное окружение разработки (Windows)      |

---

## Среды (envs)

| Среда           | Описание                                      |
|-----------------|-----------------------------------------------|
| ec2             | Развёртывание EC2-инстанса                   |
| eks-ec2-s3      | EKS кластер с узлами EC2 и интеграцией S3    |
| eks-fargate     | EKS кластер с Fargate (serverless)           |
| local-wsl       | Локальное окружение через WSL                |

---

## Роли Ansible

| Роль            | Описание                                      |
|-----------------|-----------------------------------------------|
| deploy_site     | Развёртывание веб-сайта                       |
| eks             | Развёртывание приложения в EKS через kubectl  |
| eks_s3          | EKS-сценарий с аудио из приватного S3         |
| nginx           | Установка и настройка Nginx (с хендлерами)   |

---

## Зависимости

- Terraform
- Terragrunt
- Ansible
- kubectl
- AWS CLI
- WSL (для локальной разработки)

---

*Файл создан автоматически на основе структуры проекта.*