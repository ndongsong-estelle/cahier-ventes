<?php

namespace App\Console\Commands;

use App\Services\DashboardStats;
use Illuminate\Console\Command;

class PiloteResume extends Command
{
    protected $signature = 'pilote:resume';

    protected $description = 'Affiche le tableau principal du pilote dans le terminal';

    public function handle(): int
    {
        $stats = new DashboardStats;
        $s = $stats->summary();
        $this->line("Comptes : {$s['accounts']} · actifs aujourd'hui : {$s['active_today']} · actifs 7 jours : {$s['active_7d']}");
        $this->table(
            ['Boutique', 'Numéro', 'Créé', 'Dernier passage', 'Jours vente', 'Ventes 7 j', 'Total', 'Relances', 'Reçus', 'Médiane', 'Copie', 'Aide ?'],
            array_map(fn ($r) => [
                ($r['inactive'] ? '· ' : '').$r['shop'], $r['phone'], $r['created'], $r['last_seen'] ?? '—',
                "{$r['days_with_sale']}/{$r['days_since_creation']}", $r['sales_7d'], $r['sales_total'],
                $r['reminders'], $r['receipts'], $r['median_seconds'] !== null ? "{$r['median_seconds']} s" : '—',
                $r['last_backup'] ?? '—', $r['last_aide'] ?? '—',
            ], $stats->rows()),
        );

        return self::SUCCESS;
    }
}
