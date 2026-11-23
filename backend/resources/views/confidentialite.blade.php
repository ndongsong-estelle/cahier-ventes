{{-- À faire relire : conformité à la loi camerounaise sur la protection des données personnelles. --}}
<!doctype html>
<html lang="fr">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Confidentialité · Cahier de ventes</title>
    <script src="https://cdn.tailwindcss.com"></script>
</head>
<body class="bg-gray-50 text-gray-900">
<main class="max-w-2xl mx-auto p-5 text-lg leading-relaxed space-y-5">
    <h1 class="text-2xl font-bold">Cahier de ventes : vos informations</h1>

    <section>
        <h2 class="font-bold">Ce que nous gardons</h2>
        <ul class="list-disc pl-6">
            <li>Votre numéro de téléphone et le nom de votre boutique.</li>
            <li>Une copie de votre cahier : vos ventes, vos articles, et les noms et numéros des personnes que vous notez.
                Les photos restent sur votre téléphone, elles ne sont pas copiées.</li>
            <li>Comment l'app est utilisée : par exemple « une vente a été enregistrée » ou « un onglet a été ouvert ».
                Jamais les montants exacts, jamais les noms des personnes.</li>
        </ul>
    </section>

    <section>
        <h2 class="font-bold">Pourquoi</h2>
        <p>La copie vous permet de retrouver votre cahier si vous changez de téléphone ou si vous le perdez.
            Les informations d'usage nous aident à rendre l'app plus simple.</p>
    </section>

    <section>
        <h2 class="font-bold">Qui y a accès</h2>
        <p>Seule l'équipe du Cahier de ventes. Le tableau de suivi ne montre jamais le contenu de votre cahier.
            Rien n'est vendu ni donné à d'autres.</p>
    </section>

    <section>
        <h2 class="font-bold">Combien de temps</h2>
        <p>Tant que votre compte existe. Un compte sans aucune utilisation pendant 12 mois est supprimé avec toutes ses informations.</p>
    </section>

    <section>
        <h2 class="font-bold">Supprimer votre compte</h2>
        <p>Dans l'app : Réglages, puis « Supprimer mon compte ». Tout est effacé, sur le serveur et sur votre téléphone.
            Vous pouvez aussi nous écrire sur WhatsApp @if (config('pilote.support_whatsapp'))au {{ config('pilote.support_whatsapp') }}@endif.</p>
    </section>
</main>
</body>
</html>
