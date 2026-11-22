# OTP par SMS — Laravel 11+

## Installation
1. Copier les fichiers dans le projet (fusionner AppServiceProvider et routes/api.php si existants).
2. `php artisan install:api` (installe Sanctum et routes/api.php si absent).
3. Dans `App\Models\User` : ajouter `HasApiTokens`, et `phone`, `name` dans `$fillable`.
4. `php artisan migrate`
5. `.env` :
   SMS_DRIVER=log            # passer à smsto en production
   SMSTO_API_KEY=
   SMSTO_SENDER_ID=MaBoutique
   ANDROID_SMS_APP_HASH=     # fourni par l'app Flutter (package sms_autofill)

## Endpoints
POST /api/auth/otp/send    { "phone": "690000000" }
POST /api/auth/otp/verify  { "phone": "690000000", "code": "123456", "device_name": "Tecno Spark" }
→ { token, user, is_new }

## Test rapide (driver log)
curl -X POST localhost:8000/api/auth/otp/send -H "Accept: application/json" -d phone=690000000
Le code apparaît dans storage/logs/laravel.log.

## Ajouter un autre fournisseur
Créer une classe qui implémente App\Sms\SmsSender, puis l'ajouter au `match` de AppServiceProvider.
