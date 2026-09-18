# GCP_Template - common task runner
#
# Usage:
#   make install-tools [SCENARIO=..] Install tooling needed by a scenario (default: all)
#   make validate        Validate Terraform sources, Ansible, Kubernetes and Shell
#   make fmt             Format Terraform code
#   make init [ENV=..]   Run `terragrunt init` for one environment
#   make plan  [ENV=..]  Run `terragrunt plan`
#   make apply [ENV=..]  Run `terragrunt apply` (creates billable resources!)
#   make deploy [ENV=..]  Full scenario: infra (terragrunt) + application + audio smoke test
#   make teardown [ENV=..] Destroy the scenario infrastructure
#   make output [ENV=..] Show terraform outputs
#
# ENV selects the Terragrunt environment directory under envs/ (default: local-wsl).
# Supported values: gce gke-autopilot gke-gcs-cdn local-wsl
#
# SCENARIO selects what `make install-tools` installs:
#   all (default)                base tools + Google Cloud CLI (gcloud, gsutil)
#                                + kubectl + gke-gcloud-auth-plugin
#   gce                          base tools + Google Cloud CLI
#   gke-autopilot | gke-gcs-cdn  base tools + Google Cloud CLI + kubectl
#                                + gke-gcloud-auth-plugin
#   local-wsl                    base tools only (k3s/kubectl set up manually,
#                                see scripts/install-wsl-kubernetes.sh)
#
# Requires Linux x86_64, make, curl, git, Python 3.11+ with venv, and CA certificates.
# install-tools installs Terraform/Terragrunt, Google Cloud CLI and Python tooling
# into ~/.local/bin, ~/venvs/tools and ~/google-cloud-sdk. k3s (local-wsl) is
# installed by scripts/install-wsl-kubernetes.sh, not by install-tools.

SHELL := /usr/bin/env bash
.SHELLFLAGS := -eu -o pipefail -c
export PATH := $(HOME)/.local/bin:$(HOME)/venvs/tools/bin:$(PATH)
ENV   ?= local-wsl
ENV_DIR := envs/$(ENV)
SRC_DIRS := $(wildcard src/*)
TERRAFORM ?= terraform
TERRAGRUNT ?= terragrunt
PYVENV := $(HOME)/venvs/tools/bin

SCENARIO ?= all
GCLOUD_DIR := $(HOME)/google-cloud-sdk
GCLOUD_BIN := $(GCLOUD_DIR)/bin/gcloud
GCLOUD_URL := https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-linux-x86_64.tar.gz

.PHONY: help validate validate-tf validate-ansible validate-k8s validate-shell \
        fmt init plan apply destroy output install-tools install-base \
        install-gcloud install-kubectl install-gke-auth deploy teardown \
        lint precommit test

help:
	@grep -E '^[a-zA-Z_-]+:' $(MAKEFILE_LIST) | sed 's/:.*//' | sort -u | sed 's/^/  make /'

install-tools:
	@case "$(SCENARIO)" in \
	  all|gce|gke-autopilot|gke-gcs-cdn|local-wsl) ;; \
	  *) echo 'SCENARIO must be one of: all gce gke-autopilot gke-gcs-cdn local-wsl' >&2; exit 1 ;; \
	esac
	@echo ">>> Installing tooling for scenario '$(SCENARIO)' ..."
	$(MAKE) --no-print-directory install-base
ifneq ($(strip $(filter all gce gke-autopilot gke-gcs-cdn,$(SCENARIO))),)
	$(MAKE) --no-print-directory install-gcloud
endif
ifneq ($(strip $(filter all gke-autopilot gke-gcs-cdn,$(SCENARIO))),)
	$(MAKE) --no-print-directory install-kubectl
endif
ifneq ($(strip $(filter all gke-autopilot gke-gcs-cdn,$(SCENARIO))),)
	$(MAKE) --no-print-directory install-gke-auth
endif
	@echo ">>> Tooling for scenario '$(SCENARIO)' is ready."

install-base:
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

