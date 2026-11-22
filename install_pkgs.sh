#!/bin/bash
# Lancé à chaque début de session cloud (hook SessionStart de .claude/settings.json).
# Installe les dépendances du projet si elles manquent. Ne fait rien en local.
[ "$CLAUDE_CODE_REMOTE" = "true" ] || exit 0
cd "$CLAUDE_PROJECT_DIR" || exit 0
if [ -f backend/composer.json ] && [ ! -d backend/vendor ]; then
  (cd backend && composer install --no-interaction --quiet) || true
fi
if [ -f backend/.env.example ] && [ ! -f backend/.env ]; then
  (cd backend && cp .env.example .env && php artisan key:generate --quiet) || true
fi
if [ -f mobile/pubspec.yaml ] && command -v flutter >/dev/null 2>&1 && [ ! -d mobile/.dart_tool ]; then
  (cd mobile && flutter pub get >/dev/null) || true
fi
exit 0
