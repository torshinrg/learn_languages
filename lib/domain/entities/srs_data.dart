// lib/domain/entities/srs_data.dart
class SRSData {
  final String wordId;
  final int interval;       // days
  final double easiness;    // SM-2 easiness factor
  final int repetition;     // how many times reviewed
  final DateTime nextReview;

  SRSData({
    required this.wordId,
    required this.interval,
    required this.easiness,
    required this.repetition,
    required this.nextReview,
  });

  factory SRSData.fromMap(Map<String, dynamic> map) {
    return SRSData(
      wordId: map['word_id'] as String,
      interval: map['interval'] as int,
      easiness: map['easiness'] as double,
      repetition: map['repetition'] as int,
      nextReview: DateTime.fromMillisecondsSinceEpoch(map['next_review'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'word_id': wordId,
      'interval': interval,
      'easiness': easiness,
      'repetition': repetition,
      'next_review': nextReview.millisecondsSinceEpoch,
    };
  }
}
