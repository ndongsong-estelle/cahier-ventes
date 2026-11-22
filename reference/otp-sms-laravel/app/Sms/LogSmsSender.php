<?php

namespace App\Sms;

use Illuminate\Support\Facades\Log;

// Pour le développement : le code apparaît dans storage/logs/laravel.log
class LogSmsSender implements SmsSender
{
    public function send(string $to, string $message): void
    {
        Log::info("[SMS] {$to} : {$message}");
    }
}
