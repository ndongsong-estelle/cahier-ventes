# Kit Claude Code — Cahier de ventes

App Android de suivi des ventes pour petits commerçants, avec compte (numéro + code secret), qui marche sans internet
après la connexion. Un serveur Laravel gère les comptes, garde une copie de chaque cahier et te montre l'usage.

## Démarrer
1. Dépôt GitHub vide, copie ce kit à la racine.
2. Suis LOCAL.md (création des projets en local, environnement cloud). Pousse.
3. Ouvre une session Claude Code, colle PROMPT_PHASE.md. Il s'arrête à la fin de la phase A.
   Teste : lance `php artisan serve --host=0.0.0.0` sous XAMPP, puis dans GitHub > Actions > CI > Run workflow,
   mets api_url = http://IP-de-ton-PC:8000/api et installe l'APK produit sur ton téléphone (même Wi-Fi). Ensuite nouvelle session et même prompt pour B, puis C.

## Ce que tu dois faire toi-même
- LOCAL.md (une demi-heure).
- Tester l'APK sur au moins deux vrais téléphones d'entrée de gamme à la fin de chaque phase.
- Sous-domaine HTTPS + base MySQL pour le serveur, puis backend/DEPLOY.md (écrit en T-15).
- Variable GitHub PILOT_API_URL et keystore dans les secrets avant toute distribution (mobile/RELEASE.md).
- Si tu actives la vérification par SMS : compte chez le fournisseur, clé, nom d'expéditeur.
- Faire relire /confidentialite au regard de la loi camerounaise sur les données personnelles.

## Protocole du pilote
- À l'installation : la personne crée son compte elle-même, devant toi, sans aide. Chronomètre et note où elle bloque :
  c'est ton premier test de simplicité.
- J+0 à J+14 : pas de relance pour inciter à l'usage (sauf problème technique).
- Entretiens à J+3 et J+21, notés dans la fiche du compte. Va voir aussi ceux qui ont abandonné.
- À J+21 : proposer le mois suivant à 1 000 F payés par MoMo ou OM. Le nombre de personnes qui paient est le résultat principal.

## Contenu
CLAUDE.md, LOCAL.md, PROMPT_PHASE.md
docs/01-produit.md (écrans, glossaire) · 02-technique.md (app) · 03-serveur.md (API, admin) · 04-backlog.md (16 tickets, 3 phases)
reference/otp-sms-laravel (module SMS existant)
