#!/usr/bin/env bash
# Vérifie les outils et tente une installation sans sudo. Signale ce qui manque.
set -uo pipefail
command -v php >/dev/null && echo "OK php $(php -r 'echo PHP_VERSION;')" || echo "MANQUE php : s'appuyer sur la CI"
if ! command -v composer >/dev/null && command -v php >/dev/null; then
  mkdir -p "$HOME/bin" && curl -sS https://getcomposer.org/installer -o /tmp/cs.php 2>/dev/null \
    && php /tmp/cs.php --install-dir="$HOME/bin" --filename=composer >/dev/null 2>&1 && export PATH="$HOME/bin:$PATH"
fi
command -v composer >/dev/null && echo "OK composer" || echo "MANQUE composer"
if ! command -v flutter >/dev/null; then
  git clone --depth 1 -b stable https://github.com/flutter/flutter.git "$HOME/flutter" >/dev/null 2>&1 \
    && export PATH="$HOME/flutter/bin:$PATH"
fi
command -v flutter >/dev/null && flutter --version || echo "MANQUE flutter : s'appuyer sur la CI"
