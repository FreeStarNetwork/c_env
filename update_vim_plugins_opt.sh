#!/bin/bash
set -e
VIM_PACK="$HOME/.vim/pack"

echo "=== Update tpope opt plugins ==="
for d in "$VIM_PACK/tpope/opt"/*/; do
  echo "Update: $d"
  (cd "$d" && git pull || true)
done

echo "=== Update vendor opt plugins ==="
for d in "$VIM_PACK/vendor/opt"/*/; do
  echo "Update: $d"
  (cd "$d" && git pull || true)
done

vim -c "helptags ALL" -c q
echo "Plugin update finished"

