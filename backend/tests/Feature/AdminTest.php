<?php

use App\Http\Controllers\Admin\AdminController;
use App\Models\Backup;
use App\Models\Device;
use App\Models\User;
use App\Services\BackupStore;
use App\Services\DashboardStats;
use App\Support\WeakPin;
use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

beforeEach(function () {
    Storage::fake('backups');
    config(['pilote.admin_email' => 'estha@example.com', 'pilote.admin_password_hash' => Hash::make('un-long-secret')]);
});

function admin($test)
{
    return $test->withSession(['admin' => true]);
}

/** Événement factice, à l'heure de Douala. */
function fakeEvent(User $u, string $name, string $douala, array $props = []): void
{
    $t = CarbonImmutable::parse($douala, DashboardStats::TZ)->utc();
    DB::table('events')->insert([
        'id' => (string) Str::uuid(), 'user_id' => $u->id, 'name' => $name,
        'props' => $props ? json_encode($props) : null,
        'occurred_at' => $t, 'occurred_at_corrected' => $t, 'received_at' => $t,
    ]);
}

it('protège /admin et accepte seulement le bon mot de passe', function () {
    $this->get('/admin')->assertRedirect('/admin/login');
    $this->post('/admin/login', ['email' => 'estha@example.com', 'password' => 'faux'])->assertSessionHasErrors('email');
    $this->post('/admin/login', ['email' => 'estha@example.com', 'password' => 'un-long-secret'])->assertRedirect('/admin');
    $this->get('/admin')->assertOk()->assertSee('comptes créés');
});

it('limite les essais de connexion à 5 par minute', function () {
    foreach (range(1, 5) as $i) {
        $this->post('/admin/login', ['email' => 'estha@example.com', 'password' => 'faux']);
    }
    $this->post('/admin/login', ['email' => 'estha@example.com', 'password' => 'un-long-secret'])->assertStatus(429);
});

it('calcule les chiffres sur des données factices (jours en heure de Douala)', function () {
    $this->travelTo(CarbonImmutable::parse('2026-11-20 12:00', DashboardStats::TZ));
    $awa = User::factory()->create(['shop_name' => 'Chez Awa', 'created_at' => now()->subDays(9)]);
    $ngo = User::factory()->create(['shop_name' => 'Maman Ngo', 'created_at' => now()->subDays(2)]);
    User::factory()->create(['shop_name' => 'Jamais venue', 'created_at' => now()->subDays(5)]);

    // Awa : ventes sur 3 jours, dont une annulée ; 23 h 30 à Douala reste le même jour.
    fakeEvent($awa, 'sale_saved', '2026-11-12 09:00', ['seconds' => 10]);
    fakeEvent($awa, 'sale_saved', '2026-11-19 23:30', ['seconds' => 30]);
    fakeEvent($awa, 'sale_saved', '2026-11-20 08:00', ['seconds' => 20]);
    fakeEvent($awa, 'sale_saved', '2026-11-20 08:05', ['seconds' => 40]);
    fakeEvent($awa, 'sale_undone', '2026-11-20 08:06');
    fakeEvent($awa, 'reminder_sent', '2026-11-20 09:00');
    fakeEvent($awa, 'receipt_sent', '2026-11-20 09:10');
    fakeEvent($awa, 'receipt_sent', '2026-11-20 09:20');
    // Maman Ngo : ouverte il y a 2 jours seulement, sans vente récente.
    fakeEvent($ngo, 'app_opened', '2026-11-18 10:00');
    Device::create(['id' => (string) Str::uuid(), 'user_id' => $awa->id, 'first_seen_at' => now(), 'last_seen_at' => now()]);
    DB::table('answers')->insert(['id' => (string) Str::uuid(), 'user_id' => $awa->id, 'question_id' => 'aide', 'value' => 'un_peu', 'occurred_at_corrected' => now()]);

    $stats = new DashboardStats;
    expect($stats->summary())->toBe(['accounts' => 3, 'active_today' => 1, 'active_7d' => 2]);

    $rows = collect($stats->rows())->keyBy('shop');
    $a = $rows['Chez Awa'];
    expect($a['days_with_sale'])->toBe(3)
        ->and($a['days_since_creation'])->toBe(10)
        ->and($a['sales_total'])->toBe(3)
        ->and($a['sales_7d'])->toBe(2)
        ->and($a['reminders'])->toBe(1)
        ->and($a['receipts'])->toBe(2)
        ->and($a['median_seconds'])->toBe(25)
        ->and($a['last_aide'])->toBe('un_peu')
        ->and($a['last_seen'])->toBe('20/11 12:00')
        ->and($a['inactive'])->toBeFalse();
    expect($rows['Maman Ngo']['inactive'])->toBeTrue();
    expect($rows['Jamais venue']['sales_total'])->toBe(0);

    $detail = $stats->account($awa);
    expect($detail['sales_by_day'])->toHaveCount(21);
    expect(end($detail['sales_by_day']))->toBe(['day' => '20/11', 'sales' => 1]);
    expect($detail['features']['sale_saved'])->toBe(4);

    admin($this)->get('/admin')->assertOk()->assertSee('Chez Awa')->assertSee('bg-gray-200', false);
    admin($this)->get("/admin/comptes/{$awa->id}")->assertOk()->assertSee('Ventes par jour');
});

