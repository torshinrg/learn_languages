// File: lib/presentation/screens/debug_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/di.dart';
import '../../domain/entities/srs_data.dart';
import '../../domain/entities/word.dart';
import '../../services/learning_service.dart';
import '../../services/srs_service.dart';

class DebugScreen extends StatelessWidget {
  const DebugScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final learningService = getIt<LearningService>();
    final srsService = getIt<SRSService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Debug: Word SRS Info')),
      body: FutureBuilder<List<Object>>(
        future: Future.wait([
          learningService.getAllWords(),
          srsService.fetchAllData(),
        ]),
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || snap.data == null) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final allWords = snap.data![0] as List<Word>;
          final allSrs   = snap.data![1] as List<SRSData>;
          final srsMap = { for (var s in allSrs) s.wordId : s };
          final dateFmt = DateFormat('yyyy-MM-dd HH:mm');

          return ListView.builder(
            itemCount: allWords.length,
            itemBuilder: (_, i) {
              final w = allWords[i];
              final s = srsMap[w.id];
              final nextReviewStr = s != null
                  ? dateFmt.format(s.nextReview)
                  : '—';
              final intervalStr = s?.interval.toString() ?? '—';
              final easinessStr = s?.easiness.toStringAsFixed(2) ?? '—';
              final repetitionStr = s?.repetition.toString() ?? '—';
              final lastReviewStr = s != null
                  ? dateFmt.format(s.nextReview.subtract(Duration(days: s.interval)))
                  : '—';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text(w.text, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Interval: $intervalStr days'),
                      Text('Easiness: $easinessStr'),
                      Text('Repetitions: $repetitionStr'),
                      Text('Next review: $nextReviewStr'),
                      Text('Estimated last review: $lastReviewStr'),
                    ],
                  ),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
