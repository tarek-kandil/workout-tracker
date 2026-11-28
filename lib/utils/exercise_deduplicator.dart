/// Normalizes exercise names into a canonical token signature for safe,
/// unambiguous deduplication of spelling/plural/hyphen/equipment variants
/// (e.g. `'Lats pulldown'`, `'Lat pull-down'`, and `'Lat Pulldowns'` all
/// normalize to `'lat pulldown'`).
///
/// Distinct movement qualifiers (`wide`, `close`, `neutral`, `underhand`,
/// `incline`, `decline`, `seated`, `standing`, `lying`, `kneeling`, `single`,
/// `weighted`, `smith`, `machine`, `cable`, `db`, `bb`, `ezbar`, etc.) are
/// preserved so distinct exercises never collide.
String normalizeExerciseSignature(String raw) {
  var s = raw
      .toLowerCase()
      .replaceAll('&', ' and ')
      .replaceAll(RegExp(r"['’`]"), '')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();

  if (s.isEmpty) return '';

  // Join split compound tokens before word-level singularization.
  const phraseReplacements = <(String, String)>[
    (r'\bdumb\s+bells?\b', 'db'),
    (r'\bkick\s+backs?\b', 'kickback'),
    (r'\bpull\s+ups?\b', 'pullup'),
    (r'\bpush\s+ups?\b', 'pushup'),
    (r'\bchin\s+ups?\b', 'chinup'),
    (r'\bsit\s+ups?\b', 'situp'),
    (r'\bstep\s+ups?\b', 'stepup'),
    (r'\bv\s+ups?\b', 'vup'),
    (r'\bpull\s+downs?\b', 'pulldown'),
    (r'\bpush\s+downs?\b', 'pushdown'),
    (r'\bpull\s+overs?\b', 'pullover'),
    (r'\bwood\s+choppers?\b', 'woodchopper'),
    (r'\bez\s+bar\b', 'ezbar'),
    (r'\bv\s+bar\b', 'vbar'),
    (r'\bstraight\s+bar\b', 'straightbar'),
    (r'\bt\s+bar\b', 'tbar'),
    (r'\bl\s+sit\b', 'lsit'),
  ];
  for (final (pattern, replacement) in phraseReplacements) {
    s = s.replaceAll(RegExp(pattern), replacement);
  }

  final tokens = s.split(RegExp(r'\s+')).map(_normalizeToken).toList();
  final joined = tokens.join(' ');
  return _kSafeShorthands[joined] ?? joined;
}

const Map<String, String> _kTokenReplacements = {
  'dumbbell': 'db',
  'dumbbells': 'db',
  'dumbell': 'db',
  'dumbells': 'db',
  'dbs': 'db',
  'barbell': 'bb',
  'barbells': 'bb',
  'bbs': 'bb',
  'kettlebell': 'kb',
  'kettlebells': 'kb',
  'kbs': 'kb',
  'flys': 'fly',
  'flyes': 'fly',
  'flies': 'fly',
  'crunches': 'crunch',
  'presses': 'press',
  'lunges': 'lunge',
  'bridges': 'bridge',
  'raises': 'raise',
  'calves': 'calf',
  'lats': 'lat',
  'abs': 'ab',
  'pecs': 'pec',
  'delts': 'delt',
  'traps': 'trap',
  'quads': 'quad',
  'glutes': 'glute',
  'biceps': 'bicep',
  'triceps': 'tricep',
  'dips': 'dip',
  'rows': 'row',
  'bugs': 'bug',
};

/// Unambiguous common gym shorthands (evaluated after token normalization).
const Map<String, String> _kSafeShorthands = {
  'rdl': 'romanian deadlift',
  'bb rdl': 'romanian deadlift',
  'db rdl': 'db romanian deadlift',
  'sldl': 'stiff leg deadlift',
  'ohp': 'overhead press',
  'military press': 'overhead press',
  'bb overhead press': 'overhead press',
  'bb shoulder press': 'overhead press',
  'bb bench press': 'bench press',
  'flat bench press': 'bench press',
  'flat bb bench press': 'bench press',
  'incline bb bench press': 'incline bench press',
  'decline bb bench press': 'decline bench press',
  'flat db bench press': 'db bench press',
  'db press': 'db bench press',
  'flat db press': 'db bench press',
  'incline db press': 'incline db bench press',
  'cgbp': 'close grip bench press',
  'bss': 'bulgarian split squat',
  'bb back squat': 'back squat',
  'bb squat': 'back squat',
  'squat': 'back squat',
  'ab wheel rollout': 'kneeling ab wheel rollout',
  'leg curl': 'seated leg curl',
  'calf raise': 'standing calf raise',
  'front raise': 'db front raise',
  'lateral raise': 'db lateral raise',
  'tricep kickback': 'db tricep kickback',
  'overhead tricep extension': 'overhead db tricep extension',
  'cable kickback': 'cable glute kickback',
  'rope face pull': 'face pull',
  'rope pushdown': 'rope tricep pushdown',
  'straightbar pushdown': 'straightbar tricep pushdown',
  'straight handle tricep pushdown': 'straightbar tricep pushdown',
  'straight handle pushdown': 'straightbar tricep pushdown',
  'vbar pushdown': 'vbar tricep pushdown',
  'triangle tricep pushdown': 'vbar tricep pushdown',
  'triangle handle tricep pushdown': 'vbar tricep pushdown',
  'triangle pushdown': 'vbar tricep pushdown',
  'triangle handle overhead cable tricep extension':
      'vbar overhead cable tricep extension',
  'triangle overhead cable tricep extension':
      'vbar overhead cable tricep extension',
  'straight handle overhead cable tricep extension':
      'straightbar overhead cable tricep extension',
  'rope hammer curl': 'rope cable hammer curl',
};

/// Matches an exercise name against a user search query, handling synonyms
/// like `"triangle"` ↔ `"V-Bar"`, `"dumbbell"` ↔ `"DB"`, `"barbell"` ↔ `"BB"`,
/// and hyphen/space differences (`"v bar"` ↔ `"V-Bar"`, `"pullup"` ↔ `"Pull-Ups"`).
bool matchesExerciseSearch(String exerciseName, String rawQuery) {
  final q = rawQuery.trim().toLowerCase();
  if (q.isEmpty) return true;
  final lowerName = exerciseName.toLowerCase();
  if (lowerName.contains(q)) return true;

  var expandedName = lowerName
      .replaceAll('-', ' ')
      .replaceAll(RegExp(r'\bv\s+bar\b'), 'v bar triangle handle')
      .replaceAll(RegExp(r'\bstraight\s+bar\b'), 'straight bar straight handle')
      .replaceAll(RegExp(r'\bdb\b'), 'db dumbbell')
      .replaceAll(RegExp(r'\bbb\b'), 'bb barbell');

  final queryTokens = q
      .replaceAll('-', ' ')
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty);
  if (queryTokens.every((t) => expandedName.contains(t))) return true;

  final normName = normalizeExerciseSignature(exerciseName);
  final normQuery = normalizeExerciseSignature(q);
  return normQuery.isNotEmpty && normName.contains(normQuery);
}

const Set<String> _kKeepTrailingS = {
  'press',
  'meadows',
  'kas',
  'swiss',
  'cross',
};

String _normalizeToken(String token) {
  final direct = _kTokenReplacements[token];
  if (direct != null) return direct;
  if (_kKeepTrailingS.contains(token)) return token;
  if (token.length > 4 && token.endsWith('s') && !token.endsWith('ss')) {
    return token.substring(0, token.length - 1);
  }
  return token;
}
