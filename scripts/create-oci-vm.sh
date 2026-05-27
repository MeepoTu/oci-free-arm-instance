#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="${ENV_FILE:-$REPO_DIR/.env}"
STATE_FILE="${STATE_FILE:-$REPO_DIR/.oci-vm-created}"

if [ -f "$ENV_FILE" ]; then
  set -a
  # shellcheck disable=SC1090
  . "$ENV_FILE"
  set +a
fi

log() {
  printf '[%s] %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*"
}

fail() {
  log "ERROR: $*"
  exit 1
}

require_env() {
  local missing=0
  for name in "$@"; do
    if [ -z "${!name:-}" ]; then
      log "ERROR: missing required environment value: $name"
      missing=1
    fi
  done
  [ "$missing" -eq 0 ] || exit 1
}

require_env \
  OCI_CLI_REGION \
  OCI_COMPARTMENT_ID \
  OCI_SUBNET_ID \
  OCI_CLI_USER \
  OCI_CLI_TENANCY \
  OCI_CLI_FINGERPRINT \
  OCI_CLI_KEY_FILE \
  SSH_PUBLIC_KEY_FILE \
  AD_NAME \
  IMAGE_ID

INSTANCE_NAME="${INSTANCE_NAME:-coolify-vm}"
BOOT_VOLUME_SIZE_GB="${BOOT_VOLUME_SIZE_GB:-200}"
SHAPE="${SHAPE:-VM.Standard.A1.Flex}"
SHAPE_CONFIG="${SHAPE_CONFIG:-{\"ocpus\":4,\"memoryInGBs\":24}}"
OCI_CONFIG_FILE="${OCI_CONFIG_FILE:-$HOME/.oci/config}"

case "$OCI_SUBNET_ID" in
  ocid1.subnet*) ;;
  *) fail "OCI_SUBNET_ID must start with ocid1.subnet. Do not use a VCN OCID." ;;
esac

[ -s "$OCI_CLI_KEY_FILE" ] || fail "OCI_CLI_KEY_FILE does not exist or is empty: $OCI_CLI_KEY_FILE"
[ -s "$SSH_PUBLIC_KEY_FILE" ] || fail "SSH_PUBLIC_KEY_FILE does not exist or is empty: $SSH_PUBLIC_KEY_FILE"

SSH_PUBLIC_KEY="$(tr -d '\r\n' < "$SSH_PUBLIC_KEY_FILE")"
case "$SSH_PUBLIC_KEY" in
  ssh-rsa\ *|ssh-ed25519\ *|ecdsa-sha2-nistp256\ *|ecdsa-sha2-nistp384\ *|ecdsa-sha2-nistp521\ *) ;;
  *) fail "SSH_PUBLIC_KEY_FILE must contain public key text, for example output from: cat ~/.ssh/oracle.pub" ;;
esac

if [ -f "$STATE_FILE" ]; then
  log "State file exists, assuming VM was already created: $STATE_FILE"
  exit 0
fi

if ! command -v oci >/dev/null 2>&1; then
  fail "oci CLI is not installed or not in PATH"
fi

mkdir -p "$(dirname "$OCI_CONFIG_FILE")"
cat > "$OCI_CONFIG_FILE" <<EOF
[DEFAULT]
user=$OCI_CLI_USER
tenancy=$OCI_CLI_TENANCY
fingerprint=$OCI_CLI_FINGERPRINT
key_file=$OCI_CLI_KEY_FILE
region=$OCI_CLI_REGION
EOF
chmod 600 "$OCI_CONFIG_FILE"
chmod 600 "$OCI_CLI_KEY_FILE"

log "Trying to create $SHAPE instance '$INSTANCE_NAME' in $OCI_CLI_REGION..."
OCI_OUTPUT="$(oci compute instance launch \
  --compartment-id "$OCI_COMPARTMENT_ID" \
  --availability-domain "$AD_NAME" \
  --shape "$SHAPE" \
  --shape-config "$SHAPE_CONFIG" \
  --subnet-id "$OCI_SUBNET_ID" \
  --image-id "$IMAGE_ID" \
  --ssh-authorized-keys-file "$SSH_PUBLIC_KEY_FILE" \
  --assign-public-ip true \
  --display-name "$INSTANCE_NAME" \
  --boot-volume-size-in-gbs "$BOOT_VOLUME_SIZE_GB" 2>&1 || true)"

printf '%s\n' "$OCI_OUTPUT"

if printf '%s\n' "$OCI_OUTPUT" | grep -q '"lifecycle-state": "PROVISIONING"'; then
  printf '%s\n' "$OCI_OUTPUT" > "$STATE_FILE"
  log "VM is being created. State saved to $STATE_FILE; cron runs will now skip."
  exit 0
fi

if printf '%s\n' "$OCI_OUTPUT" | grep -q 'Out of host capacity'; then
  log "Oracle returned Out of host capacity. Try again on the next cron run."
  exit 0
fi

fail "Unexpected OCI error."
