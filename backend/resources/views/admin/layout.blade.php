<!doctype html>
<html lang="fr">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="robots" content="noindex">
    <title>@yield('title', 'Tableau de bord') · Cahier de ventes</title>
    <script src="https://cdn.tailwindcss.com"></script>
</head>
<body class="bg-gray-50 text-gray-900">
<header class="bg-green-800 text-white px-4 py-3 flex items-center justify-between">
    <a href="{{ route('admin.index') }}" class="font-bold">Cahier de ventes · pilote</a>
    @if (session('admin'))
        <form method="post" action="{{ route('admin.logout') }}">@csrf<button class="underline">Se déconnecter</button></form>
    @endif
</header>
<main class="max-w-7xl mx-auto p-4">
    @if (session('status'))
        <p class="mb-4 rounded bg-green-100 p-3">{{ session('status') }}</p>
    @endif
    @yield('content')
</main>
</body>
</html>
