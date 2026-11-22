<?php

namespace App\Support;

use Illuminate\Http\JsonResponse;

/** Erreur lisible par l'app : un code stable + une phrase courte en français. */
class ApiError
{
    public static function make(string $code, string $message, int $status): JsonResponse
    {
        return response()->json(['code' => $code, 'message' => $message], $status);
    }
}
