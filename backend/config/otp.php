<?php

return [
    // log (dev) | smsto | orange ... : le fournisseur se change ici sans toucher au reste
    'driver' => env('SMS_DRIVER', 'log'),

    'length' => 6,
    'ttl' => 300,              // validité du code en secondes
    'max_attempts' => 5,       // essais avant invalidation du code
    'resend_cooldown' => 60,   // délai minimum entre deux envois

    // Hash de 11 caractères pour l'auto-remplissage Android (SMS Retriever)
    'android_app_hash' => env('ANDROID_SMS_APP_HASH'),

    'smsto' => [
        'api_key' => env('SMSTO_API_KEY'),
        'sender_id' => env('SMSTO_SENDER_ID', 'MaBoutique'),
    ],
];
