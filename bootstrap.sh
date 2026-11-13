#!/bin/sh
# bootstrap.sh — Build the reusable `hermes-agy:v1` sbx template from scratch
set -eu

SANDBOX_NAME="${1:-hermes-agy-builder}"

echo "1. Allowing Google / Antigravity egress domains in sbx policy..."
sbx policy allow network "antigravity.google,**.antigravity.google,**.run.app,**.googleapis.com,**.google.com"

echo "2. Creating builder sandbox from nousresearch/hermes-agent:latest..."
sbx create --name "$SANDBOX_NAME" -t nousresearch/hermes-agent:latest shell ./workspace

echo "3. Installing native Linux agy CLI and Hermes ACP provider plugin..."
sbx exec "$SANDBOX_NAME" -- sh -c '
set -eu
curl -fsSL https://antigravity.google/cli/install.sh | bash
mv /root/.local/bin/agy /usr/local/bin/agy
chmod 755 /usr/local/bin/agy
ln -sfn /usr/local/bin/agy /root/.local/bin/agy
chmod 755 /root

# Patch overlayfs AF_UNIX socket fallback
sed -i "s/_SOCKET_UNSUPPORTED_ERRNOS = frozenset({errno.EOPNOTSUPP, errno.ENOTSUP})/_SOCKET_UNSUPPORTED_ERRNOS = frozenset({errno.EOPNOTSUPP, errno.ENOTSUP, errno.ENAMETOOLONG})/" /opt/hermes/gateway/control_socket.py

# Register agy as a native Hermes ACP model provider in rootfs
mkdir -p /opt/hermes/plugins/model-providers/agy
cat << '\''EOF'\'' > /opt/hermes/plugins/model-providers/agy/plugin.yaml
name: agy-provider-profile
kind: model-provider
version: 1.0.0
description: Google Antigravity CLI (agy) native Linux ACP provider
author: Antigravity
EOF

cat << '\''EOF'\'' > /opt/hermes/plugins/model-providers/agy/__init__.py
from agent.acp_client import ACPClient
from providers import register_provider
from providers.base import ProviderProfile

class AgyACPClient(ACPClient):
    default_command = "/usr/local/bin/agy"
    default_args = ("acp",)
    label = "Antigravity"

class AgyProfile(ProviderProfile):
    def create_client(self, **kwargs):
        return AgyACPClient(command="/usr/local/bin/agy", args=("acp",))

register_provider(AgyProfile(
    name="agy",
    display_name="Antigravity",
    auth_type="external_process",
    process_command="/usr/local/bin/agy",
    process_args=("acp",),
    base_url="acp://agy",
))
EOF

# Auto-seed /opt/data volume on first run of any new container
sed -i "/^REAL=\/opt\/hermes\/.venv\/bin\/hermes/a \\
[ -e /opt/data/.gemini ] || ln -sfn /root/.gemini /opt/data/.gemini\\
if [ ! -f /opt/data/config.yaml ]; then\\
    printf \"model:\\n  default: agy\\n  provider: agy\\n\" > /opt/data/config.yaml\\
    chown 10000:10000 /opt/data/config.yaml 2>/dev/null || true\\
fi" /opt/hermes/bin/hermes
'

echo ""
echo "4. Next step — Sign in to Google/Gmail inside the builder sandbox once:"
echo "   sbx exec -it $SANDBOX_NAME -- agy"
echo ""
echo "5. After signing in, snapshot the template:"
echo "   sbx exec $SANDBOX_NAME -- sh -c 'chmod -R 777 /root/.gemini && hermes gateway stop --yes || true'"
echo "   sbx stop $SANDBOX_NAME"
echo "   sbx template save $SANDBOX_NAME hermes-agy:v1"
