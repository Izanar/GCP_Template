# GCP_Template - common task runner
#
# Usage:
#   make validate        Validate Terraform sources, Ansible, Kubernetes and Shell
#   make fmt             Format Terraform code
#   make init [ENV=..]   Run `terragrunt init` for one environment
#   make plan  [ENV=..]  Run `terragrunt plan`
#   make apply [ENV=..]  Run `terragrunt apply` (creates billable resources!)
#   make destroy [ENV=..] Run `terragrunt destroy`
#   make output [ENV=..] Show terraform outputs
#
# ENV selects the Terragrunt environment directory under envs/ (default: local-wsl).
# Supported values: gce gke-autopilot gke-gcs-cdn local-wsl
#
# Requires Linux x86_64, make, curl, git, Python 3.11+ with venv, and CA certificates.
# install-tools installs Terraform/Terragrunt and Python tooling, NOT Google Cloud CLI or k3s.
# local-wsl deploy installs k3s/kubectl and requires systemd plus sudo.

SHELL := /usr/bin/env bash
.SHELLFLAGS := -eu -o pipefail -c
export PATH := $(HOME)/.local/bin:$(HOME)/venvs/tools/bin:$(PATH)
ENV   ?= local-wsl
ENV_DIR := envs/$(ENV)
SRC_DIRS := $(wildcard src/*)
TERRAFORM ?= terraform
TERRAGRUNT ?= terragrunt
PYVENV := $(HOME)/venvs/tools/bin

.PHONY: help validate validate-tf validate-ansible validate-k8s validate-shell \
        fmt init plan apply destroy output install-tools lint precommit test

help:
	@grep -E '^[a-zA-Z_-]+:' $(MAKEFILE_LIST) | sed 's/:.*//' | sort -u | sed 's/^/  make /'

install-tools:
	@test "$$(uname -s)/$$(uname -m)" = Linux/x86_64 || { echo 'install-tools supports Linux x86_64'; exit 1; }
	@echo "Installing Terraform, Terragrunt and Python tooling into ~/.local/bin and ~/venvs/tools"
	mkdir -p $(HOME)/.local/bin
	@command -v $(TERRAFORM) >/dev/null || { \
	  TF_VER=1.9.8; \
	  curl -fsSL -o /tmp/terraform.zip "https://releases.hashicorp.com/terraform/$${TF_VER}/terraform_$${TF_VER}_linux_amd64.zip"; \
	  python3 -c "import zipfile; zipfile.ZipFile(r'/tmp/terraform.zip').extractall(r'$(HOME)/.local/bin')"; \
	  chmod +x $(HOME)/.local/bin/terraform; }
	@command -v $(TERRAGRUNT) >/dev/null || { \
	  TG_VER=v0.68.2; \
	  curl -fsSL -o $(HOME)/.local/bin/terragrunt "https://github.com/gruntwork-io/terragrunt/releases/download/$${TG_VER}/terragrunt_linux_amd64"; \
	  chmod +x $(HOME)/.local/bin/terragrunt; }
	@if [ ! -d "$(PYVENV)/.." ]; then \
	  python3 -m venv $(PYVENV)/.. 2>/dev/null || python3 -m venv --without-pip $(PYVENV)/..; \
	fi
	@$(PYVENV)/python -m pip --version >/dev/null 2>&1 || { \
	  echo "Pip not found in venv, bootstrapping ensurepip..."; \
	  $(PYVENV)/python -m ensurepip --default-pip; \
	  $(PYVENV)/python -m pip install -q --upgrade pip; }
	$(PYVENV)/python -m pip install -q ansible-core ansible-lint yamllint pre-commit shellcheck-py

init:
	cd $(ENV_DIR) && $(TERRAGRUNT) init

plan:
	cd $(ENV_DIR) && $(TERRAGRUNT) plan -input=false

apply:
	@if [ "$(ENV)" != local-wsl ] && [ "$(CONFIRM_COSTS)" != yes ]; then echo 'Use CONFIRM_COSTS=yes to accept GCP charges'; exit 1; fi
	cd $(ENV_DIR) && $(TERRAGRUNT) apply

destroy:
	cd $(ENV_DIR) && $(TERRAGRUNT) destroy

output:
	cd $(ENV_DIR) && $(TERRAGRUNT) output

fmt:
	$(TERRAFORM) fmt -recursive src

validate-tf:
	@for d in $(SRC_DIRS); do \
	  echo "==> $$d"; \
	  (cd $$d && $(TERRAFORM) init -backend=false -input=false -no-color >/dev/null && $(TERRAFORM) validate -no-color) || exit 1; \
	done
	$(TERRAFORM) fmt -check -recursive src

validate-ansible:
	@command -v $(PYVENV)/ansible-playbook >/dev/null || $(PYVENV)/pip install -q ansible-core
	ANSIBLE_ROLES_PATH=ansible/roles $(PYVENV)/ansible-playbook --syntax-check -i localhost, ansible/playbooks/gce.yml
	ANSIBLE_ROLES_PATH=ansible/roles $(PYVENV)/ansible-playbook --syntax-check ansible/playbooks/gke-deploy.yml
	ANSIBLE_ROLES_PATH=ansible/roles $(PYVENV)/ansible-playbook --syntax-check ansible/playbooks/gke-gcs-deploy.yml
	ANSIBLE_ROLES_PATH=ansible/roles $(PYVENV)/ansible-lint ansible/

validate-k8s:
	@$(PYVENV)/python -c "import yaml,sys; [yaml.safe_load(open(f)) for f in sys.argv[1:]]" kubernetes/base/*.yaml
	$(PYVENV)/yamllint kubernetes/ .github/workflows/

validate-shell:
	@command -v $(PYVENV)/shellcheck >/dev/null || $(PYVENV)/pip install -q shellcheck-py
	$(PYVENV)/shellcheck scripts/*.sh

validate: validate-tf validate-ansible validate-k8s validate-shell

precommit:
	$(PYVENV)/pre-commit run --all-files

lint: precommit validate

test: validate
	$(PYVENV)/python -m unittest discover -s tests -v

docs:
	@echo "Run: python3 -m http.server -d docs 8080"
