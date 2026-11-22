<?php

namespace App\Support;

use Illuminate\Support\Facades\Crypt;
use Throwable;

/** Preuve signée (chiffrée avec APP_KEY) que le numéro a été vérifié par SMS, valable 10 min. */
class OtpTicket
{
    public static function issue(string $phone): string
    {
        return Crypt::encryptString(json_encode([
            'phone' => $phone,
            'exp' => now()->addSeconds(config('pilote.otp_ticket_ttl'))->getTimestamp(),
        ]));
    }

    public static function isValidFor(?string $ticket, string $phone): bool
    {
        if (! $ticket) {
            return false;
        }
        try {
            $data = json_decode(Crypt::decryptString($ticket), true);
        } catch (Throwable) {
            return false;
        }

        return is_array($data)
            && ($data['phone'] ?? null) === $phone
            && ($data['exp'] ?? 0) >= now()->getTimestamp();
    }
}
