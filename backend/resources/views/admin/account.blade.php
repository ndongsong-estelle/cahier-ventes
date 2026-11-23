@extends('admin.layout')
@section('title', $user->shop_name)
@section('content')
<h1 class="text-2xl font-bold">{{ $user->shop_name }}</h1>
<p class="text-gray-600 mb-4">{{ $user->phone }} · créé le {{ $user->created_at->timezone('Africa/Douala')->format('d/m/Y') }}</p>

@if (session('temporary_pin'))
    <div class="mb-4 rounded bg-yellow-100 p-4 text-lg">
        Code provisoire : <strong class="text-3xl tracking-widest">{{ session('temporary_pin') }}</strong>
        — affiché une seule fois. La personne devra en choisir un nouveau à la connexion.
    </div>
@endif

<div class="grid md:grid-cols-2 gap-6">
<section class="bg-white rounded shadow p-4">
    <h2 class="font-bold mb-2">Ventes par jour (21 jours)</h2>
    <table class="text-sm w-full">
        @foreach ($data['sales_by_day'] as $d)
            <tr class="border-t"><td class="py-1">{{ $d['day'] }}</td><td class="py-1 text-right">{{ $d['sales'] }}</td></tr>
        @endforeach
    </table>
</section>

<section class="space-y-6">
    <div class="bg-white rounded shadow p-4">
        <h2 class="font-bold mb-2">Fonctions utilisées</h2>
        <ul class="text-sm">
            @forelse ($data['features'] as $name => $n)<li>{{ $name }} : {{ $n }}</li>@empty<li>Rien encore.</li>@endforelse
        </ul>
    </div>
    <div class="bg-white rounded shadow p-4">
        <h2 class="font-bold mb-2">Réponses</h2>
        <ul class="text-sm">
            @forelse ($data['answers'] as $a)
                <li>{{ \Carbon\Carbon::parse($a->occurred_at_corrected)->timezone('Africa/Douala')->format('d/m') }} · {{ $a->question_id }} : {{ $a->value }} {{ $a->text }}</li>
            @empty<li>Aucune réponse.</li>@endforelse
        </ul>
    </div>
    <div class="bg-white rounded shadow p-4">
        <h2 class="font-bold mb-2">10 dernières erreurs</h2>
        <ul class="text-sm space-y-1">
            @forelse ($data['errors'] as $e)
                <li><span class="text-gray-500">{{ \Carbon\Carbon::parse($e->occurred_at_corrected)->timezone('Africa/Douala')->format('d/m H:i') }} · {{ $e->app_version }}</span> {{ \Illuminate\Support\Str::limit($e->message, 200) }}</li>
            @empty<li>Aucune erreur.</li>@endforelse
        </ul>
    </div>
    <div class="bg-white rounded shadow p-4">
        <h2 class="font-bold mb-2">Copies (jamais le contenu)</h2>
        <ul class="text-sm">
            @forelse ($data['backups'] as $b)
                <li>{{ $b->created_at->timezone('Africa/Douala')->format('d/m H:i') }} · {{ number_format($b->size_bytes / 1024, 1, ',', ' ') }} Ko
                    · @foreach (($b->counts ?? []) as $k => $v){{ $k }} {{ $v }} @endforeach {{ $b->encrypted ? '· chiffrée' : '' }}</li>
            @empty<li>Pas encore de copie.</li>@endforelse
        </ul>
    </div>
</section>
</div>

<section class="bg-white rounded shadow p-4 mt-6">
    <h2 class="font-bold mb-2">Notes</h2>
    <form method="post" action="{{ route('admin.notes', $user) }}">
        @csrf
        <textarea name="notes" rows="6" class="w-full border rounded p-2">{{ $user->notes }}</textarea>
        <button class="mt-2 bg-green-700 text-white rounded px-4 py-2">Enregistrer les notes</button>
    </form>
</section>

<section class="bg-white rounded shadow p-4 mt-6 flex flex-wrap gap-6 items-end">
    <form method="post" action="{{ route('admin.pin', $user) }}">
        @csrf
        <button class="bg-yellow-500 rounded px-4 py-2 font-semibold">Donner un code provisoire</button>
    </form>
    <form method="post" action="{{ route('admin.destroy', $user) }}" class="space-y-2">
        @csrf @method('DELETE')
        @error('confirm_phone')<p class="text-red-700">{{ $message }}</p>@enderror
        <label class="block text-sm">Pour confirmer, tapez le numéro {{ $user->phone }}
            <input name="confirm_phone" class="mt-1 w-full border rounded p-2">
        </label>
        <button class="bg-red-700 text-white rounded px-4 py-2">Supprimer ce compte et toutes ses données</button>
    </form>
</section>
@endsection
