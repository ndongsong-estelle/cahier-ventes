<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\Hash;

class AdminHash extends Command
{
    protected $signature = 'pilote:admin';

    protected $description = "Génère ADMIN_PASSWORD_HASH pour l'accès à /admin";

    public function handle(): int
    {
        $password = $this->secret('Mot de passe du tableau de bord (12 caractères minimum)');
        if (! is_string($password) || strlen($password) < 12) {
            $this->error('12 caractères minimum.');

            return self::FAILURE;
        }
        $this->line('Ajoutez cette ligne dans .env (guillemets simples compris) :');
        $this->line("ADMIN_PASSWORD_HASH='".Hash::make($password)."'");

        return self::SUCCESS;
    }
}
