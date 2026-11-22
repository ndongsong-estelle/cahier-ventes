<?php

namespace App\Services;

use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\Storage;

/** Supprime tout ce qui concerne un compte : lignes et fichiers, sans reste. */
class AccountDeleter
{
    /** Tables qui portent une colonne user_id. */
    public const TABLES = ['events', 'answers', 'app_errors', 'backups', 'devices'];

    public static function delete(User $user): void
    {
        DB::transaction(function () use ($user) {
            foreach (self::TABLES as $table) {
                if (Schema::hasTable($table)) {
                    DB::table($table)->where('user_id', $user->id)->delete();
                }
            }
            $user->tokens()->delete();
            $user->delete();
        });

        Storage::disk('local')->deleteDirectory(self::backupDirectory($user->id));
    }

    public static function backupDirectory(int $userId): string
    {
        return "backups/{$userId}";
    }
}
