# 04 — Backlog

Chaque ticket indique les sections à lire. Trois phases, une session Claude Code par phase.

## Phase A — le cœur (arrêt à la fin)
T-00 Environnement. Lire : LOCAL.md. Vérifier php, composer, flutter et que backend/ et mobile/ existent déjà
     (créés en local par Estha). S'ils n'existent pas, les créer avec les commandes de LOCAL.md. Résultat dans PROGRESS.md.
T-01 Socle mobile. Lire : 02 Stack, Design. Thème, router, 3 onglets + Réglages vides, formatFcfa, signature
     via android/key.properties si présent. CA : app démarre, CI verte, APK de dev en artifact.
T-02 Comptes côté serveur. Lire : 03 Configuration, Tables, API (partie auth), reference/otp-sms-laravel.
     users, devices, Sanctum, /auth/*, /me, codes faibles, verrouillage, un téléphone à la fois, OTP derrière OTP_ENABLED.
     CA : tests inscription, connexion, verrouillage après 5 échecs, révocation de l'ancien token, OTP exigé seulement
     si activé, suppression complète du compte.
T-03 Base locale et calculs. Lire : 02 Données, Règles de calcul. CA : tests de chaque règle (paiement partiel,
     répartition sur 3 ventes, montant trop grand, modification, suppression, périodes autour de minuit et lundi 0 h, il en reste).
T-04 Compte côté app. Lire : 01 Compte ; 02 Compte et connexion. Écrans C1-C3, secure storage, 401 global,
     cahier d'un autre compte effacé, message sans réseau. CA : widget tests création, connexion, code faible refusé, 401.
T-05 Aujourd'hui. Lire : 01 Navigation, Aujourd'hui.
T-06 J'ai vendu. Lire : 01 J'ai vendu. CA : widget tests : article connu payé en 3 touchers ; "Pas encore" sans nom
     demande le nom ; Annuler supprime la vente et rétablit "il en reste".
T-07 Copie automatique. Lire : 02 Copie automatique ; 03 /backups, Stockage. Serveur (rétention, interrupteurs,
     chiffrement activable, commande) + app (envoi conditionnel, restauration après connexion).
     CA : téléphone A -> serveur -> connexion sur téléphone B = cahier identique (hors photos) ; copie inchangée non
     renvoyée ; BACKUP_ENABLED=false -> rien envoyé ; copies chiffrées et non chiffrées restaurables.
     >>> FIN DE PHASE A : s'arrêter et résumer.

## Phase B — compléter l'app (arrêt à la fin)
T-08 Détail d'une vente. Lire : 01 Détail d'une vente.
T-09 On me doit. Lire : 01 On me doit.
T-10 Mes articles. Lire : 01 Mes articles.
T-11 Reçu, Bilan, notification du dimanche. Lire : 01 Reçu, Bilan.
T-12 Réglages complet + copie manuelle. Lire : 01 Réglages ; 02 Copie manuelle. >>> FIN DE PHASE B.

## Phase C — suivi et livraison
T-13 Suivi d'usage. Lire : 02 Suivi d'usage ; 03 /events, /answers, /errors, /config. Serveur + app + questions courtes
     (01 Questions courtes). CA : test liste blanche sur tous les événements émis ; même lot deux fois = compté une fois ;
     horloge en avance de 3 jours corrigée ; app utilisable serveur coupé.
T-14 Tableau de bord. Lire : 03 Tableau de bord, Page publique. CA : calculs testés sur données factices ; code provisoire
     testé ; suppression sans reste (lignes et fichiers).
T-15 Livraison. mobile/RELEASE.md (keystore sous Windows, secrets et variable GitHub, "Build pilote", installation, avertissement
     Android) ; backend/DEPLOY.md (sous-domaine HTTPS, .env, migrations, seed, compte admin, cron, sauvegarde de la base et de
     storage/app/backups, limite du chiffrement, activer OTP plus tard). Relire 01 à 03 contre le code, corriger ou noter dans
     DECISIONS.md, vérifier les mots interdits, résumé final dans PROGRESS.md.
