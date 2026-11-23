<?php

namespace App\Support;

/** Vérifie un événement contre la liste blanche (config/telemetry.php). */
class Whitelist
{
    public static function allows(string $name, mixed $props): bool
    {
        $rules = config("telemetry.events.{$name}");
        if (! is_array($rules)) {
            return false;
        }
        if ($props === null || $props === []) {
            return true;
        }
        if (! is_array($props) || array_is_list($props)) {
            return false;
        }
        foreach ($props as $key => $value) {
            if (! array_key_exists($key, $rules)) {
                return false;
            }
            $rule = $rules[$key];
            $ok = match (true) {
                is_array($rule) => is_string($value) && in_array($value, $rule, true),
                $rule === 'int' => is_int($value) && $value >= 0 && $value <= 1_000_000,
                $rule === 'bool' => is_bool($value),
                $rule === 'string' => is_string($value) && strlen($value) <= 40,
                default => false,
            };
            if (! $ok) {
                return false;
            }
        }

        return true;
    }
}
