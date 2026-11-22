# 01 — Produit

## Glossaire (les seuls mots autorisés dans l'interface)
J'ai vendu · Vente · Payé · Pas encore payé · Une partie · On vous doit · {Nom} a payé · Relancer · Appeler ·
Mes articles · Il en reste · Épuisé · Reçu · Envoyer · Aujourd'hui · Cette semaine · Bilan · Espèces ·
Orange Money · MoMo · Annuler · Supprimer · Garder · Non merci · Copie de votre cahier · Remettre ·
Mon compte · Code secret · Se connecter · Créer mon compte · Se déconnecter.
Interdits : encaissé, crédit, débit, remise, stock, synchroniser, sauvegarde, valider, paramètres, transaction,
serveur, données, identifiant, mot de passe, OTP.

## Compte (premier lancement)
Internet est nécessaire seulement ici. Sans réseau : "Il faut internet pour ouvrir votre compte. Réessayez
quand vous avez du réseau." avec un bouton "Réessayer".

C1. Numéro
- icône de cahier, "Votre cahier de ventes" ;
- champ numéro avec "+237" fixe devant, pavé numérique, accepte espaces ;
- bouton "Continuer".
Le serveur dit si le numéro a déjà un compte : on va à C3 (connexion) sinon à C2 (création).

C2. Créer mon compte (un seul écran)
- "Nom de votre boutique" (champ texte, prérempli vide, obligatoire, 2 caractères minimum) ;
- "Choisissez un code secret de 4 chiffres" (pavé), puis "Tapez-le encore une fois" ;
- texte : "Une copie de votre cahier est gardée en sécurité pour que vous ne perdiez rien si vous changez
  de téléphone. Nous voyons aussi comment l'app est utilisée, pour l'améliorer." + lien "En savoir plus" ;
- bouton "Créer mon compte" (vaut acceptation).
Si la vérification par SMS est activée sur le serveur : écran "Code reçu par SMS" (6 cases, remplissage automatique,
"Renvoyer" après 60 s) entre le numéro et cet écran.
Codes refusés : 0000, 1234, 1111… (suites et répétitions) avec "Choisissez un code plus difficile à deviner."

