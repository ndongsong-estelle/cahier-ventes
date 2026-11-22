# 03 — Serveur

Rôle : comptes, copie du cahier, statistiques d'usage, tableau de bord pour Estha.
Stack : Laravel stable, PHP 8.3+, Sanctum, MySQL/MariaDB (local XAMPP et prod), SQLite mémoire pour les tests, Pest, Pint.
Tableau de bord : Blade + Tailwind par CDN, sans build front, sans Filament.

## Configuration (.env)
OTP_ENABLED=false                    vérification du numéro par SMS à la création et pour "code oublié"
SMS_DRIVER=log                       log | smsto (module de reference/otp-sms-laravel)
BACKUP_ENABLED=true                  réception des copies (renvoyé aux apps par /config)
BACKUP_MIN_INTERVAL_MINUTES=360
BACKUP_KEEP=7
BACKUP_MAX_SIZE_KB=5120
BACKUP_ENCRYPT_AT_REST=false         chiffre les copies sur le disque (Crypt / APP_KEY)
ADMIN_EMAIL=, ADMIN_PASSWORD_HASH=   accès /admin (`php artisan pilote:admin` génère le hash)
SUPPORT_WHATSAPP=+237XXXXXXXXX

## Tables
users : id, phone unique (E.164), shop_name, pin_hash (bcrypt), pin_is_temporary bool, phone_verified_at null,
        failed_pin_attempts int, locked_until null, notes text null (Estha), timestamps.
devices : id uuid (device_id), user_id, app_version, android_version, device_model, clock_offset_seconds null,
          first_seen_at, last_seen_at.
personal_access_tokens : Sanctum.
otp_codes : module de reference/.
events : id uuid (dédoublonnage), user_id, device_id, name, props json null, occurred_at, occurred_at_corrected, received_at.
         Index (user_id, occurred_at_corrected).
answers : id uuid, user_id, question_id, value, text null, occurred_at_corrected.
app_errors : id uuid, user_id null, device_id, app_version, message, stack text, occurred_at_corrected, received_at.
questions : id (slug), text, kind (choice | text), choices json null, after_days int, active bool. Seed : docs/01.
backups : id uuid, user_id, path, size_bytes, sha256, counts json, encrypted bool, created_at.

Correction d'horloge : pour chaque lot, skew = received_at − sent_at ; occurred_at_corrected = occurred_at + skew.
Calculs de jours en Africa/Douala sur occurred_at_corrected.

## API (/api, JSON, chaque réponse contient server_time)
Public, throttle 10/min/IP :
POST /auth/check  {phone} -> {exists, otp_required}
POST /auth/otp/send, /auth/otp/verify -> module de reference/ (adapter : verify renvoie un otp_ticket signé valable
     10 min, utilisé par register et pin/reset ; pas de création d'utilisateur dans verify).
POST /auth/register {phone, shop_name, pin, device, otp_ticket?} -> 201 {token, user}. otp_ticket exigé si OTP_ENABLED.
     Refuse les codes faibles (même liste que l'app). 409 si le numéro existe.
POST /auth/login {phone, pin, device} -> {token, user, must_change_pin}. 5 échecs -> locked_until = +15 min (423).
     Révoque les autres tokens de l'utilisateur (un téléphone à la fois).
POST /auth/pin/reset {phone, otp_ticket, new_pin} -> {token, user} (seulement si OTP_ENABLED).
Authentifié (Sanctum, met à jour devices.last_seen_at) :
POST /auth/logout · GET /me · PATCH /me {shop_name} · POST /auth/pin {current_pin, new_pin}
DELETE /me {pin} -> supprime utilisateur, appareils, tokens, événements, réponses, erreurs, copies et fichiers.
POST /events {sent_at, items:[{id, name, props, occurred_at}]} (200 max) -> 202 {accepted, duplicates, ignored}.
     Item hors liste blanche (docs/02) ignoré seul. Id déjà connu = duplicate.
POST /answers, POST /errors : même format, même dédoublonnage.
GET  /config -> {questions, backup_enabled, backup_min_interval_minutes, support_whatsapp}
POST /backups (multipart file, sha256, counts) -> 201. 403 si BACKUP_ENABLED=false, 413 trop gros, 422 sha256 faux.
     Garde les BACKUP_KEEP plus récentes, supprime les fichiers des autres.
GET  /backups/latest -> {id, created_at, counts, sha256, download_url} ou 404 ; GET /backups/{id}/file.
Throttle authentifié : 120/min/utilisateur.

## Stockage des copies
storage/app/backups/{user_id}/{backup_id}.json.gz, jamais dans public. Si BACKUP_ENCRYPT_AT_REST=true : chiffré avec Crypt
avant écriture (encrypted=true) ; lecture selon ce champ. `php artisan pilote:chiffrer-copies` chiffre l'existant.
Limite (à écrire dans DEPLOY.md) : protège contre une fuite du disque ou d'une sauvegarde, pas contre un accès au serveur et à son .env.

## Tableau de bord /admin
Connexion ADMIN_EMAIL + mot de passe, session, throttle 5/min.
Page principale : trois chiffres (comptes créés, actifs aujourd'hui, actifs 7 jours) ; tableau, une ligne par compte :
boutique, numéro, créé le (jour du pilote), dernier passage, jours avec vente / jours depuis la création, ventes 7 j,
ventes total, relances, reçus, temps médian d'une vente, dernière copie, dernière réponse "aide ?" ;
ligne grise si aucune vente depuis 3 jours.
Fiche compte : ventes par jour (tableau 21 jours), fonctions utilisées, réponses, 10 dernières erreurs, copies (date,
taille, compteurs, jamais le contenu), notes libres, "Donner un code provisoire" (génère 4 chiffres affichés une fois,
pin_is_temporary = true, débloque le compte), "Supprimer ce compte et toutes ses données" (confirmation en tapant le numéro).
Pas de graphiques ni d'export. Commande `php artisan pilote:resume` : le tableau principal dans le terminal.

## Page publique /confidentialite
Ce qui est gardé (numéro, nom de boutique, copie du cahier avec noms et numéros des personnes, sans photos ;
statistiques d'usage de docs/02), pourquoi, qui y a accès, durée (tant que le compte existe ; comptes inactifs
supprimés après 12 mois), comment supprimer son compte (dans l'app ou via WhatsApp). Commentaire "À faire relire" dans la vue.
