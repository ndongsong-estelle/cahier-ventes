<?php

namespace App\Support;

class PhoneNumber
{
    /**
     * Normalise un numéro mobile camerounais en +2376XXXXXXXX.
     * Accepte "6 90 00 00 00", "690000000", "+237690000000", "00237690000000".
     * Retourne null si ce n'est pas un mobile camerounais valide.
     */
    public static function normalizeCameroon(string $raw): ?string
    {
        $digits = preg_replace('/\D+/', '', $raw);

        if (str_starts_with($digits, '00')) {
            $digits = substr($digits, 2);
        }
        if (strlen($digits) === 9) {
            $digits = '237' . $digits;
        }

        return preg_match('/^2376\d{8}$/', $digits) ? '+' . $digits : null;
    }
}
