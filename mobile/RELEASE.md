# Livrer l'app (APK pilote)

L'APK est construit par GitHub Actions (workflow **CI**). Rien à installer chez vous à part Java (pour `keytool`).

## 1. Créer la clé de signature (une seule fois, sous Windows)

Ouvrez PowerShell dans un dossier **hors du dépôt** (par exemple `Documents\cahier-cle`) :

    keytool -genkeypair -v -keystore upload.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000

`keytool` est fourni avec Java (Android Studio l'installe dans `C:\Program Files\Android\Android Studio\jbr\bin`).
Notez le mot de passe du keystore et celui de la clé (souvent le même).

**Gardez `upload.jks` et ses mots de passe en lieu sûr (clé USB + gestionnaire de mots de passe).**
Sans eux, impossible de publier une mise à jour installable par-dessus l'app des commerçantes :
il faudrait désinstaller, et le cahier local serait perdu (la copie du serveur reste, mais sans les photos).
Ne commitez jamais ce fichier (le `.gitignore` refuse déjà `*.jks` et `key.properties`).

Empreinte SHA-256 du certificat (pour vérifier les APK) :

    keytool -list -v -keystore upload.jks -alias upload

Copiez la ligne `SHA256: AB:CD:...`.

## 2. Mettre la clé dans GitHub

Encodez le keystore en base64 et copiez-le dans le presse-papiers :

    [Convert]::ToBase64String([IO.File]::ReadAllBytes("upload.jks")) | Set-Clipboard

Sur GitHub : **Settings > Environments > New environment** nommé `pilote` (exactement), puis dans cet environment :

| Type | Nom | Valeur |
|---|---|---|
| Secret | `KEYSTORE_BASE64` | le texte copié ci-dessus |
| Secret | `KEYSTORE_PASSWORD` | mot de passe du keystore |
| Secret | `KEY_ALIAS` | `upload` |
| Secret | `KEY_PASSWORD` | mot de passe de la clé |

Puis **Settings > Secrets and variables > Actions > Variables** (niveau dépôt) :

| Nom | Valeur |
|---|---|
| `PILOT_API_URL` | `https://votre-sous-domaine/api` (HTTPS obligatoire, voir backend/DEPLOY.md) |
| `PILOT_CERT_SHA256` | l'empreinte SHA-256 notée plus haut (facultatif, mais recommandé) |

Conseil : dans l'environment `pilote`, ajoutez une règle « Deployment branches : main seulement ».

## 3. Construire

- **APK de test** (votre PC sous XAMPP, même Wi-Fi) : GitHub > Actions > CI > Run workflow, laissez « Build pilote »
  décoché, mettez `api_url` = `http://IP-de-votre-PC:8000/api`. Lancez le serveur avec
  `php artisan serve --host=0.0.0.0`. Cet APK s'appelle « Cahier de ventes Dev » et accepte le HTTP.
- **Build pilote** (à distribuer) : Run workflow depuis `main`, cochez « Build pilote ».
  Le workflow échoue volontairement si `PILOT_API_URL` ou le keystore manquent, ou si l'APK est signé
  avec une clé de debug ou une autre empreinte que `PILOT_CERT_SHA256`. Le flavor pilote n'accepte que le HTTPS.

Résultat : artifact `apk-pilote` (zip) avec deux fichiers :

- `app-arm64-v8a-pilote-release.apk` : presque tous les téléphones récents (à essayer d'abord) ;
- `app-armeabi-v7a-pilote-release.apk` : vieux téléphones d'entrée de gamme (si le premier refuse de s'installer).

Le numéro de version (`versionCode`) suit le numéro du run GitHub : chaque build pilote s'installe par-dessus le précédent.

## 4. Installer sur un téléphone

1. Envoyez l'APK par WhatsApp (en « Document ») ou par câble.
2. Touchez le fichier. Android demande d'autoriser l'installation depuis WhatsApp ou le gestionnaire de fichiers :
   **Paramètres > Autoriser depuis cette source**, puis retour.
3. **Avertissement Android / Play Protect** : « Application non vérifiée » ou « bloquée par Play Protect ».
   C'est normal pour une app hors Play Store : touchez **Plus de détails > Installer quand même**.
   Ne désactivez pas Play Protect.
4. Au premier lancement, Android 13+ demande d'autoriser les notifications (bilan du dimanche) : « Autoriser ».
5. La personne crée son compte elle-même (protocole du pilote, README).

## 5. Mettre à jour

Même procédure : un nouveau Build pilote, même clé, installé par-dessus. Le cahier reste sur le téléphone.
