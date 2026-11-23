@extends('admin.layout')
@section('title', 'Connexion')
@section('content')
<form method="post" action="{{ url('/admin/login') }}" class="max-w-sm mx-auto mt-10 bg-white p-6 rounded shadow space-y-4">
    @csrf
    <h1 class="text-xl font-bold">Connexion</h1>
    @error('email')<p class="text-red-700">{{ $message }}</p>@enderror
    <label class="block">Adresse e-mail
        <input name="email" type="email" value="{{ old('email') }}" required class="mt-1 w-full border rounded p-2">
    </label>
    <label class="block">Mot de passe
        <input name="password" type="password" required class="mt-1 w-full border rounded p-2">
    </label>
    <button class="w-full bg-green-700 text-white rounded p-2 font-semibold">Se connecter</button>
</form>
@endsection
