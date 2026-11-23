@extends('admin.layout')
@section('content')
<div class="grid grid-cols-3 gap-4 mb-6">
    <div class="bg-white rounded shadow p-4"><div class="text-3xl font-bold">{{ $summary['accounts'] }}</div>comptes créés</div>
    <div class="bg-white rounded shadow p-4"><div class="text-3xl font-bold">{{ $summary['active_today'] }}</div>actifs aujourd'hui</div>
    <div class="bg-white rounded shadow p-4"><div class="text-3xl font-bold">{{ $summary['active_7d'] }}</div>actifs 7 jours</div>
</div>
<div class="overflow-x-auto bg-white rounded shadow">
<table class="min-w-full text-sm">
    <thead class="bg-gray-100 text-left">
    <tr>
        <th class="p-2">Boutique</th><th class="p-2">Numéro</th><th class="p-2">Créé le</th><th class="p-2">Dernier passage</th>
        <th class="p-2">Jours avec vente</th><th class="p-2">Ventes 7 j</th><th class="p-2">Ventes total</th>
        <th class="p-2">Relances</th><th class="p-2">Reçus</th><th class="p-2">Temps médian</th>
        <th class="p-2">Dernière copie</th><th class="p-2">Aide ?</th>
    </tr>
    </thead>
    <tbody>
    @forelse ($rows as $r)
        <tr class="border-t {{ $r['inactive'] ? 'bg-gray-200 text-gray-500' : '' }}">
            <td class="p-2"><a class="underline" href="{{ route('admin.account', $r['id']) }}">{{ $r['shop'] }}</a></td>
            <td class="p-2 whitespace-nowrap">{{ $r['phone'] }}</td>
            <td class="p-2 whitespace-nowrap">{{ $r['created'] }} (J+{{ $r['pilot_day'] - 1 }})</td>
            <td class="p-2 whitespace-nowrap">{{ $r['last_seen'] ?? '—' }}</td>
            <td class="p-2">{{ $r['days_with_sale'] }} / {{ $r['days_since_creation'] }}</td>
            <td class="p-2">{{ $r['sales_7d'] }}</td>
            <td class="p-2">{{ $r['sales_total'] }}</td>
            <td class="p-2">{{ $r['reminders'] }}</td>
            <td class="p-2">{{ $r['receipts'] }}</td>
            <td class="p-2">{{ $r['median_seconds'] !== null ? $r['median_seconds'].' s' : '—' }}</td>
            <td class="p-2 whitespace-nowrap">{{ $r['last_backup'] ?? '—' }}</td>
            <td class="p-2">{{ $r['last_aide'] ?? '—' }}</td>
        </tr>
    @empty
        <tr><td class="p-4" colspan="12">Pas encore de compte.</td></tr>
    @endforelse
    </tbody>
</table>
</div>
<p class="mt-2 text-sm text-gray-600">Ligne grise : aucune vente depuis 3 jours.</p>
@endsection
