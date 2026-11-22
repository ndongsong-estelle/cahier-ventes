<?php

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use App\Services\OtpService;
use App\Support\ApiError;
use App\Support\OtpTicket;
use App\Support\PhoneNumber;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/** Module de reference/otp-sms-laravel adapté : verify renvoie un otp_ticket, sans créer d'utilisateur. */
class OtpController extends Controller
{
    public function send(Request $request, OtpService $otp): JsonResponse
    {
        if (! config('pilote.otp_enabled')) {
            return ApiError::make('otp_disabled', 'La vérification par SMS est désactivée.', 404);
        }
        $data = $request->validate(['phone' => 'required|string|max:20']);
        $phone = PhoneNumber::normalizeCameroon($data['phone']);
        if (! $phone) {
            return ApiError::make('invalid_phone', 'Ce numéro ne semble pas correct.', 422);
        }

        $otp->send($phone);

        return response()->json(['message' => 'Code envoyé.', 'phone' => $phone]);
    }

    public function verify(Request $request, OtpService $otp): JsonResponse
    {
        if (! config('pilote.otp_enabled')) {
            return ApiError::make('otp_disabled', 'La vérification par SMS est désactivée.', 404);
        }
        $data = $request->validate([
            'phone' => 'required|string|max:20',
            'code' => 'required|digits:'.config('otp.length'),
        ]);
        $phone = PhoneNumber::normalizeCameroon($data['phone']);

        if (! $phone || ! $otp->verify($phone, $data['code'])) {
            return ApiError::make('wrong_otp', 'Code incorrect ou expiré.', 422);
        }

        return response()->json(['otp_ticket' => OtpTicket::issue($phone), 'phone' => $phone]);
    }
}
