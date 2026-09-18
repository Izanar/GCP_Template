#!/usr/bin/env bash
# Install k3s on a systemd-enabled WSL2 host; never overwrite the user's kubeconfig.
set -euo pipefail
export PATH="$PATH:/usr/local/bin"
K3S_VERSION="${1:-v1.31.1+k3s1}"
[[ "$(ps -p 1 -o comm=)" == systemd ]] || { echo 'Enable systemd in WSL2 first' >&2; exit 1; }
sudo -v
if command -v k3s >/dev/null 2>&1; then
  installed="$(k3s --version | head -1)"
  # Accept any k3s >= the requested version (an installed newer k3s is fine).
  required="${K3S_VERSION#v}"; required="${required%%+*}"
  have="$(printf '%s' "$installed" | awk '{print $3}')"; have="${have#v}"; have="${have%%+*}"
  min_ok() { # returns 0 if $1 >= $2 (dotted x.y.z compare)
    local a b i
    read -r -a a <<< "${1//./ }"; read -r -a b <<< "${2//./ }"
    for i in 0 1 2; do
      (( ${a[i]:-0} > ${b[i]:-0} )) && return 0
      (( ${a[i]:-0} < ${b[i]:-0} )) && return 1
    done
    return 0
  }
  if ! min_ok "$have" "$required"; then
    echo "Existing k3s $have is older than required v$required. Upgrade explicitly before deploying." >&2
    exit 1
  fi
  echo "Existing k3s $have satisfies the required minimum v$required."
else
  installer="$(mktemp)"
  trap 'rm -f "$installer"' EXIT
  curl -fsSL https://get.k3s.io -o "$installer"
  sudo env INSTALL_K3S_VERSION="$K3S_VERSION" sh "$installer"
fi
sudo systemctl start k3s
mkdir -p "$HOME/.kube"
sudo install -m 600 -o "$(id -u)" -g "$(id -g)" /etc/rancher/k3s/k3s.yaml "$HOME/.kube/gcp-template-k3s.yaml"
export KUBECONFIG="$HOME/.kube/gcp-template-k3s.yaml"
# wait does not wait for creation when the node list is still empty.
registered=false
for ((attempt = 0; attempt < 36; attempt++)); do
  if nodes="$(kubectl get nodes -o name --request-timeout=5s 2>/dev/null)" && [[ -n "$nodes" ]]; then
    registered=true
    break
  fi
  sleep 5
done
if [[ "$registered" != true ]]; then
  echo 'Timed out waiting for k3s node registration; inspect journalctl -u k3s.' >&2
  exit 1
fi
kubectl wait --for=condition=Ready node --all --timeout=180s --request-timeout=190s
printf 'Use: export KUBECONFIG=%s/.kube/gcp-template-k3s.yaml\n' "$HOME"
