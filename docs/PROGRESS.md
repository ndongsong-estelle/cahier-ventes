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
| T-08 | Fait | Détail : montant, photos, articles, nom, heure, reçu par moyen et date, reste ; {Nom} a payé, Envoyer le reçu, Modifier, Supprimer + Annuler ; 5 tests widget |
| T-09 | Fait | On me doit : total, tri décroissant, depuis N jours, WhatsApp (numéro demandé une fois), fiche personne (a payé réparti + Annuler, montant trop grand, Relancer, Appeler, modifier) ; 5 tests widget |
| T-10 | Fait | Mes articles : grille photos/initiales, prix, nom, pastilles Plus que 2 / Épuisé, plus vendus d'abord ; ajout (photo, prix, nom) ; fiche (− +, Ne plus afficher) ; 4 tests widget |
| T-11 | Fait | Reçu (image partagée + WhatsApp direct), Bilan semaine/mois (vendu, reçu, on vous doit, flèche, 3 plus vendus), notification du dimanche 19 h ; 5 tests |
| T-12 | Fait | Réglages complets (compte, code, verrou à l'ouverture, déconnexion, suppression, bilan du dimanche, état de la copie, aide, écran technique) + copie manuelle .cahier ; 12 tests |

## Résumé phase B
- Fait : détail d'une vente, On me doit (+ fiche personne, WhatsApp), Mes articles, Reçu, Bilan, notification du dimanche, Réglages, copie manuelle.
- Décisions en autonomie : Modifier = un seul bouton "Garder" ; saisies de montant en plein écran ; reçu WhatsApp en texte ; voir DECISIONS.md T-08 à T-12.
- Bugs trouvés par les tests et corrigés : Hero en double sur "J'ai vendu", messages d'erreur hors écran, verrou sans Overlay, "par rapport à le mois".
- Tests : 36 serveur, 93 app. analyze et pint propres.
- À vérifier par Estha : reçu partagé dans WhatsApp, notification du dimanche, verrou à l'ouverture, copie manuelle d'un téléphone à l'autre.
| T-13 | Fait | Serveur /events /answers /errors (liste blanche, dédoublonnage, correction d'horloge, 200 max) + questions seedées dans /config ; app : outbox, lots de 200, erreurs, cartes de questions ; 8 tests serveur + 8 tests app |
| T-14 | Fait | Tableau de bord /admin (connexion + throttle, 3 chiffres, tableau, fiche compte, notes, code provisoire, suppression), pilote:admin, pilote:resume, /confidentialite ; 9 tests |
| T-15 | Fait | mobile/RELEASE.md, backend/DEPLOY.md, relecture 01-03 (purge des comptes inactifs ajoutée), test des mots interdits, résumé final |

## Environnement
Session cloud : PHP 8.3.6, Composer, Flutter 3.50.1 installés. composer install lent (paquets clonés depuis git) mais OK.

## Résumé phase C
- Fait : suivi d'usage (liste blanche, dédoublonnage, correction d'horloge, questions courtes), tableau de bord /admin, /confidentialite, RELEASE.md, DEPLOY.md.
- Décisions en autonomie : props aussi en liste blanche ; ventes du tableau = sale_saved − sale_undone ; purge des comptes inactifs ajoutée (DECISIONS.md T-13 à T-15).
- Tests : 54 serveur (Pest), 102 app (unitaires + widgets). Pint et flutter analyze propres. Mots interdits vérifiés par un test.
- À vérifier par Estha : tableau de bord avec de vrais comptes, réponse aux questions courtes, purge (--essai) avant le premier cron.
- À vérifier par Estha : rien n'a pu être poussé ni passé en CI (voir ci-dessous).

## Résumé final
Les 16 tickets (T-00 à T-15) sont faits et commités un par un sur `main`, en local. Aucun n'a pu être poussé :
GitHub a refusé chaque `git push` (403, pas d'accès de Claude au dépôt), donc la CI n'a jamais tourné et l'APK n'a jamais été construit.
Les tests tournent ici : 54 serveur et 102 app, tous au vert. Il n'y a pas de SDK Android dans cette session, donc
la compilation Android (Gradle, désugarage, manifeste) est la principale inconnue.

## Ce qui reste à faire pour Estha
1. **Accès GitHub** : connecter GitHub à Claude (claude.ai/connect-github) et installer l'app Claude sur le dépôt, puis pousser
   les commits locaux de `main` (16 commits T-00 à T-15) : `git push origin main` depuis cette session ou une nouvelle.
2. **CI** : vérifier qu'elle passe (backend : pint + tests ; mobile : analyze + tests + APK). Si le build APK échoue, c'est
   probablement le désugarage Java ou le manifeste (notifications) : coller les 20 lignes utiles de l'erreur.
3. **APK de test** : XAMPP + `php artisan serve --host=0.0.0.0`, CI > Run workflow avec `api_url`, installer sur deux vrais
   téléphones d'entrée de gamme. Vérifier : création du compte sans aide, « J'ai vendu » en 3 touchers, bandeau Annuler,
   récupération du cahier sur un deuxième téléphone, reçu partagé dans WhatsApp, verrou à l'ouverture,
   notification du dimanche 19 h qui ouvre le Bilan.
4. **Serveur en ligne** : sous-domaine HTTPS + MySQL, suivre backend/DEPLOY.md (`.env`, migrations, seed, `pilote:admin`,
   cron, sauvegarde nuit de la base et de storage/app/backups). Garder `APP_KEY` en lieu sûr.
5. **Signature** : créer le keystore sous Windows, secrets de l'environment `pilote`, variables `PILOT_API_URL` et
   `PILOT_CERT_SHA256` (mobile/RELEASE.md), puis « Build pilote ». Garder `upload.jks` et ses mots de passe hors du dépôt.
6. **SMS (plus tard)** : compte sms.to, clé, nom d'expéditeur, `ANDROID_SMS_APP_HASH`, puis `OTP_ENABLED=true`.
7. **Juridique** : faire relire `/confidentialite` (loi camerounaise sur les données personnelles).
8. **Pilote** : surveiller le throttle 10/min/IP (IP partagées des réseaux mobiles), voir DEPLOY.md § 10.
9. **À décider** (choix faits par défaut, voir DECISIONS.md) : « Modifier » avec un seul bouton « Garder » ;
   « On vous doit » du Bilan = restes des ventes de la période ; reçu WhatsApp en texte.

## Dernière session
2026-11-22/23 : backlog complet T-00 → T-15 en une session, push impossible (403).
