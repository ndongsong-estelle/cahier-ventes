<?php

// Liste blanche des statistiques d'usage (docs/02). Rien d'autre n'est enregistré.
// nom => [clé de props => valeurs permises (liste) ou type ('int', 'bool', 'string')].
$bucket = ['lt5k', '5k_20k', '20k_100k', 'gt100k'];
$method = ['cash', 'orange_money', 'momo'];

return [
    'events' => [
        'app_opened' => [],
        'tab_viewed' => ['tab' => ['today', 'debts', 'articles']],
        'sale_started' => [],
        'sale_saved' => [
            'payment' => ['paid', 'partial', 'unpaid'],
            'method' => $method,
            'amount_bucket' => $bucket,
            'articles_count' => 'int',
            'used_photo' => 'bool',
            'has_person' => 'bool',
            'seconds' => 'int',
        ],
        'sale_undone' => [],
        'sale_edited' => [],
        'sale_deleted' => [],
        'payment_added' => ['method' => $method, 'amount_bucket' => $bucket],
        'reminder_sent' => [],
        'call_made' => [],
        'receipt_sent' => [],
        'article_kept' => [],
        'article_created' => ['has_photo' => 'bool'],
        'summary_opened' => ['period' => ['week', 'month']],
        'manual_copy_made' => [],
        'manual_copy_restored' => [],
        'pin_changed' => [],
        'question_answered' => ['question_id' => 'string'],
    ],
    'max_batch' => 200,
];
