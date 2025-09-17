#!/usr/bin/env bash
# render_values.sh <file> <key> <value>
set -euo pipefail
FILE="$1"; KEY="$2"; VALUE="$3"
if grep -q "^$KEY:" "$FILE"; then
  sed -i.bak "s|^$KEY:.*|$KEY: \"$VALUE\"|" "$FILE"
else
  echo "$KEY: \"$VALUE\"" >> "$FILE"
fi