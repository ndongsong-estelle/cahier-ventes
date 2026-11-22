# Avancement

| Ticket | Statut | Notes |
|---|---|---|
| T-00 | Fait | php 8.3.6, composer, Flutter 3.50.1 / Dart 3.14 ; backend/ et mobile/ déjà présents ; tests de base au vert |
| T-01 | Fait | Thème, router (3 onglets + Réglages), formatFcfa, signature key.properties. APK non construit en local (pas de SDK Android) : CI |
| T-02 | Fait | users/devices/otp_codes, Sanctum, /auth/*, /me, codes faibles, verrouillage 5 essais/15 min, un téléphone à la fois, OTP derrière OTP_ENABLED. 27 tests |
| T-03 | Fait | Drift (7 tables), domain/ledger.dart (règles pures), LedgerRepository ; 30 tests (partiel, 3 ventes, surplus, modification, suppression, minuit, lundi 0 h, il en reste) |
| T-04 | Fait | C1-C3 + SMS + nouveau code, token en secure storage, 401 global, cahier d'un autre compte effacé, message sans réseau ; 10 tests widget |
| T-05 | Fait | Aujourd'hui : total du jour, Reçu, On vous doit, liste, flèches + glissement, vide, total -> Bilan ; 3 tests widget |
| T-06 | Fait | J'ai vendu : pavé géant + 000, photos d'articles (plus vendus d'abord), étiquettes ×n, nom + suggestions, moyen, PAYÉ/UNE PARTIE/PAS ENCORE, Garder l'article, Annuler 5 s ; 8 tests widget dont 360×640 à 130 % |
| T-07 | Fait | Serveur : /backups (403/413/422, rétention BACKUP_KEEP, chiffrement Crypt, pilote:chiffrer-copies) + /config. App : data.json gzip+sha256, envoi conditionnel, restauration après connexion, SyncRunner 1 h ; 9 tests serveur + 10 tests app |

## Résumé phase A
- Fait : comptes (serveur + app C1-C3, SMS activable), base locale et règles de calcul testées, Aujourd'hui, J'ai vendu, copie automatique et restauration.
- Décisions en autonomie : voir DECISIONS.md (T-01 à T-07), dont mauvais code = 422, /config avancé, disque 'backups', sha256 sur le json.
- Tests : 36 côté serveur (Pest), 62 côté app (unitaires + widgets, dont 360×640 à 130 %). Pint et flutter analyze propres.
- À vérifier par Estha : git push refusé (403, accès GitHub) donc CI jamais lancée ; APK à construire par la CI une fois le push possible.
- À vérifier par Estha : parcours de création sur un vrai téléphone (pavé, SMS désactivé), et "J'ai vendu" en 3 touchers.

## Environnement
Session cloud : PHP 8.3.6, Composer, Flutter 3.50.1 installés. composer install lent (paquets clonés depuis git) mais OK.

## Ce qui reste à faire pour Estha

## Dernière session
