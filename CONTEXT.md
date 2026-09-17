# AWS_Template Project Context

## Актуальный статус — 2026-09-17

**Этот раздел заменяет исторические утверждения о версиях и готовности ниже.**
Проверенный отчёт: [docs/completion-context.md](docs/completion-context.md).
Terraform 1.9.8 / Terragrunt 0.68.2; EC2 provider 6.x, EKS provider 5.x;
локальный сценарий без AWS provider. Статические проверки и 5 регрессионных тестов
проходят. Полный E2E не завершён: WSL без systemd; AWS не запускался ради нулевых
новых расходов. GitHub Deploy теперь только инфраструктурный, требует существующий
S3 backend и DynamoDB lock table. Состояние вне кэша. Оставшиеся ограничения и
очистка: [docs/completion.md](docs/completion.md).

## Исторический контекст (не отчёт о текущих проверках)


## Summary

The repository was transformed into a reusable Terraform/Ansible/Kubernetes
template with Terragrunt. The previous intermediate layout (`modules/`,
`terraform/`, `terragrunt/`) was replaced by four self-contained environment
roots under `src/`, wired to the Terragrunt units under `envs/`.

## What Has Been Done

### Self-contained Terraform roots (`src/`)
- `src/ec2` (main.tf, variables.tf, outputs.tf) - EC2 + budget
- `src/eks-fargate` (main.tf, variables.tf, outputs.tf) - VPC + EKS + budget
- `src/eks-ec2-s3` (main.tf, variables.tf, outputs.tf) - VPC + EKS + S3 + CloudFront + budget
- `src/local-wsl` (main.tf, variables.tf, outputs.tf) - k3s via local-exec

Each root is cache-safe: no relative sibling paths, only registry modules from
`terraform-aws-modules`.

### Terragrunt Configuration
- Root `root.hcl` with provider generation (aws ~> 6.0, Terraform >= 1.9)
  and common locals
- Environment configurations with `terraform.source` pointing to `src/*`:
  - `envs/ec2/terragrunt.hcl`
  - `envs/eks-fargate/terragrunt.hcl`
  - `envs/eks-ec2-s3/terragrunt.hcl`
  - `envs/local-wsl/terragrunt.hcl`

### Ansible Roles and Playbooks
- Roles: `nginx`, `deploy_site`, `eks`
- Playbooks: `ansible/playbooks/ec2.yml`, `ansible/playbooks/eks-deploy.yml`

### Kubernetes Manifests
- Base manifests in `kubernetes/base/`: `namespace.yaml`, `deployment.yaml`, `service.yaml`
- Local manifests in `kubernetes/local/`: `namespace.yaml`, `deployment.yaml`, `service.yaml`

### GitHub Actions
- `validate.yml` - CI on push/PR (terraform fmt/validate, ansible, yamllint, shellcheck)
- `deploy.yml` - manual apply/destroy per scenario with AWS OIDC
- `build-images.yml` - manual image builds from the AI_Nginx repository

### Scripts
- `scripts/deploy.sh`, `scripts/destroy.sh` - scenario-aware lifecycle control
- `scripts/install-wsl-kubernetes.sh` - WSL k3s installer

### Tooling
- Makefile with validate/fmt/init/plan/apply/destroy/output/lint/test targets
- pre-commit configuration (terraform, ansible-lint, yamllint, shellcheck)
- Documentation in `docs/`

## Validation status

- Terraform: `terraform init` + `validate` pass for all `src/*` roots (TF 1.9.8,
  AWS provider 6.x for EC2, 5.x for EKS; no AWS provider for local-wsl)
- Terragrunt: `render` + `init` pass for all four envs; `plan` pass for
  `local-wsl` (no cloud credentials needed)
- Ansible: playbook syntax checks pass
- Kubernetes: manifests parse cleanly under yamllint

## What Remains to Be Done

- [x] Run `terragrunt apply` against a real AWS account for `ec2` (2026-09-17:
      Spot t3.micro, Ansible deploy, HTTP smoke test, destroy; cleanup verified
      through AWS API - instance/volume/SG/keypair/Spot request all gone, state empty)
- [x] Deploy the demo workload on the `ec2` scenario and observe the smoke test
      (live). Local k3s application E2E is also complete; see docs/completion-context.md.
- [x] If the previous `modules/` layout is still referenced anywhere (docs,
      branches), update or remove those references (verified: only historical references in architecture doc)
- [x] Fix Fargate profile selector in `src/eks-fargate/main.tf` (`weather-demo` -> `ai-nginx-demo`)
- [x] Automated offline regression tests: 13 unittest checks (template, S3
      delivery with a recorded fake AWS CLI, rendered manifests, k3s registration)
- [x] Live application E2E for `local-wsl`: deploy, browser/HTTP checks, destroy;
      state empty and app resources removed. Owner also uninstalled k3s and
      removed checkout/kubeconfig; absence independently verified.

## Explicitly NOT planned (do not schedule for agents)

- Live `terragrunt apply`/`destroy` for `eks-fargate` and `eks-ec2-s3`.
  The code, README entries and scenarios stay as reference implementations,
  but running them is deliberately out of scope (costly control plane/NAT).
  Do not re-add them to plans, checklists or "next steps" lists.
- Terratest / InSpec / k8s conformance suites (offline tests cover the gates).

## Next Steps for Continuation

1. Local E2E and full test-cluster cleanup are complete; no local cleanup pending.
2. Check the Billing entry for the completed EC2 test once data settles.
3. Optional later: real GitHub OIDC + S3 state backend for the Deploy workflow;
   a first CI run without `[skip ci]` to turn the badge green.
