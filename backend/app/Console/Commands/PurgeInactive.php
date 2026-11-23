<?php

namespace App\Console\Commands;

use App\Models\User;
use App\Services\AccountDeleter;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

/** Comptes sans aucune utilisation depuis 12 mois : supprimés avec toutes leurs données (page /confidentialite). */
class PurgeInactive extends Command
{
    protected $signature = 'pilote:supprimer-inactifs {--mois=12} {--essai : affiche sans supprimer}';

    protected $description = 'Supprime les comptes inactifs depuis 12 mois, avec leurs copies';

    public function handle(): int
    {
        $limit = now()->subMonths((int) $this->option('mois'));
        $seen = DB::table('devices')->groupBy('user_id')->selectRaw('user_id, MAX(last_seen_at) AS seen')->pluck('seen', 'user_id');
        $count = 0;
        User::query()->each(function (User $user) use ($seen, $limit, &$count) {
            $last = $seen[$user->id] ?? $user->updated_at;
            if ($last === null || now()->parse($last)->gte($limit)) {
                return;
            }
            $count++;
            if (! $this->option('essai')) {
                AccountDeleter::delete($user);
            }
        });
        $this->info(($this->option('essai') ? 'À supprimer : ' : 'Supprimés : ').$count);

        return self::SUCCESS;
    }
}
