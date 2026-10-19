#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")"
gh auth status
gh auth setup-git
if [[ -e .git ]]; then echo 'Git checkout already exists; inspect it before publishing manually.'; exit 1; fi
if gh repo view cuzzaintit321/linux-network-doctor >/dev/null 2>&1; then
    echo 'Repository already exists; inspect it before publishing manually.'; exit 1
fi
git init -b main
git add .
git -c user.name='Jason Edwards' \
    -c user.email='228125969+cuzzaintit321@users.noreply.github.com' \
    commit -m 'Add Bash network diagnostics with fixture tests and documentation'
gh repo create cuzzaintit321/linux-network-doctor --public --source . --remote origin --push \
    --description 'Read-only Bash troubleshooting tool for Linux interfaces, routing, name resolution, and optional HTTPS checks.'
