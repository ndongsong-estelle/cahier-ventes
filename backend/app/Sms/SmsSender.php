<?php

namespace App\Sms;

interface SmsSender
{
    /** @param string $to Numéro au format E.164 (+2376XXXXXXXX) */
    public function send(string $to, string $message): void;
}
