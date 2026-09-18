#!/usr/bin/env bash
# Deploy one environment with Terragrunt (+ Ansible for the GCE scenario).
# Usage: ./scripts/deploy.sh [scenario]
#
# Scenarios:
#   gce           GCP Compute Engine + nginx (needs gcloud and an SSH key)
#   gke-autopilot GCP GKE Autopilot (needs gcloud)
#   gke-gcs-cdn   GCP GKE + GCS + Cloud CDN (needs gcloud)
#   local-wsl     Local k3s on WSL2 (no cloud credentials required)
set -euo pipefail
export PATH="$PATH:/usr/local/bin"

cd "$(dirname "$0")/.."

SCENARIO="${1:-local-wsl}"
case "$SCENARIO" in
  gce|gke-autopilot|gke-gcs-cdn|local-wsl) ;;
  *) echo 'Usage: deploy.sh {gce|gke-autopilot|gke-gcs-cdn|local-wsl}' >&2; exit 1 ;;
esac
ENV_DIR="envs/${SCENARIO}"

if [[ ! -f "${ENV_DIR}/terragrunt.hcl" ]]; then
  echo "Unknown scenario: ${SCENARIO}" >&2
  echo "Available: gce gke-autopilot gke-gcs-cdn local-wsl" >&2
  exit 1
fi

command -v terragrunt >/dev/null || { echo "terragrunt is required" >&2; exit 1; }
command -v curl >/dev/null || { echo "curl is required" >&2; exit 1; }

tg() { (cd "$ENV_DIR" && terragrunt "$@"); }

# Fail before provisioning, not after billable resources have been created.
if [[ "$SCENARIO" != local-wsl ]]; then
  for tool in gcloud ansible-playbook; do
    command -v "$tool" >/dev/null || { echo "$tool is required" >&2; exit 1; }
  done
  if [[ "$SCENARIO" == gke-* ]]; then
    if [[ "$SCENARIO" == gke-gcs-cdn ]]; then
      command -v git >/dev/null || { echo 'git is required for audio upload' >&2; exit 1; }
      command -v gsutil >/dev/null || { echo 'gsutil is required for audio upload' >&2; exit 1; }
    fi
    command -v kubectl >/dev/null || { echo 'kubectl is required' >&2; exit 1; }
  fi
else
  command -v git >/dev/null || { echo 'git is required' >&2; exit 1; }
  [[ "$(ps -p 1 -o comm=)" == systemd ]] || { echo 'Enable systemd in WSL2 first' >&2; exit 1; }
  sudo -v
  export KUBECONFIG="$HOME/.kube/gcp-template-k3s.yaml"
fi

# Cloud scenarios require project, region and explicit cost confirmation
if [[ "$SCENARIO" != "local-wsl" ]]; then
  gcp_project="${GOOGLE_PROJECT:-}"
  [[ -n "$gcp_project" ]] || read -r -p "GCP project ID (required): " gcp_project
  [[ -n "$gcp_project" ]] || { echo 'A project ID is required' >&2; exit 1; }
  export GOOGLE_PROJECT="$gcp_project"

  gcp_region="${GOOGLE_REGION:-}"
  [[ -n "$gcp_region" ]] || read -r -p "GCP region [europe-west1]: " gcp_region
  export GOOGLE_REGION="${gcp_region:-europe-west1}"

  budget_email="${BUDGET_EMAIL:-}"
  export BUDGET_EMAIL="$budget_email"

  read -r -p "This will create billable resources. Continue? [yes/no]: " confirmation
  [[ "$confirmation" == "yes" ]] || { echo "Cancelled."; exit 0; }
else
  export GOOGLE_PROJECT=""
  export GOOGLE_REGION="europe-west1"
  budget_email=""
  export BUDGET_EMAIL="$budget_email"
fi

if [[ "$SCENARIO" == gce ]]; then
  read -r -p "SSH public key path [$HOME/.ssh/id_rsa.pub]: " public_key_path
  public_key_path="${public_key_path:-$HOME/.ssh/id_rsa.pub}"
  [[ -f "$public_key_path" && -f "${public_key_path%.pub}" ]] || { echo 'SSH key pair not found' >&2; exit 1; }
  public_key_path="$(realpath "$public_key_path")"
  export TF_VAR_public_key_path="$public_key_path"
  runner_ip="$(curl -fsS --max-time 15 https://api.ipify.org)"
  export TF_VAR_ssh_cidr_blocks="[\"${runner_ip}/32\"]"
fi
# Verify the project when the Cloud Resource Manager API is available; if it is
# disabled, Terraform will still validate the project during apply.
if [[ "$SCENARIO" != local-wsl ]]; then
  if ! CLOUDSDK_CORE_DISABLE_PROMPTS=1 gcloud projects describe "$GOOGLE_PROJECT" >/dev/null 2>&1; then
    echo "WARNING: could not verify project '$GOOGLE_PROJECT' via Cloud Resource Manager (API may be disabled or no permission). Continuing; terraform apply will validate it." >&2
  fi
  if [[ -n "${BUDGET_EMAIL:-}" && -z "${BILLING_ACCOUNT:-}" ]]; then
    echo 'BILLING_ACCOUNT is required with BUDGET_EMAIL' >&2; exit 1
  fi
  if [[ "$SCENARIO" == gke-* ]]; then
    command -v gke-gcloud-auth-plugin >/dev/null || { echo 'Install gke-gcloud-auth-plugin' >&2; exit 1; }
    mkdir -p "$HOME/.kube"
    export KUBECONFIG="$HOME/.kube/gcp-template-${GOOGLE_PROJECT}-${SCENARIO}.yaml"
    umask 077
  fi
  if [[ "$SCENARIO" == gke-gcs-cdn && -z "${CDN_DOMAIN:-}" ]]; then
    echo 'Set CDN_DOMAIN to your owned audio hostname before deploy' >&2; exit 1
  fi
