import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ReadingProgressStore {
  static const _prefix = 'reading_progress:';

  Future<void> saveProgress(String materialId, int lastOrder) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode({
      'order': lastOrder,
      'updatedAt': DateTime.now().toIso8601String(),
    });
    await prefs.setString(_key(materialId), payload);
  }

  Future<ReadingProgressRecord?> loadProgress(String materialId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(materialId));
    if (raw == null) return null;
    return _decode(materialId, raw);
  }

  Future<Map<String, ReadingProgressRecord>> allProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, ReadingProgressRecord> result = {};
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(_prefix)) continue;
      final materialId = key.substring(_prefix.length);
      final raw = prefs.getString(key);
      if (raw == null) continue;
      final record = _decode(materialId, raw);
      if (record != null) {
        result[materialId] = record;
      }
    }
    return result;
  }

  Future<void> clearProgress(String materialId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(materialId));
  }

  ReadingProgressRecord? _decode(String materialId, String raw) {
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final orderRaw = data['order'];
      int? order;
      if (orderRaw is int) {
        order = orderRaw;
      } else if (orderRaw is num) {
        order = orderRaw.toInt();
      } else if (orderRaw is String) {
        order = int.tryParse(orderRaw);
      }
      if (order == null) return null;
      DateTime? timestamp;
      final updatedAtRaw = data['updatedAt'];
      if (updatedAtRaw is String) {
        timestamp = DateTime.tryParse(updatedAtRaw);
      }
      return ReadingProgressRecord(
        materialId: materialId,
        lastOrder: order,
        updatedAt: timestamp,
      );
    } catch (_) {
      return null;
    }
  }

  String _key(String materialId) => '$_prefix$materialId';
}

class ReadingProgressRecord {
  ReadingProgressRecord({
    required this.materialId,
    required this.lastOrder,
    this.updatedAt,
  });

  final String materialId;
  final int lastOrder;
  final DateTime? updatedAt;
}
