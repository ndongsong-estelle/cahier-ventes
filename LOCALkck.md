# Préparation en local (Windows) — économise des tokens

Tout ce qui est mécanique (créer les projets, télécharger les paquets) coûte des tokens à Claude Code et échoue
parfois en session cloud. Fais-le une fois chez toi, puis pousse.

## 1. Créer les deux projets (PowerShell, à la racine du dépôt)
    composer create-project laravel/laravel backend
    cd backend
    php artisan install:api          # installe Sanctum ; répondre "no" à la question des migrations
    composer remove phpunit/phpunit --dev
    composer require pestphp/pest pestphp/pest-plugin-laravel --dev --with-all-dependencies
    ./vendor/bin/pest --init
    cd ..
    flutter create --org cm.cahierventes --project-name cahier_ventes --platforms android mobile
    cd mobile
    flutter pub add flutter_riverpod drift drift_flutter dio go_router image_picker flutter_image_compress path_provider share_plus url_launcher flutter_local_notifications timezone flutter_timezone uuid intl file_picker archive connectivity_plus crypto flutter_secure_storage sms_autofill
    flutter pub add dev:drift_dev dev:build_runner
    flutter test                     # doit passer avec le test par défaut
    cd ..
    git add . ; git commit -m "Squelettes backend et mobile" ; git push

Vérifie que composer.lock et pubspec.lock sont bien commités (ils le sont par défaut).

## 2. Configurer l'environnement de la session cloud
Dans les réglages de l'environnement Claude Code, mets comme script d'installation : `bash scripts/setup-env.sh`.
Ainsi PHP, Composer et Flutter sont installés une fois au démarrage, et pas par l'agent au fil de la conversation.
Si Flutter ne s'installe pas dans le cloud, la CI GitHub reste l'arbitre des tests mobiles.

## 3. Une session par phase
Le backlog a trois phases (A, B, C). Ouvre une nouvelle session pour chacune avec PROMPT_PHASE.md.
Une conversation longue relit tout son historique à chaque échange : repartir à zéro par phase coûte beaucoup moins.
Dans une même session, `/compact` quand la conversation s'allonge.

## 4. Choisir le modèle
Les phases B et C sont du travail d'écran et de CRUD : un modèle moins coûteux suffit (commande `/model`).
Garde le plus puissant pour la phase A (comptes, copie, restauration).

## 5. Pendant que l'agent travaille
- Ne colle pas de longs logs : copie seulement les 20 lignes utiles de l'erreur.
- Une remarque = un message court qui cite le ticket ("T-06 : le bouton PAYÉ est trop petit").
- Teste toi-même l'APK sur ton téléphone plutôt que de demander à l'agent de "vérifier l'interface" (il ne voit pas l'écran).
