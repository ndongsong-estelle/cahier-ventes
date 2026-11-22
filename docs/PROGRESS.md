# Avancement

| Ticket | Statut | Notes |
|---|---|---|
| T-00 | Fait | php 8.3.6, composer, Flutter 3.50.1 / Dart 3.14 ; backend/ et mobile/ déjà présents ; tests de base au vert |
| T-01 | Fait | Thème, router (3 onglets + Réglages), formatFcfa, signature key.properties. APK non construit en local (pas de SDK Android) : CI |
| T-02 | Fait | users/devices/otp_codes, Sanctum, /auth/*, /me, codes faibles, verrouillage 5 essais/15 min, un téléphone à la fois, OTP derrière OTP_ENABLED. 27 tests |
| T-03 | Fait | Drift (7 tables), domain/ledger.dart (règles pures), LedgerRepository ; 30 tests (partiel, 3 ventes, surplus, modification, suppression, minuit, lundi 0 h, il en reste) |

## Environnement
Session cloud : PHP 8.3.6, Composer, Flutter 3.50.1 installés. composer install lent (paquets clonés depuis git) mais OK.

## Ce qui reste à faire pour Estha

## Dernière session
