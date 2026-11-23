/// Liste blanche des statistiques d'usage (docs/02). Même liste que backend/config/telemetry.php.
/// Rien d'autre ne part : un événement hors liste lève une erreur en test et n'est jamais stocké.
library;

const _bucket = ['lt5k', '5k_20k', '20k_100k', 'gt100k'];
const _method = ['cash', 'orange_money', 'momo'];

/// nom → clé de props → valeurs permises (List) ou type ('int', 'bool', 'string').
const Map<String, Map<String, Object>> whitelist = {
  'app_opened': {},
  'tab_viewed': {
    'tab': ['today', 'debts', 'articles'],
  },
  'sale_started': {},
  'sale_saved': {
    'payment': ['paid', 'partial', 'unpaid'],
    'method': _method,
    'amount_bucket': _bucket,
    'articles_count': 'int',
    'used_photo': 'bool',
    'has_person': 'bool',
    'seconds': 'int',
  },
  'sale_undone': {},
  'sale_edited': {},
  'sale_deleted': {},
  'payment_added': {'method': _method, 'amount_bucket': _bucket},
  'reminder_sent': {},
  'call_made': {},
  'receipt_sent': {},
  'article_kept': {},
  'article_created': {'has_photo': 'bool'},
  'summary_opened': {
    'period': ['week', 'month'],
  },
  'manual_copy_made': {},
  'manual_copy_restored': {},
  'pin_changed': {},
  'question_answered': {'question_id': 'string'},
};

bool isAllowed(String name, Map<String, Object?> props) {
  final rules = whitelist[name];
  if (rules == null) return false;
  for (final e in props.entries) {
    final rule = rules[e.key];
    final v = e.value;
    final ok = switch (rule) {
      final List<String> values => v is String && values.contains(v),
      'int' => v is int && v >= 0 && v <= 1000000,
      'bool' => v is bool,
      'string' => v is String && v.length <= 40,
      _ => false,
    };
    if (!ok) return false;
  }
  return true;
}

/// amount_bucket : lt5k | 5k_20k | 20k_100k | gt100k.
String amountBucket(int amount) => switch (amount) {
  < 5000 => 'lt5k',
  <= 20000 => '5k_20k',
  <= 100000 => '20k_100k',
  _ => 'gt100k',
};