install-gcloud:
	@test "$$(uname -s)/$$(uname -m)" = Linux/x86_64 || { echo 'install-gcloud supports Linux x86_64'; exit 1; }
	@if [ -x "$(GCLOUD_BIN)" ]; then \
	  echo "Google Cloud CLI already installed at $(GCLOUD_BIN)"; \
	else \
	  echo "Installing Google Cloud CLI into $(GCLOUD_DIR) ..."; \
	  curl -fsSL -o /tmp/google-cloud-cli.tar.gz "$(GCLOUD_URL)"; \
	  tar -xzf /tmp/google-cloud-cli.tar.gz -C "$(HOME)"; \
	  rm -f /tmp/google-cloud-cli.tar.gz; \
	  "$(GCLOUD_DIR)/install.sh" --quiet --path-update false --command-completion false --usage-reporting false; \
	fi
	@$(GCLOUD_BIN) --version
	@mkdir -p $(HOME)/.local/bin
	@ln -sfn "$(GCLOUD_BIN)" "$(HOME)/.local/bin/gcloud"
	@ln -sfn "$(GCLOUD_DIR)/bin/gsutil" "$(HOME)/.local/bin/gsutil"
	@echo "gcloud and gsutil are available on PATH via ~/.local/bin"

install-kubectl:
	@test "$$(uname -s)/$$(uname -m)" = Linux/x86_64 || { echo 'install-kubectl supports Linux x86_64'; exit 1; }
	@if command -v kubectl >/dev/null; then \
	  echo "kubectl already installed: $$(command -v kubectl)"; \
	else \
	  mkdir -p $(HOME)/.local/bin; \
	  KVER=$$(curl -fsSL https://dl.k8s.io/release/stable.txt); \
	  echo "Installing kubectl $${KVER} into ~/.local/bin ..."; \
	  curl -fsSL -o "$(HOME)/.local/bin/kubectl" "https://dl.k8s.io/release/$${KVER}/bin/linux/amd64/kubectl"; \
	  chmod +x "$(HOME)/.local/bin/kubectl"; \
	  "$(HOME)/.local/bin/kubectl" version --client --output=yaml 2>/dev/null | head -3; \
	fi

install-gke-auth: install-gcloud
	@if [ -x "$(GCLOUD_DIR)/bin/gke-gcloud-auth-plugin" ]; then \
	  echo "gke-gcloud-auth-plugin already installed"; \
	else \
	  $(GCLOUD_BIN) components install gke-gcloud-auth-plugin --quiet; \
	fi
	@ln -sfn "$(GCLOUD_DIR)/bin/gke-gcloud-auth-plugin" "$(HOME)/.local/bin/gke-gcloud-auth-plugin"
	@$(GCLOUD_BIN) components list --filter='state.name=Installed' --format='value(id)' 2>/dev/null | grep -x 'gke-gcloud-auth-plugin' && echo 'gke-gcloud-auth-plugin ready' || true

init:
	cd $(ENV_DIR) && $(TERRAGRUNT) init

plan:
	cd $(ENV_DIR) && $(TERRAGRUNT) plan -input=false

apply:
	@if [ "$(ENV)" != local-wsl ] && [ "$(CONFIRM_COSTS)" != yes ]; then echo 'Use CONFIRM_COSTS=yes to accept GCP charges'; exit 1; fi
	cd $(ENV_DIR) && $(TERRAGRUNT) apply

destroy:
	cd $(ENV_DIR) && $(TERRAGRUNT) destroy

# Full scenario = infrastructure + application + smoke test (see scripts/deploy.sh).
# CONFIRM_COSTS=yes is required for cloud scenarios.
deploy:
	@if [ "$(ENV)" != local-wsl ] && [ "$(CONFIRM_COSTS)" != yes ]; then echo 'Use CONFIRM_COSTS=yes to accept GCP charges'; exit 1; fi
	./scripts/deploy.sh $(ENV)

teardown:
	./scripts/destroy.sh $(ENV)

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
