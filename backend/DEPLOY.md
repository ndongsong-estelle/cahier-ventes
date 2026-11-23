# Mettre le serveur en ligne

Laravel 12, PHP 8.3+, MySQL ou MariaDB. Un hébergement mutualisé avec SSH et cron suffit pour le pilote.

## 1. Sous-domaine HTTPS

- Créez un sous-domaine, par exemple `cahier.votredomaine.cm`, dont la **racine web pointe sur `backend/public`**
  (jamais sur `backend/`, sinon `.env` et `storage/` seraient lisibles).
- Activez un certificat HTTPS (Let's Encrypt, souvent un bouton dans le panneau de l'hébergeur).
- L'app pilote n'accepte que le HTTPS : `PILOT_API_URL` = `https://cahier.votredomaine.cm/api`.
- Extensions PHP : `pdo_mysql`, `mbstring`, `openssl`, `zlib` (copies gzip), `intl`, `fileinfo`.

## 2. Code et dépendances

    git clone https://github.com/<vous>/cahier-ventes.git
    cd cahier-ventes/backend
    composer install --no-dev --optimize-autoloader
    cp .env.example .env
    php artisan key:generate

## 3. `.env`

    APP_NAME="Cahier de ventes"
    APP_ENV=production
    APP_DEBUG=false
    APP_URL=https://cahier.votredomaine.cm
    APP_LOCALE=fr

    DB_CONNECTION=mysql
    DB_HOST=127.0.0.1
    DB_PORT=3306
    DB_DATABASE=cahier
    DB_USERNAME=cahier
    DB_PASSWORD=un-mot-de-passe-long

    SESSION_DRIVER=database
    SESSION_SECURE_COOKIE=true
    CACHE_STORE=database
    QUEUE_CONNECTION=sync

    OTP_ENABLED=false
    SMS_DRIVER=log
    BACKUP_ENABLED=true
    BACKUP_MIN_INTERVAL_MINUTES=360
    BACKUP_KEEP=7
    BACKUP_MAX_SIZE_KB=5120
    BACKUP_ENCRYPT_AT_REST=false
    ADMIN_EMAIL=votre@adresse.cm
    ADMIN_PASSWORD_HASH=          # voir étape 5
    SUPPORT_WHATSAPP=+2376XXXXXXXX

**`APP_KEY` : notez-la dans votre gestionnaire de mots de passe.** Elle chiffre les copies si
`BACKUP_ENCRYPT_AT_REST=true` : si elle est perdue ou changée, ces copies deviennent illisibles.
Ne la régénérez jamais sur un serveur en service.

## 4. Base de données

    php artisan migrate --force
    php artisan db:seed --force        # questions courtes par défaut ("Est-ce que l'app vous aide ?"…)
    php artisan config:cache
    php artisan route:cache
    php artisan view:cache

Après chaque mise à jour du code : `git pull`, `composer install --no-dev --optimize-autoloader`,
`php artisan migrate --force`, puis les trois `cache` ci-dessus.

## 5. Compte admin (/admin)

    php artisan pilote:admin

Tapez un mot de passe de 12 caractères minimum ; la commande affiche une ligne `ADMIN_PASSWORD_HASH='...'`
à coller dans `.env` (avec les guillemets simples), puis `php artisan config:cache`.
Connexion sur `https://cahier.votredomaine.cm/admin` avec `ADMIN_EMAIL` et ce mot de passe (5 essais par minute).
Résumé dans le terminal : `php artisan pilote:resume`.

## 6. Cron

Une seule ligne dans la crontab de l'hébergement :

    * * * * * cd /chemin/vers/cahier-ventes/backend && php artisan schedule:run >> /dev/null 2>&1

Elle lance chaque nuit à 3 h (Douala) `pilote:supprimer-inactifs` : comptes sans utilisation depuis 12 mois
supprimés avec leurs copies, comme promis sur `/confidentialite`. Essai sans rien supprimer :
`php artisan pilote:supprimer-inactifs --essai`.

## 7. Sauvegarde du serveur

Deux choses à sauvegarder **chaque nuit**, et à copier hors du serveur (Google Drive, autre machine) :

1. la base : `mysqldump --single-transaction -u cahier -p cahier | gzip > cahier-$(date +%F).sql.gz`
2. les copies des cahiers : `tar czf copies-$(date +%F).tgz -C storage/app backups`

(dossier `storage/app/backups/{id du compte}/{id de la copie}.json.gz`, jamais servi par le web).
Gardez 14 jours. Testez une restauration une fois avant le pilote. Sauvegardez aussi le fichier `.env`
séparément (il contient `APP_KEY`).

## 8. Chiffrement des copies : ce qu'il protège, et ce qu'il ne protège pas

`BACKUP_ENCRYPT_AT_REST=true` chiffre chaque nouvelle copie avec `APP_KEY` avant de l'écrire sur le disque.
Pour chiffrer les copies déjà reçues : `php artisan pilote:chiffrer-copies`.

- Protège : une fuite du disque ou d'une sauvegarde (tar, dump) **sans** le fichier `.env`.
- Ne protège pas : quelqu'un qui accède au serveur et à son `.env` (il a la clé), ni l'app elle-même.
- Le tableau de bord ne lit jamais le contenu des copies, chiffrées ou non.

## 9. Activer la vérification par SMS plus tard

Rien à changer dans l'app : elle lit `otp_required` dans `/auth/check`.

1. Compte chez le fournisseur (module actuel : sms.to), clé d'API, nom d'expéditeur validé.
2. `.env` : `SMS_DRIVER=smsto`, `SMSTO_API_KEY=...`, `SMSTO_SENDER_ID=CahierVente`,
   `ANDROID_SMS_APP_HASH=` (hash de 11 caractères de l'app signée, pour le remplissage automatique du code),
   puis `OTP_ENABLED=true` et `php artisan config:cache`.
3. Testez avec votre numéro : création de compte, puis « Code oublié ? ».
Les envois sont limités (5 par heure et par numéro, 10 par IP, 500 par jour en tout) pour protéger le crédit SMS.

## 10. Points à surveiller

- **Throttle par IP** : 10 requêtes par minute et par IP sur les routes publiques (création, connexion).
  Les réseaux mobiles camerounais partagent souvent une même IP entre beaucoup d'abonnés (CGNAT) :
  si des personnes se plaignent de ne pas pouvoir se connecter au même moment, augmentez cette limite
  dans `app/Providers/AppServiceProvider.php` (`RateLimiter::for('public', ...)`).
- Derrière un proxy ou Cloudflare, configurez les proxys de confiance (`trustProxies` dans `bootstrap/app.php`),
  sinon toutes les requêtes semblent venir de la même IP.
- Faites relire `/confidentialite` (loi camerounaise sur les données personnelles) avant le pilote.
