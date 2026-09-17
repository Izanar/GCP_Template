#!/usr/bin/env bash
# Destroy one environment managed by Terragrunt.
# Usage: ./scripts/destroy.sh [scenario]
set -euo pipefail
export PATH="$PATH:/usr/local/bin"

cd "$(dirname "$0")/.."

SCENARIO="${1:-local-wsl}"
case "$SCENARIO" in
  gce|gke-autopilot|gke-gcs-cdn|local-wsl) ;;
  *) echo 'Unknown scenario' >&2; exit 1 ;;
esac
ENV_DIR="envs/${SCENARIO}"

if [[ ! -f "${ENV_DIR}/terragrunt.hcl" ]]; then
  echo "Unknown scenario: ${SCENARIO}" >&2
  echo "Available: gce gke-autopilot gke-gcs-cdn local-wsl" >&2
  exit 1
fi

command -v terragrunt >/dev/null || { echo "terragrunt is required" >&2; exit 1; }

if [[ "$SCENARIO" == local-wsl ]]; then
  export KUBECONFIG="$HOME/.kube/gcp-template-k3s.yaml"
else
  gcp_project="${GOOGLE_PROJECT:-}"
  [[ -n "$gcp_project" ]] || read -r -p "GCP project ID (required): " gcp_project
  [[ -n "$gcp_project" ]] || { echo 'A project ID is required' >&2; exit 1; }
  export GOOGLE_PROJECT="$gcp_project"
  gcp_region="${GOOGLE_REGION:-}"
  [[ -n "$gcp_region" ]] || read -r -p "GCP region [europe-west1]: " gcp_region
  export GOOGLE_REGION="${gcp_region:-europe-west1}"
fi

if [[ "$SCENARIO" == gke-gcs-cdn && -z "${CDN_DOMAIN:-}" ]]; then
  export CDN_DOMAIN
  CDN_DOMAIN="$(cd "$ENV_DIR" && terragrunt output -raw cdn_domain)"
fi
read -r -p "Destroy all Terraform-managed resources for '${SCENARIO}'? [yes/no]: " confirmation
[[ "$confirmation" == "yes" ]] || { echo "Cancelled."; exit 0; }

echo ">>> Destroying scenario '${SCENARIO}' ..."

if [[ "$SCENARIO" == "local-wsl" ]] && command -v kubectl >/dev/null; then
  echo ">>> Removing the AI_Nginx demo from local Kubernetes ..."
  kubectl delete -f kubernetes/local/service.yaml --ignore-not-found
  kubectl delete -f kubernetes/local/deployment.yaml --ignore-not-found
  kubectl delete -f kubernetes/local/namespace.yaml --ignore-not-found
  echo ">>> App checkout /opt/ai-nginx left in place (remove it manually if unwanted)."
fi

(cd "$ENV_DIR" && terragrunt init -input=false && terragrunt destroy -auto-approve)
echo 'Terraform destroy finished. Check billing and any resources managed outside this state.'
if [[ "$SCENARIO" == local-wsl ]]; then
  echo 'k3s remains installed. On a dedicated test host, sudo /usr/local/bin/k3s-uninstall.sh removes the entire cluster.'
fi
