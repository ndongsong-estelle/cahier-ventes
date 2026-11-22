<?php

namespace App\Console\Commands;

use App\Models\Backup;
use App\Services\BackupStore;
use Illuminate\Console\Command;

class EncryptBackups extends Command
{
    protected $signature = 'pilote:chiffrer-copies';

    protected $description = 'Chiffre les copies de cahier encore en clair (Crypt / APP_KEY)';

    public function handle(): int
    {
        $count = 0;
        Backup::where('encrypted', false)->chunkById(100, function ($backups) use (&$count) {
            foreach ($backups as $backup) {
                BackupStore::encrypt($backup);
                $count++;
            }
        });
        $this->info("{$count} copie(s) chiffrée(s).");

        return self::SUCCESS;
    }
}
