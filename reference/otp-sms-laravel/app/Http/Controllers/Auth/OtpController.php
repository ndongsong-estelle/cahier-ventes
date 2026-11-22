<?php

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Services\OtpService;
use App\Support\PhoneNumber;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class OtpController extends Controller
{
    public function send(Request $request, OtpService $otp): JsonResponse
    {
        $data = $request->validate(['phone' => 'required|string|max:20']);

        $phone = PhoneNumber::normalizeCameroon($data['phone']);
        if (! $phone) {
            return response()->json(['message' => 'Numéro de téléphone invalide.'], 422);
        }

        $otp->send($phone);

        return response()->json(['message' => 'Code envoyé.', 'phone' => $phone]);
    }

    public function verify(Request $request, OtpService $otp): JsonResponse
    {
        $data = $request->validate([
            'phone' => 'required|string|max:20',
            'code' => 'required|digits:' . config('otp.length'),
            'device_name' => 'nullable|string|max:100',
        ]);

        $phone = PhoneNumber::normalizeCameroon($data['phone']);

        if (! $phone || ! $otp->verify($phone, $data['code'])) {
            return response()->json(['message' => 'Code incorrect ou expiré.'], 422);
        }

        $user = User::firstOrCreate(['phone' => $phone], ['name' => $phone]);
        $user->forceFill(['phone_verified_at' => $user->phone_verified_at ?? now()])->save();

        $token = $user->createToken($data['device_name'] ?? 'mobile')->plainTextToken;

        return response()->json([
            'token' => $token,
            'user' => $user,
            'is_new' => $user->wasRecentlyCreated, // l'app enchaîne sur la création de la boutique et du PIN
        ]);
    }
}
