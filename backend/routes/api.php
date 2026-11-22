<?php

use App\Http\Controllers\Auth\AuthController;
use App\Http\Controllers\Auth\OtpController;
use App\Http\Controllers\BackupController;
use App\Http\Controllers\ConfigController;
use App\Http\Controllers\MeController;
use Illuminate\Support\Facades\Route;

Route::middleware('throttle:public')->group(function () {
    Route::post('auth/check', [AuthController::class, 'check']);
    Route::post('auth/register', [AuthController::class, 'register']);
    Route::post('auth/login', [AuthController::class, 'login']);
    Route::post('auth/pin/reset', [AuthController::class, 'resetPin']);
    Route::post('auth/otp/send', [OtpController::class, 'send'])->middleware('throttle:otp-send');
    Route::post('auth/otp/verify', [OtpController::class, 'verify'])->middleware('throttle:otp-verify');
});

Route::middleware(['auth:sanctum', 'touch.device', 'throttle:user'])->group(function () {
    Route::post('auth/logout', [AuthController::class, 'logout']);
    Route::post('auth/pin', [AuthController::class, 'changePin']);
    Route::get('me', [MeController::class, 'show']);
    Route::patch('me', [MeController::class, 'update']);
    Route::delete('me', [MeController::class, 'destroy']);
    Route::get('config', [ConfigController::class, 'show']);
    Route::post('backups', [BackupController::class, 'store']);
    Route::get('backups/latest', [BackupController::class, 'latest']);
    Route::get('backups/{id}/file', [BackupController::class, 'file']);
});
