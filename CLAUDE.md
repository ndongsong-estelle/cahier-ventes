# Cahier de ventes — règles pour Claude Code

App Android de suivi des ventes pour petits commerçants camerounais. Chaque utilisateur a un compte
(numéro + code secret). L'app marche sans internet après la connexion ; le serveur garde une copie du cahier.
mobile/ = Flutter, backend/ = Laravel, docs/ = source de vérité, reference/ = code existant à réutiliser.

## Simplicité d'abord
Utilisatrice pressée, téléphone d'entrée de gamme, parfois peu à l'aise avec la lecture.
Une action principale énorme par écran ; jamais de formulaire long ; seuls les mots du glossaire (docs/01) ;
une icône par action ; vert = reçu, rouge = on vous doit, orange = une partie ; tout se corrige, "Annuler" après
chaque enregistrement. Si ça demande une explication, simplifier ou retirer (noter dans DECISIONS.md).

## Méthode
1. Suivre docs/04-backlog.md dans l'ordre. Pour chaque ticket, lire UNIQUEMENT les sections indiquées dans le ticket.
2. Un ticket = un commit "T-XX: titre". Rien hors backlog.
3. Jamais de question : choisir l'option la plus simple pour l'utilisatrice, l'écrire en une ligne dans
   docs/DECISIONS.md, continuer. Blocage humain : contourner (mock, config), noter dans PROGRESS.md, continuer.
4. Fini = critères d'acceptation testés et au vert. Lancer seulement les tests concernés pendant le travail
   (`php artisan test --filter=...`, `flutter test test/chemin`), la suite complète une fois en fin de ticket.
   Sorties courtes : `php artisan test --compact`, `flutter test -r compact`. Max 2 tentatives sur un avertissement de style.
5. PROGRESS.md : une ligne par ticket, pas de journal détaillé.
6. Ne pas lire ni afficher vendor/, node_modules/, build/, .dart_tool/, ni les fichiers *.g.dart générés.
7. Locks commités, pas de mise à jour de dépendances hors ticket, aucun secret dans le dépôt.

## Invariants
Montants en int FCFA ("15 000 F"), jamais de float. UUID v4 générés sur le téléphone (entités et événements).
Le montant saisi fait foi. Ce qu'on vous doit est calculé, jamais stocké. Téléphones en +2376XXXXXXXX.
Statistiques d'usage limitées à la liste blanche (docs/02), vérifiée par un test.
Le tableau de bord ne lit jamais le contenu des copies du cahier.
Textes en français, vouvoiement chaleureux, phrases courtes.
