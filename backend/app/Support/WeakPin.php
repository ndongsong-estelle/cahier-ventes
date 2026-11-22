<?php

namespace App\Support;

/**
 * Codes secrets trop faciles à deviner. Même règle dans l'app (mobile/lib/core/auth/weak_pin.dart).
 * Refusés : pas 4 chiffres, 4 chiffres identiques (1111), suite qui monte ou descend (1234, 4321),
 * deux chiffres répétés (1212), ou un code de la liste ci-dessous.
 */
class WeakPin
{
    public const LIST = ['1122', '2580', '0852', '1004', '2000', '2001', '1010', '6969'];

    public static function isWeak(string $pin): bool
    {
        if (! preg_match('/^\d{4}$/', $pin)) {
            return true;
        }
        $d = array_map('intval', str_split($pin));
        if (count(array_unique($d)) === 1) {
            return true;
        }
        $up = $down = true;
        for ($i = 1; $i < 4; $i++) {
            $up = $up && $d[$i] === $d[$i - 1] + 1;
            $down = $down && $d[$i] === $d[$i - 1] - 1;
        }
        if ($up || $down) {
            return true;
        }
        if ($d[0] === $d[2] && $d[1] === $d[3]) {
            return true;
        }

        return in_array($pin, self::LIST, true);
    }
}
