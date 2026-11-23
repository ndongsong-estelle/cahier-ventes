<?php

use Illuminate\Support\Facades\Schedule;

// Cron du serveur : * * * * * php artisan schedule:run (voir DEPLOY.md).
Schedule::command('pilote:supprimer-inactifs')->dailyAt('03:00')->timezone('Africa/Douala');
