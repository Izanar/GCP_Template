# Architecture

AWS_Template is split into four layers:

```
└── root.hcl                  Root config: shared locals + generated provider.tf
    ├── envs/                 One Terragrunt unit per environment
    │   ├── ec2/
    │   ├── eks-fargate/
    │   ├── eks-ec2-s3/
    │   └── local-wsl/
    ├── src/                  Self-contained Terraform roots (sources)
    │   ├── ec2/          EC2 + budget
    │   ├── eks-fargate/  VPC + EKS + budget
│   ├── eks-ec2-s3/   VPC + EKS + S3 + CloudFront + budget (audio from S3)
    │   └── local-wsl/    k3s install
    ├── ansible/              Playbooks and roles
    ├── kubernetes/base/      Manifests for the demo workload
    ├── scripts/              Helper scripts
    ├── docs/                 This documentation
    └── .github/workflows/    CI/CD
```

## Data flow

1. Terragrunt reads `envs/<scenario>/terragrunt.hcl`.
2. The root `terragrunt.hcl` generates `provider.tf` (aws region and provider
   versions) into the unit working directory and provides shared defaults such
   as the budget email or the AWS region.
3. The unit points `terraform.source` at the matching self-contained root under
   `src/` and passes its `inputs` as Terraform variables.
4. `terraform` (through Terragrunt) creates the infrastructure.
5. For `ec2`, `scripts/deploy.sh` runs the `nginx` Ansible role against the
   new instance and smoke-tests the site.
6. For Kubernetes scenarios, the `eks` Ansible role applies the manifests from
   `kubernetes/base/`.

## Why self-contained roots?

Terragrunt copies the source directory into its cache and runs Terraform from
there. Relative paths like `../shared-module` therefore break. Keeping every
environment root self-contained (only registry modules plus inlined resources)
makes deployments predictable and cache-safe. The previous `modules/` layout
was removed for this reason; see CONTEXT.md for the history.
