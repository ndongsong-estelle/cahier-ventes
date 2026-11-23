<?php

use App\Models\Device;
use App\Models\Question;
use Carbon\CarbonImmutable;
use Database\Seeders\QuestionSeeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

function tracked(string $name, array $props = [], ?string $at = null, ?string $id = null): array
{
    return ['id' => $id ?? (string) Str::uuid(), 'name' => $name, 'props' => $props, 'occurred_at' => $at ?? now()->toIso8601String()];
}

it('la liste blanche du serveur est exactement celle de docs/02', function () {
    $doc = file_get_contents(base_path('../docs/02-technique.md'));
    preg_match('/Liste blanche[^\n]*\n(.*?)amount_bucket :/s', $doc, $m);
    preg_match_all('/([a-z_]+) \{/', $m[1], $names);
    expect(array_keys(config('telemetry.events')))->toEqualCanonicalizing($names[1]);
});

it('enregistre les événements de la liste blanche et ignore les autres un par un', function () {
    [, $token] = account();
    $this->withToken($token)->postJson('/api/events', [
        'sent_at' => now()->toIso8601String(),
        'items' => [
            tracked('app_opened'),
            tracked('sale_saved', ['payment' => 'paid', 'method' => 'cash', 'amount_bucket' => 'lt5k', 'articles_count' => 1, 'used_photo' => true, 'has_person' => false, 'seconds' => 12]),
            tracked('contacts_read'),
            tracked('sale_saved', ['payment' => 'paid', 'customer_name' => 'Awa']),
            tracked('tab_viewed', ['tab' => 'secret']),
        ],
    ])->assertStatus(202)->assertJson(['accepted' => 2, 'duplicates' => 0, 'ignored' => 3]);

    expect(DB::table('events')->pluck('name')->sort()->values()->all())->toBe(['app_opened', 'sale_saved']);
});

it('même lot deux fois = compté une fois', function () {
    [, $token] = account();
    $batch = ['sent_at' => now()->toIso8601String(), 'items' => [tracked('app_opened'), tracked('sale_started')]];
    $this->withToken($token)->postJson('/api/events', $batch)->assertJson(['accepted' => 2]);
    $this->withToken($token)->postJson('/api/events', $batch)->assertJson(['accepted' => 0, 'duplicates' => 2]);
    expect(DB::table('events')->count())->toBe(2);
});

it('horloge du téléphone en avance de 3 jours : heure corrigée', function () {
    $this->freezeTime();
    [, $token] = account();
    $phoneNow = CarbonImmutable::now()->addDays(3);
    $this->withToken($token)->postJson('/api/events', [
        'sent_at' => $phoneNow->toIso8601String(),
        'items' => [tracked('app_opened', [], $phoneNow->subHour()->toIso8601String())],
    ])->assertStatus(202);

    $row = DB::table('events')->first();
    expect(CarbonImmutable::parse($row->occurred_at_corrected)->getTimestamp())
        ->toBe(CarbonImmutable::now()->subHour()->getTimestamp());
    expect(Device::first()->clock_offset_seconds)->toBe(-3 * 86400);
});

it('refuse plus de 200 éléments', function () {
    [, $token] = account();
    $items = array_map(fn () => tracked('app_opened'), range(1, 201));
    $this->withToken($token)->postJson('/api/events', ['sent_at' => now()->toIso8601String(), 'items' => $items])
        ->assertStatus(422);
});

it('réponses et erreurs : même format, même dédoublonnage, pile tronquée à 4 Ko', function () {
    [, $token] = account();
    $answer = ['id' => (string) Str::uuid(), 'question_id' => 'aide', 'value' => 'oui', 'text' => null, 'occurred_at' => now()->toIso8601String()];
    $batch = ['sent_at' => now()->toIso8601String(), 'items' => [$answer]];
    $this->withToken($token)->postJson('/api/answers', $batch)->assertJson(['accepted' => 1]);
    $this->withToken($token)->postJson('/api/answers', $batch)->assertJson(['duplicates' => 1]);

    $error = ['id' => (string) Str::uuid(), 'message' => 'Boum', 'stack' => str_repeat('x', 10000), 'app_version' => '1.0.0', 'occurred_at' => now()->toIso8601String()];
    $this->withToken($token)->postJson('/api/errors', ['sent_at' => now()->toIso8601String(), 'items' => [$error]])
        ->assertJson(['accepted' => 1]);
    expect(strlen(DB::table('app_errors')->first()->stack))->toBe(4096);
});

it('GET /config renvoie les questions actives', function () {
    $this->seed(QuestionSeeder::class);
    Question::create(['id' => 'vieille', 'text' => 'x', 'kind' => 'text', 'after_days' => 1, 'active' => false]);
    [, $token] = account();
    $res = $this->withToken($token)->getJson('/api/config')->assertOk();
    expect(collect($res->json('questions'))->pluck('id')->all())->toBe(['aide', 'manque']);
    expect($res->json('questions.0.choices.0.label'))->toBe('😀 Oui');
});

it('la suppression du compte efface événements, réponses et erreurs', function () {
    [$user, $token] = account();
    $now = now()->toIso8601String();
    $this->withToken($token)->postJson('/api/events', ['sent_at' => $now, 'items' => [tracked('app_opened')]]);
    $this->withToken($token)->postJson('/api/answers', ['sent_at' => $now, 'items' => [['id' => (string) Str::uuid(), 'question_id' => 'aide', 'value' => 'oui', 'occurred_at' => $now]]]);
    $this->withToken($token)->postJson('/api/errors', ['sent_at' => $now, 'items' => [['id' => (string) Str::uuid(), 'message' => 'x', 'occurred_at' => $now]]]);
    $this->withToken($token)->deleteJson('/api/me', ['pin' => '4826'])->assertOk();
    foreach (['events', 'answers', 'app_errors'] as $t) {
        expect(DB::table($t)->where('user_id', $user->id)->count())->toBe(0);
    }
});
