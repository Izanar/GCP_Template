# Development

## Validation

Run the full static validation suite:

```bash
make validate
```

It covers:

| Target | Tool | What it checks |
|---|---|---|
| `validate-tf` | `terraform fmt -check` + `terraform init`/`validate` per `src/*` | Terraform syntax and provider resolution |
| `validate-ansible` | `ansible-playbook --syntax-check`, `ansible-lint` | Playbook/role correctness |
| `validate-k8s` | PyYAML + `yamllint` | Manifest parsing and YAML style |
| `validate-shell` | `shellcheck` | Bash scripts under `scripts/` |

Pre-commit hooks run the same checks on every commit:

```bash
make precommit    # pre-commit run --all-files
```

Configure them once with `pre-commit install`.

## Constraints

- Terraform `>= 1.9.0`; locally tested 1.9.8. AWS provider 6.x for EC2,
  5.x for EKS module 20.x; local-wsl does not require an AWS provider.
- Terragrunt `>= 0.68.0` because the env units use `terraform.source` with
  `inputs`.
- Never reference sibling directories from a `src/` root: Terragrunt copies
  source trees into a cache, so relative siblings do not exist at run time.
  Use registry modules (`terraform-aws-modules/*`) or inline resources instead.

## Applying a new scenario

1. Create `src/<new>/` with `main.tf`/`variables.tf`/`outputs.tf`.
2. Create `envs/<new>/terragrunt.hcl` mirroring an existing unit.
3. Validate with `make validate` and run `make plan ENV=<new>`.

## AWS notes

- Cloud scenarios create billable resources (`t3.micro`/`t3.small` nodes, VPCs,
  EKS clusters, S3 buckets, CloudFront distributions). Always `destroy` after
  testing or rely on the manual `destroy` action.
- The EC2 instance uses Spot capacity and may be reclaimed by AWS at any time;
  a failed workflow can leave resources behind, so the manual destroy action
  exists.

## Feature branches

The Kubernetes scenarios were consolidated into `main`; the old per-scenario
branches were removed. Application images are built from the
[Izanar/AI_Nginx](https://github.com/Izanar/AI_Nginx) repository itself via the
manual `build-images.yml` workflow using its own Dockerfile. Both EKS scenarios
use `ghcr.io/izanar/aws-template-kubernetes`. Only `eks-ec2-s3` creates the
application audio bucket: its playbook uploads `html/audio/` from AI_Nginx to
private S3 and configures nginx to redirect `/audio/*` through CloudFront.
The common image retains the upstream content; the S3 route takes precedence.
