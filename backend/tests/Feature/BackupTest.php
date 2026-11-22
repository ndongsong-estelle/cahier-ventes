<?php

use App\Models\Backup;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;

beforeEach(fn () => Storage::fake('backups'));

function cahierJson(int $n = 1): string
{
    return json_encode(['format_version' => 1, 'shop_name' => 'Chez Awa', 'tables' => ['sales' => array_fill(0, $n, ['amount' => 1000])]]);
}

function upload($test, string $token, string $json, ?string $sha = null)
{
    return $test->withToken($token)->post('/api/backups', [
        'file' => UploadedFile::fake()->createWithContent('cahier.json.gz', gzencode($json)),
        'sha256' => $sha ?? hash('sha256', $json),
        'counts' => json_encode(['sales' => 1]),
    ], ['Accept' => 'application/json']);
}

it('reçoit une copie et la rend identique', function () {
    [$user, $token] = account();
    $json = cahierJson();
    $id = upload($this, $token, $json)->assertCreated()->json('backup.id');

    $backup = Backup::find($id);
    expect($backup->path)->toBe("{$user->id}/{$id}.json.gz")
        ->and($backup->encrypted)->toBeFalse()
        ->and($backup->counts)->toBe(['sales' => 1]);
    Storage::disk('backups')->assertExists($backup->path);

    $latest = $this->withToken($token)->getJson('/api/backups/latest')->assertOk()
        ->assertJsonPath('id', $id)->assertJsonPath('sha256', hash('sha256', $json));
    expect($latest->json('download_url'))->toEndWith("/api/backups/{$id}/file");

    $file = $this->withToken($token)->get("/api/backups/{$id}/file")->assertOk();
    expect(gzdecode($file->getContent()))->toBe($json);
});

it('copies chiffrées et non chiffrées restaurables', function () {
    [, $token] = account();
    $plain = cahierJson(1);
    $plainId = upload($this, $token, $plain)->json('backup.id');

    config(['pilote.backup.encrypt_at_rest' => true]);
    $secret = cahierJson(2);
    $secretId = upload($this, $token, $secret)->assertCreated()->json('backup.id');

    $stored = Storage::disk('backups')->get(Backup::find($secretId)->path);
    expect(Backup::find($secretId)->encrypted)->toBeTrue()
        ->and(@gzdecode($stored))->toBeFalse();

    expect(gzdecode($this->withToken($token)->get("/api/backups/{$secretId}/file")->getContent()))->toBe($secret);
    expect(gzdecode($this->withToken($token)->get("/api/backups/{$plainId}/file")->getContent()))->toBe($plain);
});

it('la commande chiffre les copies existantes', function () {
    [, $token] = account();
    $json = cahierJson();
    $id = upload($this, $token, $json)->json('backup.id');

    $this->artisan('pilote:chiffrer-copies')->assertSuccessful();

    expect(Backup::find($id)->encrypted)->toBeTrue();
    expect(gzdecode($this->withToken($token)->get("/api/backups/{$id}/file")->getContent()))->toBe($json);
});

it('BACKUP_ENABLED=false refuse les copies (403)', function () {
    config(['pilote.backup.enabled' => false]);
    [, $token] = account();
    upload($this, $token, cahierJson())->assertForbidden();
    expect(Backup::count())->toBe(0);
    $this->withToken($token)->getJson('/api/config')->assertJson(['backup_enabled' => false]);
});

it('refuse une copie trop grosse (413) ou un sha256 faux (422)', function () {
    config(['pilote.backup.max_size_kb' => 1]);
    [, $token] = account();
    $big = json_encode(['x' => bin2hex(random_bytes(4000))]);
    upload($this, $token, $big)->assertStatus(413);

    config(['pilote.backup.max_size_kb' => 5120]);
    upload($this, $token, cahierJson(), str_repeat('a', 64))->assertStatus(422)->assertJsonPath('code', 'bad_sha256');
});

it('garde les BACKUP_KEEP plus récentes et supprime les fichiers des autres', function () {
    config(['pilote.backup.keep' => 2]);
    [$user, $token] = account();
    $ids = [];
    foreach (range(1, 4) as $i) {
        $ids[] = upload($this, $token, cahierJson($i))->json('backup.id');
        $this->travel(1)->minutes();
    }
    expect(Backup::pluck('id')->sort()->values()->all())->toBe(collect([$ids[2], $ids[3]])->sort()->values()->all());
    expect(Storage::disk('backups')->files("{$user->id}"))->toHaveCount(2);
});

it('404 sans copie, et une copie d un autre compte est introuvable', function () {
    [, $token] = account();
    $this->withToken($token)->getJson('/api/backups/latest')->assertNotFound();
    $otherId = upload($this, $token, cahierJson())->json('backup.id');

    [, $other] = account();
    $this->app['auth']->forgetGuards();
    $this->withToken($other)->get("/api/backups/{$otherId}/file", ['Accept' => 'application/json'])->assertNotFound();
});

it('la suppression du compte efface les copies et leurs fichiers', function () {
    [$user, $token] = account();
    upload($this, $token, cahierJson());
    $this->withToken($token)->deleteJson('/api/me', ['pin' => '4826'])->assertOk();
    expect(Backup::count())->toBe(0);
    Storage::disk('backups')->assertMissing("{$user->id}");
});

it('GET /config renvoie les réglages de la copie', function () {
    config(['pilote.support_whatsapp' => '+237699000000']);
    [, $token] = account();
    $this->withToken($token)->getJson('/api/config')->assertOk()->assertJson([
        'backup_enabled' => true,
        'backup_min_interval_minutes' => 360,
        'support_whatsapp' => '+237699000000',
    ])->assertJsonStructure(['questions', 'server_time']);
});