it('ne lit jamais le contenu des copies', function () {
    [$user, $token] = account();
    $json = json_encode(['tables' => ['people' => [['name' => 'Cliente secrète']]]]);
    BackupStore::save($user, gzencode($json), hash('sha256', $json), ['people' => 1]);
    // Fichier rendu illisible : le tableau de bord marche quand même et n'affiche rien du contenu.
    Storage::disk('backups')->put(Backup::first()->path, 'abîmé');

    admin($this)->get('/admin')->assertOk()->assertDontSee('Cliente secrète');
    admin($this)->get("/admin/comptes/{$user->id}")->assertOk()->assertSee('people 1')->assertDontSee('Cliente secrète');
    $src = file_get_contents(app_path('Services/DashboardStats.php'));
    expect($src)->not->toContain('BackupStore::read')->not->toContain('Storage::');
});

it('code provisoire : 4 chiffres affichés une fois, à changer, compte débloqué', function () {
    $user = User::factory()->create(['locked_until' => now()->addMinutes(10)]);
    $user->forceFill(['failed_pin_attempts' => 3])->save();

    $res = admin($this)->post("/admin/comptes/{$user->id}/code-provisoire")->assertRedirect();
    $pin = $res->getSession()->get('temporary_pin');
    expect($pin)->toMatch('/^\d{4}$/')->and(WeakPin::isWeak($pin))->toBeFalse();

    $user->refresh();
    expect($user->pin_is_temporary)->toBeTrue()->and($user->locked_until)->toBeNull()->and($user->failed_pin_attempts)->toBe(0);

    $this->postJson('/api/auth/login', ['phone' => $user->phone, 'pin' => $pin, 'device' => device()])
        ->assertOk()->assertJson(['must_change_pin' => true]);
    foreach (range(1, 50) as $i) {
        expect(WeakPin::isWeak(AdminController::newPin()))->toBeFalse();
    }
});

it('suppression depuis l admin : sans reste (lignes et fichiers), numéro à retaper', function () {
    [$user, $token] = account();
    $json = '{"tables":{}}';
    BackupStore::save($user, gzencode($json), hash('sha256', $json), []);
    $now = now()->toIso8601String();
    $this->withToken($token)->postJson('/api/events', ['sent_at' => $now, 'items' => [['id' => (string) Str::uuid(), 'name' => 'app_opened', 'props' => [], 'occurred_at' => $now]]]);
    $this->withToken($token)->postJson('/api/errors', ['sent_at' => $now, 'items' => [['id' => (string) Str::uuid(), 'message' => 'x', 'occurred_at' => $now]]]);

    admin($this)->delete("/admin/comptes/{$user->id}", ['confirm_phone' => '+237600000000'])->assertSessionHasErrors('confirm_phone');
    expect(User::find($user->id))->not->toBeNull();

    admin($this)->delete("/admin/comptes/{$user->id}", ['confirm_phone' => $user->phone])->assertRedirect('/admin');
    foreach (['users' => 'id', 'devices' => 'user_id', 'personal_access_tokens' => 'tokenable_id', 'events' => 'user_id', 'app_errors' => 'user_id', 'backups' => 'user_id'] as $table => $col) {
        expect(DB::table($table)->where($col, $user->id)->count())->toBe(0, $table);
    }
    expect(Storage::disk('backups')->allFiles())->toBe([]);
});

it('notes libres enregistrées', function () {
    $user = User::factory()->create();
    admin($this)->post("/admin/comptes/{$user->id}/notes", ['notes' => 'J+3 : contente'])->assertRedirect();
    expect($user->fresh()->notes)->toBe('J+3 : contente');
});

it('pilote:resume affiche le tableau', function () {
    User::factory()->create(['shop_name' => 'Chez Awa']);
    $this->artisan('pilote:resume')->expectsOutputToContain('Comptes : 1')->assertSuccessful();
});

it('page publique /confidentialite', function () {
    $this->get('/confidentialite')->assertOk()->assertSee('Supprimer mon compte')->assertSee('12 mois')->assertSee('sans', false);
});

it('supprime les comptes inactifs depuis 12 mois, garde les autres', function () {
    $old = User::factory()->create();
    $recent = User::factory()->create();
    Device::create(['id' => (string) Str::uuid(), 'user_id' => $old->id, 'first_seen_at' => now()->subMonths(14), 'last_seen_at' => now()->subMonths(13)]);
    Device::create(['id' => (string) Str::uuid(), 'user_id' => $recent->id, 'first_seen_at' => now()->subMonths(14), 'last_seen_at' => now()->subDays(3)]);

    $this->artisan('pilote:supprimer-inactifs --essai')->expectsOutputToContain('À supprimer : 1');
    expect(User::count())->toBe(2);
    $this->artisan('pilote:supprimer-inactifs')->assertSuccessful();
    expect(User::pluck('id')->all())->toBe([$recent->id]);
});
