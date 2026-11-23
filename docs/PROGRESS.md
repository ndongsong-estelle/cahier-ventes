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

## Environnement
Session cloud : PHP 8.3.6, Composer, Flutter 3.50.1 installés. composer install lent (paquets clonés depuis git) mais OK.

## Ce qui reste à faire pour Estha
- Donner à Claude l'accès GitHub au dépôt (claude.ai/connect-github + app Claude GitHub installée) : tous les git push
  de cette session ont été refusés (403). Les commits sont sur main en local ; sans push, la CI n'a jamais tourné.
- Vérifier que la CI construit l'APK (désugarage Java ajouté pour les notifications, jamais compilé ici faute de SDK Android).
- Sur un vrai téléphone : la notification du dimanche 19 h arrive et ouvre le Bilan.

## Dernière session
