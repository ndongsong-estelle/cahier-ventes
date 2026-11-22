<?php

namespace App\Sms;

use Illuminate\Support\Facades\Http;

class SmsToSender implements SmsSender
{
    public function send(string $to, string $message): void
    {
        Http::withToken(config('otp.smsto.api_key'))
            ->timeout(10)
            ->post('https://api.sms.to/sms/send', [
                'to' => $to,
                'message' => $message,
                'sender_id' => config('otp.smsto.sender_id'),
            ])
            ->throw();
    }
}
