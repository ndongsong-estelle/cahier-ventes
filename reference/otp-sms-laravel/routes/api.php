<?php

use App\Http\Controllers\Auth\OtpController;
use Illuminate\Support\Facades\Route;

Route::prefix('auth/otp')->group(function () {
    Route::post('send', [OtpController::class, 'send'])->middleware('throttle:otp-send');
    Route::post('verify', [OtpController::class, 'verify'])->middleware('throttle:otp-verify');
});
