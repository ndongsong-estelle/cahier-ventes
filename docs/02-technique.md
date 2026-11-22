# 02 — App mobile : technique

## Stack
Flutter stable, Dart 3, Android uniquement, minSdk 26, applicationId cm.cahierventes.app, nom "Cahier de ventes".
Paquets : flutter_riverpod, drift + drift_flutter, dio, go_router, image_picker, flutter_image_compress,
path_provider, share_plus, url_launcher, flutter_local_notifications, timezone, flutter_timezone, uuid, intl,
file_picker, archive, connectivity_plus, crypto (sha256), flutter_secure_storage, sms_autofill (OTP sans permission SMS).
Aucune permission sensible (ni contacts, ni SMS, ni localisation). Pas d'autre paquet sans justification dans DECISIONS.md.
Structure : lib/core (db, theme, format, router, api, auth, telemetry, backup), lib/features/<onglet>/{data,domain,ui}.

## Design
Thème unique dans lib/core/theme : vert #1B873F, rouge #C62828, orange #E37400, fond clair, contrastes AA.
Texte courant 18 sp minimum, montants 32 à 56 sp, boutons principaux 64 dp de haut minimum.
Tient sans texte coupé sur 360 × 640 dp avec police à 130 %. Animations < 200 ms.

## Données (Drift)
settings : clé/valeur (user_id, phone, shop_name, shop_phone, weekly_summary, pin_on_open, device_id,
           last_backup_at, last_backup_hash, clock_offset_seconds, installed_at).
Token d'accès dans flutter_secure_storage, jamais dans Drift.
people : id, name, phone null (+237…), created_at, updated_at, deleted_at.
articles : id, name null, price int, photo_path null, remaining int null, hidden bool, created_at, updated_at, deleted_at.
sales : id, amount int > 0, person_id null, sold_at, photo_path null, created_at, updated_at, deleted_at.
sale_articles : id, sale_id, article_id, quantity int.
payments : id, sale_id, amount int > 0, method (cash | orange_money | momo), paid_at, created_at, updated_at, deleted_at.
outbox : id (uuid), kind (event | answer | error), payload json, created_at.
Photos : 800 px max, ~100 Ko, JPEG, dossier de l'app ; fichier supprimé quand plus rien ne le référence.

## Règles de calcul (domain/, tests unitaires obligatoires)
- reçu(vente) = somme des paiements non supprimés ; reste(vente) = max(0, montant − reçu).
- Vente "Payé" : un paiement du montant total à l'heure de la vente.
- Modifier le montant : si le reçu dépasse le nouveau montant, réduire le dernier paiement.
- "{Nom} a payé X" : réparti sur ses ventes avec reste > 0, de la plus ancienne à la plus récente.
- On vous doit (personne) = somme de ses restes ; total = somme sur toutes les personnes.
- "depuis N jours" = jours depuis sa plus ancienne vente non soldée.
- Vendu (période) = somme des montants des ventes de la période ; Reçu = somme des paiements de la période.
  Semaine = lundi à dimanche, heure locale du téléphone.
- Il en reste : −quantité à la vente, rétabli si la vente est supprimée ou modifiée. "Plus que 2" si 1 ou 2,
  "Épuisé" si <= 0. Jamais de blocage.
- Articles les plus vendus = somme des quantités sur 30 jours.

## Compte et connexion au serveur
- PILOT_API_URL (adresse de l'API) par --dart-define. Vide = build de développement pointant sur http://10.0.2.2:8000/api.
- device_id (UUID) créé au premier lancement, envoyé à chaque connexion.
- Parcours C1-C3 de docs/01 avec les endpoints /auth de docs/03. Le serveur renvoie otp_required dans /auth/check.
- Code secret : jamais stocké sur le téléphone en clair. Si "Demander le code à chaque ouverture" est actif,
  stocker un hash sha256 salé dans flutter_secure_storage pour le vérifier hors ligne.
- Après connexion : GET /backups/latest ; si présent, restauration (voir plus bas) avant d'afficher Aujourd'hui.
  Si le téléphone contient le cahier d'un AUTRE compte : effacer d'abord les données locales.
- Toute réponse 401 : effacer le token, garder les données locales, afficher le message "ouvert sur un autre téléphone",
  aller à C1. Si la même personne se reconnecte, ses données locales sont envoyées en copie si elles sont plus récentes
  que la copie du serveur (sinon on restaure celle du serveur).
- Envois (événements, copies) seulement avec réseau, à l'ouverture puis au plus une fois par heure. Une seule opération
  réseau à la fois. Chaque réponse contient server_time : l'app garde clock_offset_seconds.

## Suivi d'usage
- Chaque événement : {id uuid, name, props, occurred_at (heure du téléphone)}. Stocké dans outbox,
  envoyé par lots de 200 avec sent_at (heure du téléphone à l'envoi), supprimé de l'outbox seulement après réponse 2xx.
  Le serveur dédoublonne par id : renvoyer un lot ne compte jamais deux fois.
- Liste blanche (rien d'autre ne part) :
  app_opened {} · tab_viewed {tab} · sale_started {} ·
  sale_saved {payment: paid|partial|unpaid, method, amount_bucket, articles_count, used_photo, has_person, seconds} ·
  sale_undone {} · sale_edited {} · sale_deleted {} · payment_added {method, amount_bucket} · reminder_sent {} ·
  call_made {} · receipt_sent {} · article_kept {} · article_created {has_photo} · summary_opened {period} ·
  manual_copy_made {} · manual_copy_restored {} · pin_changed {} · question_answered {question_id}.
  amount_bucket : lt5k | 5k_20k | 20k_100k | gt100k. seconds = de sale_started à sale_saved, plafonné à 600.
- Réponses aux questions : kind answer {question_id, value, text}. Erreurs : FlutterError.onError et
  PlatformDispatcher.onError, kind error {message, stack tronquée à 4 Ko, app_version}.
- Questions : GET /config à l'ouverture (si réseau), mis en cache.
- Test obligatoire : chaque événement émis par l'app est validé contre la liste blanche.

## Copie automatique du cahier
- Contenu : le même data.json que la copie manuelle (tables métier + shop_name, shop_phone ; sans photos, sans token),
  gzip, version de format incluse.
- Envoi si backup_enabled (renvoyé par /config) ET contenu changé (sha256 ≠ last_backup_hash) ET au moins
  backup_min_interval_minutes depuis la dernière copie (défaut 360). Toujours tenté à l'ouverture si la dernière copie a
  plus de 24 h et que le contenu a changé.
- POST /backups (multipart : fichier, sha256, counts). Succès : last_backup_at, last_backup_hash.
- Restauration : GET /backups/latest -> fichier, vérification sha256, remplacement dans une transaction.

## Copie manuelle
Fichier .cahier (zip : data.json + dossier photos). Import : vérifie la version, remplace tout dans une transaction,
restaure les photos.

## CI (déjà fournie, à garder à jour)
Push : tests backend et mobile, APK de développement (serveur 10.0.2.2, pour l'émulateur) en artifact.
Lancement manuel avec api_url : APK de test pointant vers le serveur local d'Estha (téléphone sur le même Wi-Fi).
Lancement manuel "Build pilote" : échoue si la variable PILOT_API_URL est vide ; signe avec le keystore des secrets
(échoue s'il manque) ; APK armeabi-v7a et arm64-v8a en artifact.
