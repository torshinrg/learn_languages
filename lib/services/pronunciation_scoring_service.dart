// lib/services/pronunciation_scoring_service.dart
import 'dart:math';

class PronunciationScoringService {
  /// Returns a [0..1] score: 1.0 = perfect match
  double score(String expected, String actual) {
    final s = expected.toLowerCase();
    final t = actual.toLowerCase();
    final dist = _levenshtein(s, t);
    final maxLen = max(s.length, t.length);
    if (maxLen == 0) return 1.0;
    return (1.0 - dist / maxLen).clamp(0.0, 1.0);
  }

  int _levenshtein(String s, String t) {
    final n = s.length, m = t.length;
    if (n == 0) return m;
    if (m == 0) return n;
    // DP table
    final dp = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
    for (var i = 0; i <= n; i++) dp[i][0] = i;
    for (var j = 0; j <= m; j++) dp[0][j] = j;
    for (var i = 1; i <= n; i++) {
      for (var j = 1; j <= m; j++) {
        final cost = s[i - 1] == t[j - 1] ? 0 : 1;
        dp[i][j] = [
          dp[i - 1][j] + 1,
          dp[i][j - 1] + 1,
          dp[i - 1][j - 1] + cost,
        ].reduce(min);
      }
    }
    return dp[n][m];
  }
}
