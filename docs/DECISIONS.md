# Décisions

## Figées
- Compte obligatoire : numéro + nom de boutique + code secret à 4 chiffres. Vérification SMS désactivée par défaut
  (OTP_ENABLED), activable sans changer l'app.
- Un compte = une boutique = un téléphone connecté à la fois.
- L'app fonctionne hors ligne après la connexion. Internet requis pour créer le compte, se connecter, le supprimer.
- Le serveur garde une copie du cahier (sans photos), non chiffrée par défaut ; BACKUP_ENCRYPT_AT_REST l'active.
- Code oublié sans SMS : code provisoire donné par Estha depuis /admin.
- Le tableau de bord ne lit jamais le contenu des copies.
- Le montant saisi fait foi ; les articles sont facultatifs et se créent depuis les ventes.
- Vouvoiement chaleureux. applicationId cm.cahierventes.app, nom "Cahier de ventes".

## Prises en autonomie
(date — ticket — décision — raison)
- 2026-11-22 — T-01 — formatFcfa utilise des espaces insécables ("15 000 F" ne se coupe jamais en deux lignes)
- 2026-11-22 — T-01 — applicationId passé à cm.cahierventes.app et minSdk 26 (docs/02) ; namespace Kotlin inchangé
- 2026-11-22 — T-01 — Imports via package:material_ui (package:flutter/material.dart est déprécié depuis Flutter 3.47)
