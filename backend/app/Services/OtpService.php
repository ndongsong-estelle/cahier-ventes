<?php

namespace App\Services;

use App\Exceptions\OtpException;
use App\Models\OtpCode;
use App\Sms\SmsSender;
use Illuminate\Support\Facades\Hash;

class OtpService
{
    public function __construct(private SmsSender $sms) {}

    public function send(string $phone): void
    {
        $last = OtpCode::where('phone', $phone)->latest()->first();

        if ($last && $last->created_at->gt(now()->subSeconds(config('otp.resend_cooldown')))) {
            throw new OtpException('Patientez une minute avant de demander un nouveau code.', 429);
        }

        // Un seul code actif à la fois par numéro
        OtpCode::where('phone', $phone)->whereNull('consumed_at')->update(['consumed_at' => now()]);

        $length = config('otp.length');
        $code = str_pad((string) random_int(0, 10 ** $length - 1), $length, '0', STR_PAD_LEFT);

        OtpCode::create([
            'phone' => $phone,
            'code_hash' => Hash::make($code),
            'expires_at' => now()->addSeconds(config('otp.ttl')),
        ]);

        $this->sms->send($phone, $this->message($code));
    }

    public function verify(string $phone, string $code): bool
    {
        $otp = OtpCode::where('phone', $phone)
            ->whereNull('consumed_at')
            ->where('expires_at', '>', now())
            ->latest()
            ->first();

        if (! $otp) {
            return false;
        }

        if ($otp->attempts >= config('otp.max_attempts')) {
            $otp->update(['consumed_at' => now()]);

            return false;
        }

        $otp->increment('attempts');

        if (! Hash::check($code, $otp->code_hash)) {
            return false;
        }

        $otp->update(['consumed_at' => now()]);

        return true;
    }

    // Texte sans accents : reste en encodage GSM-7, donc 1 seul SMS facturé
    private function message(string $code): string
    {
        $text = "Votre code de connexion : {$code}. Valable 5 min. Ne le communiquez a personne.";

        if ($hash = config('otp.android_app_hash')) {
            $text .= "\n{$hash}";
        }

        return $text;
    }
}
