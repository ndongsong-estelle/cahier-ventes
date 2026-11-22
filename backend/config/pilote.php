<?php

return [
    'otp_enabled' => (bool) env('OTP_ENABLED', false),
    'otp_ticket_ttl' => 600,

    'pin_max_attempts' => 5,
    'pin_lock_minutes' => 15,

    'backup' => [
        'enabled' => (bool) env('BACKUP_ENABLED', true),
        'min_interval_minutes' => (int) env('BACKUP_MIN_INTERVAL_MINUTES', 360),
        'keep' => (int) env('BACKUP_KEEP', 7),
        'max_size_kb' => (int) env('BACKUP_MAX_SIZE_KB', 5120),
        'encrypt_at_rest' => (bool) env('BACKUP_ENCRYPT_AT_REST', false),
    ],

    'admin_email' => env('ADMIN_EMAIL'),
    'admin_password_hash' => env('ADMIN_PASSWORD_HASH'),
    'support_whatsapp' => env('SUPPORT_WHATSAPP'),
];
