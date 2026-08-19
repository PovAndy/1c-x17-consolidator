#!/usr/bin/env bash
set -euo pipefail

home_dir="${HOME:-{HOME}}"
local_bin="$home_dir/.local/bin"
venv_root="{WORKSPACE_ROOT}/venv"
add_src="{WORKSPACE_ROOT}/add"
add_dst="$venv_root/lib/add"

mkdir -p "$local_bin" "$venv_root/lib"

cat > "$local_bin/oscript" <<'EOF'
#!/usr/bin/env bash
exec {WORKSPACE_ROOT}/venv/bin/oscript "$@"
EOF

cat > "$local_bin/opm" <<'EOF'
#!/usr/bin/env bash
exec {WORKSPACE_ROOT}/venv/bin/oscript {WORKSPACE_ROOT}/venv/lib/opm/src/cmd/opm.os "$@"
EOF

chmod +x "$local_bin/oscript" "$local_bin/opm"

if [ -e "$add_dst" ] && [ ! -L "$add_dst" ]; then
  mv "$add_dst" "$add_dst.bak.$(date +%Y%m%d%H%M%S)"
fi

rm -f "$add_dst"
ln -s "$add_src" "$add_dst"

echo "OK"
echo "oscript=$(command -v "$local_bin/oscript")"
echo "opm=$(command -v "$local_bin/opm")"
echo "add=$add_dst -> $add_src"
