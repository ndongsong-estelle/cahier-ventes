<?php

namespace App\Http\Controllers;

use App\Http\Controllers\Auth\AuthController;
use App\Services\AccountDeleter;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class MeController extends Controller
{
    public function show(Request $request): JsonResponse
    {
        $user = $request->user();

        return response()->json(['user' => $user->toApi(), 'must_change_pin' => $user->pin_is_temporary]);
    }

    public function update(Request $request): JsonResponse
    {
        $data = $request->validate(['shop_name' => 'required|string|min:2|max:60']);
        $user = $request->user();
        $user->update(['shop_name' => trim($data['shop_name'])]);

        return response()->json(['user' => $user->toApi()]);
    }

    public function destroy(Request $request): JsonResponse
    {
        $data = $request->validate(['pin' => 'required|string|max:10']);
        $user = $request->user();

        $check = AuthController::checkPin($user, $data['pin']);
        if ($check) {
            return $check;
        }
        AccountDeleter::delete($user);

        return response()->json(['deleted' => true]);
    }
}
