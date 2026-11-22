<?php

namespace App\Http\Controllers;

use App\Models\Backup;
use App\Services\BackupStore;
use App\Support\ApiError;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;

class BackupController extends Controller
{
    public function store(Request $request): JsonResponse
    {
        if (! config('pilote.backup.enabled')) {
            return ApiError::make('backup_disabled', 'La copie est arrêtée pour le moment.', 403);
        }
        $file = $request->file('file');
        if ($file && $file->getSize() > config('pilote.backup.max_size_kb') * 1024) {
            return ApiError::make('too_large', 'La copie est trop grosse.', 413);
        }
        $data = $request->validate([
            'file' => 'required|file',
            'sha256' => 'required|string|size:64',
            'counts' => 'nullable',
        ]);

        $gz = $file->get();
        $json = @gzdecode($gz);
        if ($json === false || ! hash_equals(strtolower($data['sha256']), hash('sha256', $json))) {
            return ApiError::make('bad_sha256', 'La copie est abîmée. Elle sera renvoyée.', 422);
        }
        $counts = is_string($data['counts'] ?? null) ? json_decode($data['counts'], true) : ($data['counts'] ?? null);

        $backup = BackupStore::save($request->user(), $gz, strtolower($data['sha256']), is_array($counts) ? $counts : null);

        return response()->json(['backup' => $this->meta($backup)], 201);
    }

    public function latest(Request $request): JsonResponse
    {
        $backup = Backup::where('user_id', $request->user()->id)
            ->orderByDesc('created_at')->orderByDesc('id')->first();
        if (! $backup) {
            return ApiError::make('no_backup', 'Pas encore de copie.', 404);
        }

        return response()->json($this->meta($backup));
    }

    public function file(Request $request, string $id): Response
    {
        $backup = Backup::where('user_id', $request->user()->id)->findOrFail($id);

        return response(BackupStore::read($backup), 200, [
            'Content-Type' => 'application/gzip',
            'X-Sha256' => $backup->sha256,
        ]);
    }

    private function meta(Backup $backup): array
    {
        return [
            'id' => $backup->id,
            'created_at' => $backup->created_at->toIso8601ZuluString(),
            'counts' => $backup->counts,
            'sha256' => $backup->sha256,
            'download_url' => url("/api/backups/{$backup->id}/file"),
        ];
    }
}
