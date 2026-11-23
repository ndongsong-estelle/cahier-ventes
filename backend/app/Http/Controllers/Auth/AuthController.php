<?php

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Services\DeviceRegistrar;
use App\Support\ApiError;
use App\Support\OtpTicket;
use App\Support\PhoneNumber;
use App\Support\WeakPin;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

class AuthController extends Controller
{
    public function check(Request $request): JsonResponse
    {
        $phone = $this->phone($request);
        if (! $phone) {
            return $this->invalidPhone();
        }

        return response()->json([
            'exists' => User::where('phone', $phone)->exists(),
            'otp_required' => (bool) config('pilote.otp_enabled'),
        ]);
    }

    public function register(Request $request): JsonResponse
    {
        $data = $request->validate([
            'phone' => 'required|string|max:20',
            'shop_name' => 'required|string|min:2|max:60',
            'pin' => 'required|string',
            'otp_ticket' => 'nullable|string',
        ] + DeviceRegistrar::rules());

        $phone = PhoneNumber::normalizeCameroon($data['phone']);
        if (! $phone) {
            return $this->invalidPhone();
        }
        if (WeakPin::isWeak($data['pin'])) {
            return $this->weakPin();
        }
        $otp = (bool) config('pilote.otp_enabled');
        if ($otp && ! OtpTicket::isValidFor($data['otp_ticket'] ?? null, $phone)) {
            return ApiError::make('otp_required', 'Le code reçu par SMS est nécessaire.', 422);
        }
        if (User::where('phone', $phone)->exists()) {
            return ApiError::make('phone_taken', 'Ce numéro a déjà un compte. Connectez-vous.', 409);
        }

        $user = User::create([
            'phone' => $phone,
            'shop_name' => trim($data['shop_name']),
            'pin_hash' => Hash::make($data['pin']),
            'phone_verified_at' => $otp ? now() : null,
        ]);
        $token = DeviceRegistrar::login($user, $data['device']);

        return response()->json(['token' => $token, 'user' => $user->toApi()], 201);
    }

    public function login(Request $request): JsonResponse
    {
        $data = $request->validate([
            'phone' => 'required|string|max:20',
            'pin' => 'required|string|max:10',
        ] + DeviceRegistrar::rules());

        $phone = PhoneNumber::normalizeCameroon($data['phone']);
        $user = $phone ? User::where('phone', $phone)->first() : null;
        if (! $user) {
            return ApiError::make('unknown_phone', "Ce numéro n'a pas encore de compte.", 404);
        }

        $check = self::checkPin($user, $data['pin']);
        if ($check) {
            return $check;
        }

        $token = DeviceRegistrar::login($user, $data['device']);

        return response()->json([
            'token' => $token,
            'user' => $user->toApi(),
            'must_change_pin' => $user->pin_is_temporary,
        ]);
    }

    public function resetPin(Request $request): JsonResponse
    {
        if (! config('pilote.otp_enabled')) {
            return ApiError::make('otp_disabled', "Contactez l'aide sur WhatsApp pour recevoir un code provisoire.", 403);
        }
        $data = $request->validate([
            'phone' => 'required|string|max:20',
            'otp_ticket' => 'required|string',
            'new_pin' => 'required|string',
        ] + DeviceRegistrar::rules());

        $phone = PhoneNumber::normalizeCameroon($data['phone']);
        $user = $phone ? User::where('phone', $phone)->first() : null;
        if (! $user || ! OtpTicket::isValidFor($data['otp_ticket'], $phone)) {
            return ApiError::make('otp_required', 'Le code reçu par SMS est nécessaire.', 422);
        }
        if (WeakPin::isWeak($data['new_pin'])) {
            return $this->weakPin();
        }

        $user->forceFill([
            'pin_hash' => Hash::make($data['new_pin']),
            'pin_is_temporary' => false,
            'failed_pin_attempts' => 0,
            'locked_until' => null,
            'phone_verified_at' => $user->phone_verified_at ?? now(),
        ])->save();
        $token = DeviceRegistrar::login($user, $data['device']);

        return response()->json(['token' => $token, 'user' => $user->toApi()]);
    }

    public function logout(Request $request): JsonResponse
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json(['ok' => true]);
    }

    public function changePin(Request $request): JsonResponse
    {
        $data = $request->validate([
            'current_pin' => 'required|string|max:10',
            'new_pin' => 'required|string',
        ]);
        $user = $request->user();

        $check = self::checkPin($user, $data['current_pin']);
        if ($check) {
            return $check;
        }
        if (WeakPin::isWeak($data['new_pin'])) {
            return $this->weakPin();
        }

        $user->forceFill(['pin_hash' => Hash::make($data['new_pin']), 'pin_is_temporary' => false])->save();

        return response()->json(['user' => $user->toApi()]);
    }

    /**
     * Vérifie le code secret. Null si bon. 5 erreurs : verrouillé 15 minutes (423).
     */
    public static function checkPin(User $user, string $pin): ?JsonResponse
    {
        if ($user->isLocked()) {
            return self::locked($user);
        }
        if (Hash::check($pin, $user->pin_hash)) {
            if ($user->failed_pin_attempts > 0) {
                $user->forceFill(['failed_pin_attempts' => 0, 'locked_until' => null])->save();
            }

            return null;
        }

        $attempts = $user->failed_pin_attempts + 1;
        if ($attempts >= config('pilote.pin_max_attempts')) {
            $user->forceFill([
                'failed_pin_attempts' => 0,
                'locked_until' => now()->addMinutes(config('pilote.pin_lock_minutes')),
            ])->save();

            return self::locked($user);
        }
        $user->forceFill(['failed_pin_attempts' => $attempts])->save();

        return response()->json([
            'code' => 'wrong_pin',
            'message' => "Ce n'est pas le bon code secret.",
            'attempts_left' => config('pilote.pin_max_attempts') - $attempts,
        ], 422);
    }

    private static function locked(User $user): JsonResponse
    {
        $minutes = max(1, (int) ceil(now()->diffInSeconds($user->locked_until) / 60));

        return response()->json([
            'code' => 'locked',
            'message' => "Trop d'essais. Réessayez dans {$minutes} minutes.",
            'retry_after_minutes' => $minutes,
        ], 423);
    }

    private function phone(Request $request): ?string
    {
        $raw = $request->validate(['phone' => 'required|string|max:20'])['phone'];

        return PhoneNumber::normalizeCameroon($raw);
    }

    private function invalidPhone(): JsonResponse
    {
        return ApiError::make('invalid_phone', 'Ce numéro ne semble pas correct.', 422);
    }

    private function weakPin(): JsonResponse
    {
        return ApiError::make('weak_pin', 'Ce code est trop facile à deviner. Choisissez-en un autre.', 422);
    }
}
