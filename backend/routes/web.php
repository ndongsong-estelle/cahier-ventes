<?php

use App\Http\Controllers\Admin\AdminController;
use App\Http\Middleware\AdminOnly;
use Illuminate\Support\Facades\Route;

Route::get('/', fn () => redirect('/confidentialite'));
Route::view('/confidentialite', 'confidentialite')->name('privacy');

Route::prefix('admin')->name('admin.')->group(function () {
    Route::get('login', [AdminController::class, 'loginForm'])->name('login');
    Route::post('login', [AdminController::class, 'login'])->middleware('throttle:5,1');

    Route::middleware(AdminOnly::class)->group(function () {
        Route::get('/', [AdminController::class, 'index'])->name('index');
        Route::post('logout', [AdminController::class, 'logout'])->name('logout');
        Route::get('comptes/{user}', [AdminController::class, 'show'])->name('account');
        Route::post('comptes/{user}/notes', [AdminController::class, 'notes'])->name('notes');
        Route::post('comptes/{user}/code-provisoire', [AdminController::class, 'temporaryPin'])->name('pin');
        Route::delete('comptes/{user}', [AdminController::class, 'destroy'])->name('destroy');
    });
});
