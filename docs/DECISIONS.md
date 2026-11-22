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
- 2026-11-22 — T-02 — Codes faibles : 4 chiffres identiques, suites (1234/4321), motif ABAB (1212) et une courte liste (2580, 1122…) ; même règle à copier dans l'app
- 2026-11-22 — T-02 — Erreurs API : {code, message} (code stable pour l'app, phrase en français) ; numéro inconnu au login = 404 unknown_phone
- 2026-11-22 — T-02 — Le nom du token Sanctum est l'id du téléphone (devices.id) : last_seen_at mis à jour sans table de liaison
- 2026-11-22 — T-02 — Sans OTP, pin/reset renvoie 403 otp_disabled : le code oublié passe par le code provisoire d'Estha (/admin)
- 2026-11-22 — T-03 — Fichiers drift générés (*.g.dart) commités : la CI fournie ne lance pas build_runner
- 2026-11-22 — T-03 — "{Nom} a payé X" plus grand que ce qui est dû : seul le dû est enregistré, le surplus est rendu à l'écran (pas de crédit d'avance)
- 2026-11-22 — T-03 — Montant réduit sous le reçu : on réduit le dernier paiement, puis le précédent si besoin (paiement à 0 = supprimé)
- 2026-11-22 — T-03 — Suppressions douces (deleted_at) partout ; "il en reste" peut devenir négatif (jamais de blocage), affiché Épuisé
- 2026-11-22 — T-04 — Mauvais code secret = 422 wrong_pin (et non 401) : 401 est réservé à « compte ouvert sur un autre téléphone »
- 2026-11-22 — T-04 — C2 : champs code secret avec le pavé numérique du téléphone (3 champs sur un écran) ; C3 : grand pavé dans l'app avec 4 cases
- 2026-11-22 — T-04 — Code oublié sans SMS : lien WhatsApp (numéro de /config, sinon --dart-define SUPPORT_WHATSAPP) avec un message prérempli
- 2026-11-22 — T-04 — Modèle du téléphone non envoyé (null) : device_info_plus n'est pas dans la liste des paquets ; version Android = Platform.operatingSystemVersion
- 2026-11-22 — T-04 — Se déconnecter garde le cahier sur le téléphone ; il n'est effacé que si un autre compte se connecte ensuite
- 2026-11-22 — T-05 — Sur Aujourd'hui, "On vous doit" = restes des ventes du jour ; "Reçu" = tous les paiements du jour (même pour d'anciennes ventes), comme docs/02
- 2026-11-22 — T-05 — Ligne de vente : partiel = pastille orange "Doit X", rien payé = rouge "Doit X", soldé = vert "Payé" ; titre = personne, sinon premier article, sinon "Vente"
- 2026-11-22 — T-05 — Pas de navigation vers les jours futurs ; dates en français écrites à la main (pas d'initialisation intl)
