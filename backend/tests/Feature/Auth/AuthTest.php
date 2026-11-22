<?php

use App\Models\Device;
use App\Models\User;
use App\Sms\SmsSender;
use App\Support\OtpTicket;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\PersonalAccessToken;

function registerPayload(array $over = []): array
{
    return array_merge([
        'phone' => '6 90 12 34 56',
        'shop_name' => 'Chez Maman Brigitte',
        'pin' => '4826',
        'device' => device(),
    ], $over);
}

it('crée un compte avec un numéro normalisé', function () {
    $res = $this->postJson('/api/auth/register', registerPayload())
        ->assertCreated()
        ->assertJsonStructure(['token', 'user' => ['id', 'phone', 'shop_name'], 'server_time']);

    expect($res->json('user.phone'))->toBe('+237690123456')
        ->and($res->json('user'))->not->toHaveKey('pin_hash');
    expect(Device::count())->toBe(1);
    $this->withToken($res->json('token'))->getJson('/api/me')->assertOk()
        ->assertJsonPath('user.shop_name', 'Chez Maman Brigitte');
});

it('refuse un code faible et un numéro déjà pris', function () {
    $this->postJson('/api/auth/register', registerPayload(['pin' => '1234']))
        ->assertStatus(422)->assertJsonPath('code', 'weak_pin');
    $this->postJson('/api/auth/register', registerPayload())->assertCreated();
    $this->postJson('/api/auth/register', registerPayload(['device' => device()]))
        ->assertStatus(409)->assertJsonPath('code', 'phone_taken');
});

it('dit si le numéro existe et si le SMS est exigé', function () {
    $this->postJson('/api/auth/check', ['phone' => '690123456'])
        ->assertOk()->assertJson(['exists' => false, 'otp_required' => false]);
    $this->postJson('/api/auth/register', registerPayload());
    $this->postJson('/api/auth/check', ['phone' => '+237 690 12 34 56'])
        ->assertJson(['exists' => true]);
    $this->postJson('/api/auth/check', ['phone' => '12345'])->assertStatus(422);
});

it('se connecte et révoque le token de l’ancien téléphone', function () {
    $first = $this->postJson('/api/auth/register', registerPayload())->json('token');

    $res = $this->postJson('/api/auth/login', ['phone' => '690123456', 'pin' => '4826', 'device' => device()])
        ->assertOk()->assertJson(['must_change_pin' => false]);

    expect(PersonalAccessToken::count())->toBe(1);
    $this->app['auth']->forgetGuards();
    $this->withToken($first)->getJson('/api/me')->assertUnauthorized();
    $this->app['auth']->forgetGuards();
    $this->withToken($res->json('token'))->getJson('/api/me')->assertOk();
});

it('verrouille 15 minutes après 5 mauvais codes', function () {
    $this->postJson('/api/auth/register', registerPayload());
    $bad = ['phone' => '690123456', 'pin' => '9999', 'device' => device()];

    foreach (range(1, 4) as $i) {
        $this->postJson('/api/auth/login', $bad)->assertStatus(401)->assertJsonPath('attempts_left', 5 - $i);
    }
    $this->postJson('/api/auth/login', $bad)->assertStatus(423)->assertJsonPath('code', 'locked');
    // Même le bon code est refusé pendant le verrouillage
    $this->postJson('/api/auth/login', ['pin' => '4826'] + $bad)->assertStatus(423);

    $this->travel(16)->minutes();
    $this->postJson('/api/auth/login', ['pin' => '4826'] + $bad)->assertOk();
});