fi
trap 'echo "Deployment failed. Resources may remain; run scripts/destroy.sh for this scenario using the same state and project." >&2' ERR

# Full smoke check: the page must load and the media it references must be
# served (HTTP 200/206). Audio content itself is for the user to check by ear.
smoke_test() { # $1 = base URL (media paths are relative to it)
  local base="$1" page media_srcs f url code
  page="$(mktemp)"
  curl -fsSL --max-time 30 "$base" -o "$page" || { echo "Smoke test FAILED: page not reachable at $base" >&2; rm -f "$page"; return 1; }
  [[ -s "$page" ]] || { echo 'Smoke test FAILED: page is empty' >&2; rm -f "$page"; return 1; }
  echo ">>> Page OK ($(wc -c < "$page") bytes): $(grep -o '<title>[^<]*</title>' "$page" | head -1)"
  media_srcs="$(grep -oE 'src="[^"]*\.(mp3|ogg|wav|m4a)"' "$page" | sed 's/src="//; s/"//' | sort -u || true)"
  if [[ -z "$media_srcs" ]]; then
    echo '>>> No media referenced on the page; content smoke test OK'
    rm -f "$page"; return 0
  fi
  for f in $media_srcs; do
    case "$f" in
      http://*|https://*) url="$f" ;;
      /*)                 url="${base}${f}" ;;
      *)                  url="${base}/${f}" ;;
    esac
    code="$(curl -fsSL --max-time 60 -o /dev/null -w '%{http_code}' "$url" 2>/dev/null || true)"
    if [[ "$code" == 200 || "$code" == 206 ]]; then
      echo ">>> Media OK [$code] $f"
    else
      echo "Smoke test FAILED: media '$f' not served (HTTP=$code)" >&2
      rm -f "$page"; return 1
    fi
  done
  rm -f "$page"
  # shellcheck disable=SC2086  # word splitting is intended: one path per line
  echo ">>> Smoke test OK: page + $(printf '%s\n' $media_srcs | wc -l) media file(s) served"
}

echo ">>> Applying scenario '${SCENARIO}' ..."
tg init -input=false
tg plan -input=false
tg apply -input=false -auto-approve

case "$SCENARIO" in
  gce)

  public_ip="$(tg output -raw public_ip)"
  umask 077
  inventory="$(mktemp)"
  trap 'rm -f "$inventory"' EXIT
  cat > "$inventory" <<INV
[webservers]
${public_ip} ansible_user=ubuntu ansible_ssh_private_key_file='${public_key_path%.pub}' ansible_ssh_common_args='-o StrictHostKeyChecking=accept-new'
INV
  ANSIBLE_ROLES_PATH="ansible/roles" ansible-playbook -i "$inventory" ansible/playbooks/gce.yml
  nginx_url="http://${public_ip}"
  echo ">>> AI_Nginx demo is live at: $nginx_url"
  smoke_test "$nginx_url"
  ;;

  gke-autopilot|gke-gcs-cdn)
  cluster_name="$(tg output -raw cluster_name)"
  gcloud container clusters get-credentials "$cluster_name" --region "$GOOGLE_REGION" --project "$GOOGLE_PROJECT"
  if [[ "$SCENARIO" == gke-gcs-cdn ]]; then
    export AUDIO_BUCKET_NAME CDN_DOMAIN
    AUDIO_BUCKET_NAME="$(tg output -raw audio_bucket_name)"
    CDN_DOMAIN="$(tg output -raw cdn_domain)"
    echo ">>> Point DNS A record ${CDN_DOMAIN} to $(tg output -raw cdn_ip)."
    echo '>>> Certificate provisioning may take time; rerun the Ansible playbook after DNS and HTTPS are ready.' 
    ANSIBLE_ROLES_PATH="ansible/roles" ansible-playbook ansible/playbooks/gke-gcs-deploy.yml
  else
    ANSIBLE_ROLES_PATH="ansible/roles" ansible-playbook ansible/playbooks/gke-deploy.yml
  fi
  echo ">>> Deployed. Use kubectl port-forward -n ai-nginx-demo svc/ai-nginx-app 8080:80 for local access."
  ;;

  local-wsl)
  command -v kubectl >/dev/null || { echo "kubectl is required for the local scenario" >&2; exit 1; }
  echo ">>> Deploying AI_Nginx (site + media) to the local cluster via Ansible ..."
  ANSIBLE_ROLES_PATH="ansible/roles" ansible-playbook ansible/playbooks/local-wsl.yml
  node_port="$(tg output -raw node_port)"
  echo ">>> AI_Nginx demo is live at: http://localhost:${node_port} (inside WSL)"
  echo ">>> From Windows use the WSL address, e.g.: http://$(hostname -I | awk '{print $1}'):${node_port}"
  smoke_test "http://localhost:${node_port}"
  ;;

  *)
  echo "Unknown scenario: $SCENARIO" >&2
  exit 1
  ;;
esac
