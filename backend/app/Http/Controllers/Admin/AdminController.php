<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Services\AccountDeleter;
use App\Services\DashboardStats;
use App\Support\WeakPin;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\View\View;

class AdminController extends Controller
{
    public function loginForm(): View
    {
        return view('admin.login');
    }

    public function login(Request $request): RedirectResponse
    {
        $data = $request->validate(['email' => 'required|email', 'password' => 'required|string']);
        $email = config('pilote.admin_email');
        $hash = config('pilote.admin_password_hash');
        if (! $email || ! $hash || ! hash_equals(strtolower($email), strtolower($data['email'])) || ! Hash::check($data['password'], $hash)) {
            return back()->withErrors(['email' => 'Adresse ou mot de passe incorrect.'])->onlyInput('email');
        }
        $request->session()->regenerate();
        $request->session()->put('admin', true);

        return redirect()->route('admin.index');
    }

    public function logout(Request $request): RedirectResponse
    {
        $request->session()->invalidate();

        return redirect()->route('admin.login');
    }

    public function index(): View
    {
        $stats = new DashboardStats;

        return view('admin.index', ['summary' => $stats->summary(), 'rows' => $stats->rows()]);
    }

    public function show(User $user): View
    {
        return view('admin.account', ['user' => $user, 'data' => (new DashboardStats)->account($user)]);
    }

    public function notes(Request $request, User $user): RedirectResponse
    {
        $user->forceFill(['notes' => $request->validate(['notes' => 'nullable|string|max:10000'])['notes']])->save();

        return back()->with('status', 'Notes enregistrées.');
    }

    /** Code provisoire : 4 chiffres affichés une fois, à changer à la connexion suivante, compte débloqué. */
    public function temporaryPin(User $user): RedirectResponse
    {
        $pin = self::newPin();
        $user->forceFill([
            'pin_hash' => Hash::make($pin),
            'pin_is_temporary' => true,
            'failed_pin_attempts' => 0,
            'locked_until' => null,
        ])->save();

        return back()->with('temporary_pin', $pin);
    }

    public static function newPin(): string
    {
        do {
            $pin = str_pad((string) random_int(0, 9999), 4, '0', STR_PAD_LEFT);
        } while (WeakPin::isWeak($pin));

        return $pin;
    }

    public function destroy(Request $request, User $user): RedirectResponse
    {
        if ($request->input('confirm_phone') !== $user->phone) {
            return back()->withErrors(['confirm_phone' => 'Tapez le numéro exact pour confirmer.']);
        }
        AccountDeleter::delete($user);

        return redirect()->route('admin.index')->with('status', 'Compte supprimé avec toutes ses données.');
    }
}
