<?php

namespace App\Services;

use App\Models\Backup;
use App\Models\User;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

/**
 * Copies du cahier : storage/app/backups/{user_id}/{backup_id}.json.gz (disque local, jamais public).
 * Chiffrées avec Crypt (APP_KEY) si BACKUP_ENCRYPT_AT_REST=true.
 */
class BackupStore
{
    private static function disk()
    {
        return Storage::disk('backups');
    }

    public static function save(User $user, string $gz, string $sha256, ?array $counts): Backup
    {
        $id = (string) Str::uuid();
        $path = AccountDeleter::backupDirectory($user->id)."/{$id}.json.gz";
        $encrypt = (bool) config('pilote.backup.encrypt_at_rest');
        self::disk()->put($path, $encrypt ? Crypt::encryptString(base64_encode($gz)) : $gz);

        $backup = Backup::create([
            'id' => $id,
            'user_id' => $user->id,
            'path' => $path,
            'size_bytes' => strlen($gz),
            'sha256' => $sha256,
            'counts' => $counts,
            'encrypted' => $encrypt,
        ]);
        self::prune($user);

        return $backup;
    }

    /** Contenu gzip d'origine, chiffré ou non. */
    public static function read(Backup $backup): string
    {
        $raw = self::disk()->get($backup->path);

        return $backup->encrypted ? base64_decode(Crypt::decryptString($raw)) : $raw;
    }

    public static function encrypt(Backup $backup): void
    {
        if ($backup->encrypted) {
            return;
        }
        $gz = self::read($backup);
        self::disk()->put($backup->path, Crypt::encryptString(base64_encode($gz)));
        $backup->forceFill(['encrypted' => true])->save();
    }

    /** Garde les BACKUP_KEEP plus récentes, supprime les fichiers des autres. */
    public static function prune(User $user): void
    {
        $old = Backup::where('user_id', $user->id)
            ->orderByDesc('created_at')
            ->orderByDesc('id')
            ->skip(max(1, (int) config('pilote.backup.keep')))
            ->take(PHP_INT_MAX)
            ->get();
        foreach ($old as $backup) {
            self::disk()->delete($backup->path);
            $backup->delete();
        }
    }
}
