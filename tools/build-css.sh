#!/usr/bin/env bash
# Tailwind CSS'i HTML'deki sinif kullanimina gore yeniden derler (assets/tailwind.css). Gelistirme makinesinde calistirilir.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
W=${TWBUILD_DIR:-/tmp/twbuild}
mkdir -p "$W" && cd "$W"
[ -d node_modules/tailwindcss ] || { npm init -y >/dev/null 2>&1; npm install tailwindcss@3.4.10 --no-audit --no-fund >/dev/null; }
printf '@tailwind base;\n@tailwind components;\n@tailwind utilities;\n' > in.css
echo "module.exports={content:['$ROOT/Kuzgun_Iletisim_CRM.html'],theme:{extend:{}},plugins:[]}" > tailwind.config.js
./node_modules/.bin/tailwindcss -c tailwind.config.js -i in.css -o "$ROOT/assets/tailwind.css" --minify
echo "CSS OK: $(wc -c < "$ROOT/assets/tailwind.css") bytes"
