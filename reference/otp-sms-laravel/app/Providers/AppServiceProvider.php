<?php

namespace App\Providers;

use App\Sms\LogSmsSender;
use App\Sms\SmsSender;
use App\Sms\SmsToSender;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        $this->app->bind(SmsSender::class, fn () => match (config('otp.driver')) {
            'smsto' => new SmsToSender(),
            default => new LogSmsSender(),
        });
    }

    public function boot(): void
    {
        // Protège ton crédit SMS : par numéro, par IP, et plafond global journalier
        RateLimiter::for('otp-send', fn (Request $request) => [
            Limit::perHour(5)->by('phone:' . preg_replace('/\D+/', '', (string) $request->input('phone'))),
            Limit::perHour(10)->by('ip:' . $request->ip()),
            Limit::perDay(500)->by('global-otp'),
        ]);

        RateLimiter::for('otp-verify', fn (Request $request) => Limit::perMinute(10)->by($request->ip()));
    }
}