it("n'exige le SMS que si OTP_ENABLED", function () {
    config(['pilote.otp_enabled' => true]);
    $this->postJson('/api/auth/check', ['phone' => '690123456'])->assertJson(['otp_required' => true]);
    $this->postJson('/api/auth/register', registerPayload())
        ->assertStatus(422)->assertJsonPath('code', 'otp_required');
    $this->postJson('/api/auth/register', registerPayload(['otp_ticket' => OtpTicket::issue('+237699999999')]))
        ->assertStatus(422);
    $this->postJson('/api/auth/register', registerPayload(['otp_ticket' => OtpTicket::issue('+237690123456')]))
        ->assertCreated();
    expect(User::first()->phone_verified_at)->not->toBeNull();
});

it('envoie et vérifie un code SMS (driver log) puis remet un code secret', function () {
    config(['pilote.otp_enabled' => true]);
    $this->postJson('/api/auth/register', registerPayload(['otp_ticket' => OtpTicket::issue('+237690123456')]));

    $sent = null;
    $this->mock(SmsSender::class, function ($mock) use (&$sent) {
        $mock->shouldReceive('send')->once()->andReturnUsing(function ($to, $msg) use (&$sent) {
            preg_match('/(\d{6})/', $msg, $m);
            $sent = $m[1];
        });
    });
    $this->postJson('/api/auth/otp/send', ['phone' => '690123456'])->assertOk();
    $ticket = $this->postJson('/api/auth/otp/verify', ['phone' => '690123456', 'code' => $sent])
        ->assertOk()->json('otp_ticket');

    $this->postJson('/api/auth/pin/reset', [
        'phone' => '690123456', 'otp_ticket' => $ticket, 'new_pin' => '7391', 'device' => device(),
    ])->assertOk();
    $this->postJson('/api/auth/login', ['phone' => '690123456', 'pin' => '7391', 'device' => device()])->assertOk();
});

it('refuse le SMS et la remise du code quand OTP est désactivé', function () {
    $this->postJson('/api/auth/otp/send', ['phone' => '690123456'])->assertNotFound();
    $this->postJson('/api/auth/pin/reset', [
        'phone' => '690123456', 'otp_ticket' => 'x', 'new_pin' => '7391', 'device' => device(),
    ])->assertForbidden();
});

it('change le code secret et le nom de la boutique', function () {
    [$user, $token] = account();
    $this->withToken($token)->postJson('/api/auth/pin', ['current_pin' => '4826', 'new_pin' => '1111'])
        ->assertStatus(422);
    $this->withToken($token)->postJson('/api/auth/pin', ['current_pin' => '0000', 'new_pin' => '7391'])
        ->assertStatus(401);
    $this->withToken($token)->postJson('/api/auth/pin', ['current_pin' => '4826', 'new_pin' => '7391'])
        ->assertOk();
    $this->withToken($token)->patchJson('/api/me', ['shop_name' => 'Nouvelle boutique'])
        ->assertJsonPath('user.shop_name', 'Nouvelle boutique');
});

it('se déconnecte', function () {
    [, $token] = account();
    $this->withToken($token)->postJson('/api/auth/logout')->assertOk();
    $this->app['auth']->forgetGuards();
    $this->withToken($token)->getJson('/api/me')->assertUnauthorized();
});

it('supprime complètement le compte', function () {
    Storage::fake('local');
    [$user, $token] = account();
    Storage::disk('local')->put("backups/{$user->id}/x.json", '{}');

    $this->withToken($token)->deleteJson('/api/me', ['pin' => '0000'])->assertStatus(401);
    $this->withToken($token)->deleteJson('/api/me', ['pin' => '4826'])->assertOk()->assertJson(['deleted' => true]);

    expect(User::count())->toBe(0)
        ->and(Device::count())->toBe(0)
        ->and(PersonalAccessToken::count())->toBe(0);
    Storage::disk('local')->assertMissing("backups/{$user->id}");
});

it('met à jour last_seen_at du téléphone', function () {
    [$user, $token] = account();
    $this->travel(10)->minutes();
    $this->withToken($token)->getJson('/api/me')->assertOk();
    expect($user->devices()->first()->last_seen_at->diffInSeconds(now()))->toBeLessThan(5);
});
