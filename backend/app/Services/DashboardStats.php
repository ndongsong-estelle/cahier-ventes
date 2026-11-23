<?php

namespace App\Services;

use App\Models\Backup;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

/**
 * Chiffres du tableau de bord. Sources : events, answers, app_errors, devices et les métadonnées
 * de backups (date, taille, compteurs). Le contenu des copies n'est jamais lu.
 * Jours calculés en Africa/Douala sur occurred_at_corrected.
 */
class DashboardStats
{
    public const TZ = 'Africa/Douala';

    public function __construct(private ?CarbonImmutable $now = null)
    {
        $this->now ??= CarbonImmutable::now();
    }

    private function day(string|\DateTimeInterface $t): string
    {
        return CarbonImmutable::parse($t)->setTimezone(self::TZ)->format('Y-m-d');
    }

    private function today(): string
    {
        return $this->day($this->now);
    }

    /** Événements d'un ou plusieurs comptes, groupés par compte. */
    private function events(?array $userIds = null): Collection
    {
        return DB::table('events')
            ->when($userIds !== null, fn ($q) => $q->whereIn('user_id', $userIds))
            ->get(['user_id', 'name', 'props', 'occurred_at_corrected'])
            ->groupBy('user_id');
    }

    /** Trois chiffres : comptes créés, actifs aujourd'hui, actifs 7 jours. */
    public function summary(): array
    {
        $today = $this->today();
        $since = $this->now->setTimezone(self::TZ)->startOfDay()->subDays(6)->utc();
        $activeToday = $active7 = 0;
        foreach ($this->events() as $events) {
            $days = $events->map(fn ($e) => $e->occurred_at_corrected);
            if ($days->contains(fn ($t) => $this->day($t) === $today)) {
                $activeToday++;
            }
            if ($days->contains(fn ($t) => CarbonImmutable::parse($t)->gte($since))) {
                $active7++;
            }
        }

        return ['accounts' => User::count(), 'active_today' => $activeToday, 'active_7d' => $active7];
    }

    /** Une ligne par compte. */
    public function rows(): array
    {
        $users = User::orderBy('created_at')->get();
        $events = $this->events($users->pluck('id')->all());
        $lastSeen = DB::table('devices')->groupBy('user_id')->selectRaw('user_id, MAX(last_seen_at) AS seen')->pluck('seen', 'user_id');
        $lastBackup = Backup::groupBy('user_id')->selectRaw('user_id, MAX(created_at) AS at')->pluck('at', 'user_id');
        $lastAide = DB::table('answers')->where('question_id', 'aide')->orderBy('occurred_at_corrected')->get()->keyBy('user_id');

        return $users->map(fn (User $u) => $this->row($u, $events->get($u->id, collect()), $lastSeen[$u->id] ?? null, $lastBackup[$u->id] ?? null, $lastAide[$u->id]->value ?? null))->all();
    }

    private function row(User $u, Collection $events, $seen, $backup, $aide): array
    {
        $created = CarbonImmutable::parse($u->created_at);
        $sinceCreation = $created->setTimezone(self::TZ)->startOfDay()->diffInDays($this->now->setTimezone(self::TZ)->startOfDay()) + 1;
        $saleDays = $this->salesByDay($events);
        $since7 = $this->now->setTimezone(self::TZ)->startOfDay()->subDays(6)->format('Y-m-d');
        $sales7 = collect($saleDays)->filter(fn ($n, $d) => $d >= $since7)->sum();
        $lastSaleDay = collect($saleDays)->filter(fn ($n) => $n > 0)->keys()->max();
        $threeDaysAgo = $this->now->setTimezone(self::TZ)->startOfDay()->subDays(2)->format('Y-m-d');

        return [
            'id' => $u->id,
            'shop' => $u->shop_name,
            'phone' => $u->phone,
            'created' => $created->setTimezone(self::TZ)->format('d/m'),
            'pilot_day' => (int) $sinceCreation,
            'last_seen' => $seen ? CarbonImmutable::parse($seen)->setTimezone(self::TZ)->format('d/m H:i') : null,
            'days_with_sale' => count(array_filter($saleDays)),
            'days_since_creation' => (int) $sinceCreation,
            'sales_7d' => $sales7,
            'sales_total' => array_sum($saleDays),
            'reminders' => $events->where('name', 'reminder_sent')->count(),
            'receipts' => $events->where('name', 'receipt_sent')->count(),
            'median_seconds' => $this->medianSeconds($events),
            'last_backup' => $backup ? CarbonImmutable::parse($backup)->setTimezone(self::TZ)->format('d/m H:i') : null,
            'last_aide' => $aide,
            'inactive' => $lastSaleDay === null || $lastSaleDay < $threeDaysAgo,
        ];
    }

    /** Ventes par jour = sale_saved − sale_undone (jour Douala). */
    public function salesByDay(Collection $events): array
    {
        $days = [];
        foreach ($events as $e) {
            $delta = match ($e->name) {
                'sale_saved' => 1,
                'sale_undone' => -1,
                default => 0,
            };
            if ($delta !== 0) {
                $d = $this->day($e->occurred_at_corrected);
                $days[$d] = max(0, ($days[$d] ?? 0) + $delta);
            }
        }
        ksort($days);

        return $days;
    }

    public function medianSeconds(Collection $events): ?int
    {
        $values = $events->where('name', 'sale_saved')
            ->map(fn ($e) => json_decode($e->props ?? '{}', true)['seconds'] ?? null)
            ->filter(fn ($v) => is_int($v))->sort()->values();
        if ($values->isEmpty()) {
            return null;
        }
        $n = $values->count();

        return (int) ($n % 2 ? $values[intdiv($n, 2)] : round(($values[$n / 2 - 1] + $values[$n / 2]) / 2));
    }

    /** Fiche compte. */
    public function account(User $u): array
    {
        $events = $this->events([$u->id])->get($u->id, collect());
        $byDay = $this->salesByDay($events);
        $table = [];
        for ($i = 20; $i >= 0; $i--) {
            $d = $this->now->setTimezone(self::TZ)->startOfDay()->subDays($i);
            $table[] = ['day' => $d->format('d/m'), 'sales' => $byDay[$d->format('Y-m-d')] ?? 0];
        }

        return [
            'sales_by_day' => $table,
            'features' => $events->countBy('name')->sortDesc()->all(),
            'answers' => DB::table('answers')->where('user_id', $u->id)->orderByDesc('occurred_at_corrected')->get(),
            'errors' => DB::table('app_errors')->where('user_id', $u->id)->orderByDesc('occurred_at_corrected')->limit(10)->get(),
            'backups' => Backup::where('user_id', $u->id)->orderByDesc('created_at')
                ->get(['id', 'created_at', 'size_bytes', 'counts', 'encrypted']),
        ];
    }
}
