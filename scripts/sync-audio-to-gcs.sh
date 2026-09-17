#!/usr/bin/env bash
# Upload application audio to the scenario-owned private bucket; never delete objects.
# Usage: sync-audio-to-gcs.sh <app-checkout-or-repository-url> <bucket>
set -euo pipefail
source="${1:?Application checkout or repository URL required}"
bucket="${2:?GCS bucket name required}"
ref="${APP_SOURCE_REF:-main}"
[[ "$bucket" =~ ^[a-z0-9][a-z0-9._-]{1,61}[a-z0-9]$ ]] || { echo 'Invalid bucket name' >&2; exit 1; }
[[ "$source" != -* && "$ref" != -* ]] || { echo 'Invalid source/ref' >&2; exit 1; }
command -v gsutil >/dev/null
work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT
if [[ -d "$source" ]]; then
  checkout="$source"
else
  command -v git >/dev/null
  git clone --depth 1 --no-checkout "$source" "$work_dir/app"
  git -C "$work_dir/app" fetch --depth 1 origin "$ref"
  git -C "$work_dir/app" checkout --detach FETCH_HEAD
  checkout="$work_dir/app"
fi
audio_dir="$checkout/html/audio"
[[ -d "$audio_dir" && -f "$audio_dir/rain.mp3" ]] || {
  echo 'Expected html/audio/ with rain.mp3 in the application checkout' >&2
  exit 1
}
gsutil -q -m rsync -r -e "$audio_dir/" "gs://${bucket}/audio/"
echo "Audio uploaded to gs://${bucket}/audio/"
