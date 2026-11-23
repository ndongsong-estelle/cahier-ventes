<?php

namespace App\Http\Controllers;

use App\Models\Device;
use App\Support\Whitelist;
use Carbon\CarbonImmutable;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Throwable;

/**
 * POST /events, /answers, /errors : lots de 200 au plus, dédoublonnés par id.
 * Correction d'horloge : skew = received_at − sent_at ; occurred_at_corrected = occurred_at + skew.
 */
class TelemetryController extends Controller
{
    public function events(Request $request): JsonResponse
    {
        return $this->ingest($request, 'events', function (array $item, array $base) {
            $name = (string) ($item['name'] ?? '');
            $props = $item['props'] ?? null;
            if (! Whitelist::allows($name, $props)) {
                return null;
            }

            return $base + [
                'name' => $name,
                'props' => $props ? json_encode($props) : null,
                'occurred_at' => $base['_occurred'],
            ];
        });
    }

    public function answers(Request $request): JsonResponse
    {
        return $this->ingest($request, 'answers', function (array $item, array $base) {
            $question = (string) ($item['question_id'] ?? '');
            if ($question === '' || strlen($question) > 40) {
                return null;
            }

            return [
                'id' => $base['id'],
                'user_id' => $base['user_id'],
                'question_id' => $question,
                'value' => isset($item['value']) ? Str::limit((string) $item['value'], 40, '') : null,
                'text' => isset($item['text']) ? Str::limit((string) $item['text'], 500, '') : null,
                'occurred_at_corrected' => $base['occurred_at_corrected'],
            ];
        });
    }

    public function errors(Request $request): JsonResponse
    {
        return $this->ingest($request, 'app_errors', function (array $item, array $base) {
            return $base + [
                'app_version' => isset($item['app_version']) ? Str::limit((string) $item['app_version'], 30, '') : null,
                'message' => Str::limit((string) ($item['message'] ?? ''), 1000, ''),
                'stack' => isset($item['stack']) ? substr((string) $item['stack'], 0, 4096) : null,
            ];
        });
    }

    private function ingest(Request $request, string $table, callable $map): JsonResponse
    {
        $data = $request->validate([
            'sent_at' => 'required|date',
            'items' => 'required|array|max:'.config('telemetry.max_batch'),
            'items.*' => 'array',
        ]);

        $received = CarbonImmutable::now();
        $skew = (int) $received->getTimestamp() - (int) CarbonImmutable::parse($data['sent_at'])->getTimestamp();
        $user = $request->user();
        $deviceId = $request->user()->currentAccessToken()?->name;
        if ($deviceId) {
            Device::whereKey($deviceId)->where('user_id', $user->id)->update(['clock_offset_seconds' => $skew]);
        }

        $ids = collect($data['items'])->pluck('id')->filter(fn ($id) => is_string($id) && Str::isUuid($id));
        $known = DB::table($table)->whereIn('id', $ids)->pluck('id')->flip();

        $accepted = $duplicates = $ignored = 0;
        $rows = [];
        foreach ($data['items'] as $item) {
            $id = $item['id'] ?? null;
            if (! is_string($id) || ! Str::isUuid($id)) {
                $ignored++;

                continue;
            }
            if (isset($known[$id]) || isset($rows[$id])) {
                $duplicates++;

                continue;
            }
            try {
                $occurred = CarbonImmutable::parse($item['occurred_at'] ?? '');
            } catch (Throwable) {
                $ignored++;

                continue;
            }
            $base = [
                'id' => $id,
                'user_id' => $user->id,
                'device_id' => $deviceId,
                'occurred_at_corrected' => $occurred->addSeconds($skew)->utc(),
                'received_at' => $received->utc(),
                '_occurred' => $occurred->utc(),
            ];
            $row = $map($item, $base);
            if ($row === null) {
                $ignored++;

                continue;
            }
            unset($row['_occurred']);
            $rows[$id] = $row;
            $accepted++;
        }
        if ($rows) {
            DB::table($table)->insertOrIgnore(array_values($rows));
        }

        return response()->json(compact('accepted', 'duplicates', 'ignored'), 202);
    }
}