C3. Se connecter
- "Bonjour ! Tapez votre code secret" (pavé, 4 cases) ;
- "Code oublié ?" : si SMS activé, code par SMS puis nouveau code secret ; sinon "Contactez l'aide sur WhatsApp"
  (Estha réinitialise depuis l'admin et vous donne un code provisoire, à changer à la connexion suivante) ;
- 5 erreurs : "Trop d'essais. Réessayez dans 15 minutes."
Après connexion : si une copie du cahier existe, "Récupération de votre cahier…" puis Aujourd'hui ; sinon Aujourd'hui vide
avec une flèche vers "J'ai vendu".
L'utilisatrice reste connectée : le code secret n'est plus demandé à chaque ouverture (option dans Réglages).

Un compte n'est ouvert que sur un téléphone à la fois. Se connecter ailleurs ferme l'ancien, qui affiche :
"Votre compte est ouvert sur un autre téléphone." et revient à C1.

## Navigation
Trois onglets en bas avec icônes : Aujourd'hui · On me doit · Mes articles.
Bouton "J'ai vendu" (gros, vert, icône +) en bas au centre sur Aujourd'hui et On me doit.
Icône engrenage en haut à droite : Réglages.

## Aujourd'hui
+--------------------------------------+
|  ‹   Lundi 16 novembre   ›        ⚙  |
|            85 000 F                  |
|         vendus aujourd'hui           |
|  ● Reçu 60 000 F  ● On vous doit 25 000 F |
|--------------------------------------|
| [img] Maman Ngo     10:42  15 000 F  |
|                     ● Doit 10 000 F  |
| [img] Vente         10:15   8 000 F  |
|                     ● Payé           |
|           [ + J'AI VENDU ]           |
| Aujourd'hui · On me doit · Mes articles |
+--------------------------------------+
- Flèches et glissement pour changer de jour. Toucher le gros total ouvre le Bilan.
- Toucher une vente ouvre son détail.
- Vide : "Pas encore de vente aujourd'hui. Touchez J'ai vendu."
- Carte en haut : question courte (voir plus bas).

## J'ai vendu (écran le plus important)
+--------------------------------------+
| ✕              15 000 F              |
|  Robe fleurie ×1  ✕                  |
|--------------------------------------|
| [img][img][img][img][img]  [+ Photo] |
| 👤 Nom (facultatif)  [Maman Ngo][Sali]|
| ( Espèces ) ( Orange Money ) ( MoMo )|
|   1     2     3                      |
|   4     5     6                      |
|   7     8     9                      |
|  000    0     ⌫                      |
| [ PAYÉ ✓ ] [UNE PARTIE] [PAS ENCORE] |
+--------------------------------------+
- Montant en très gros. Pavé numérique géant avec touche "000".
- Rangée de photos des articles (les plus vendus d'abord). Toucher une photo ajoute son prix au montant et une
  étiquette "Nom ×1" ; retoucher = ×2 ; la croix de l'étiquette retire.
- "+ Photo" : ouvre la galerie (appareil photo en second choix). La photo s'attache à la vente.
- Nom : facultatif, suggestions des noms déjà utilisés (un toucher suffit). Un nom nouveau crée la personne.
- Moyen : Espèces sélectionné par défaut.
- PAYÉ : enregistre, entièrement payé.
- PAS ENCORE : sans nom, une fenêtre demande "Qui vous doit ?" (suggestions + saisie), puis enregistre.
- UNE PARTIE : pavé "Combien avez-vous reçu ?", puis nom obligatoire comme ci-dessus, puis enregistre.
- Boutons désactivés tant que le montant est 0.
- Nouvelle photo ajoutée : fenêtre "Garder cet article pour la prochaine fois ?" (photo, prix prérempli,
  nom facultatif, [Garder] [Non merci]).
- Retour sur Aujourd'hui avec bandeau "Vente enregistrée · Annuler" pendant 5 secondes.
- Objectif : article connu payé en espèces = 3 touchers (J'ai vendu, photo, PAYÉ).

## Détail d'une vente
Montant, photos des articles, nom, heure, ce qui a été reçu (lignes avec moyen et date), ce qui reste.
Actions : "{Nom} a payé" (si reste > 0 : pavé prérempli avec le reste + moyen), "Envoyer le reçu",
"Modifier" (rouvre J'ai vendu prérempli), "Supprimer" (avec confirmation).

## On me doit
+--------------------------------------+
|        On vous doit 140 000 F        |
| Maman Ngo       25 000 F   [WhatsApp]|
| depuis 12 jours                      |
| Sali            40 000 F   [WhatsApp]|
+--------------------------------------+
- Tri par montant décroissant. Vide : "Personne ne vous doit d'argent. Bravo !"
- Bouton WhatsApp : relance directe. Numéro inconnu : le demander une fois (pavé), le garder.
- Fiche personne : montant dû en gros, ventes non payées avec photos, "{Nom} a payé" (prérempli = tout ;
  réparti de la plus ancienne vente à la plus récente ; montant trop grand : "{Nom} ne vous doit que X F."),
  "Relancer", "Appeler", modifier nom/numéro.
- Message : "Bonjour {Nom}, c'est {boutique}. Il reste {montant} F à régler. Merci et bonne journée !"


## Mes articles
Grille de grandes photos, prix dessous, nom s'il existe, pastille "Plus que 2" (orange) ou "Épuisé" (rouge)
si "il en reste" est suivi. Les plus vendus d'abord.
"+ Ajouter un article" : photo (galerie d'abord), prix, nom facultatif.
Fiche article : photo, prix, nom ; "Il en reste combien ?" facultatif avec − et + ; "Ne plus afficher".
Sans photo : tuile colorée avec initiales.

## Reçu
Image : nom et numéro de la boutique, date, articles (nom ou "Article"), montant, reçu, reste, "Merci !".
Partage Android ; si la personne a un numéro, proposer aussi
d'ouvrir directement sa discussion WhatsApp.

## Bilan
Depuis le gros total ou la notification du dimanche. Onglets Cette semaine / Ce mois : vendu, reçu,
on vous doit, comparaison avec la période précédente (flèche verte ou rouge), 3 articles les plus vendus.
Notification chaque dimanche à 19 h : "Votre bilan de la semaine est prêt 📒". Désactivable.

## Réglages
- Mon compte : numéro (lecture seule), nom de la boutique, numéro WhatsApp de la boutique (pour le reçu),
  "Changer mon code secret", "Demander le code à chaque ouverture" (non par défaut), "Se déconnecter",
  "Supprimer mon compte" (explication claire, code secret demandé, internet nécessaire, efface tout sur le serveur
  et sur le téléphone).
- Bilan du dimanche : oui/non.
- "Dernière copie de votre cahier : aujourd'hui à 14 h" (ou "Pas encore de copie", ou "En attente de réseau").
- "Copie de votre cahier" > "Envoyer une copie" (fichier partagé) et "Remettre une copie" (avertissement
  "Cela remplace votre cahier actuel").
- Aide : WhatsApp vers le numéro de support (fourni par le serveur).
- Version. Toucher 7 fois : écran technique (dernier envoi réussi, éléments en attente, adresse du serveur).

## Questions courtes (cartes sur Aujourd'hui)
Jamais pendant une vente, au plus une par jour, disparaît pour de bon dès qu'on répond ou qu'on ferme.
Fournies par le serveur ; valeurs par défaut :
- après 3 jours avec des ventes : "Est-ce que l'app vous aide ?" [😀 Oui] [😐 Un peu] [🙁 Non]
- après 10 jours : "Qu'est-ce qui vous manque ?" texte court facultatif, [Envoyer] [Plus tard]
