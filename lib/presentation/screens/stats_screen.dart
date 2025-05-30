// lib/presentation/screens/stats_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/learning_service.dart';
import '../../services/srs_service.dart';
import '../providers/settings_provider.dart';
import '../../core/constants.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// Holds computed totals for the stats screen.
class StatsData {
  final int totalWords;
  final int masteredWords;
  StatsData({required this.totalWords, required this.masteredWords});
}

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});


  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();
    final learningService = context.read<LearningService>();
    final srsService = context.read<SRSService>();

    return Scaffold(
      appBar: AppBar(title: Text(loc.stats)),
      body: FutureBuilder<StatsData>(
        future: _loadStats(learningService, srsService),
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || snap.data == null) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final stats = snap.data!;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _StatCard(
                  icon: Icons.school,
                  label: loc.today_learned,
                  value: '${settings.studiedCount}/${settings.dailyCount}',
                ),
                const SizedBox(height: 16),
                _StatCard(
                  icon: Icons.local_fire_department,
                  label: loc.current_streak,
                  value: '${settings.streakCount} ${settings.streakCount == 1 ? 'day' : 'days'}',
                ),
                const SizedBox(height: 16),
                _StatCard(
                  icon: Icons.book,
                  label: loc.total_words,
                  value: '${stats.totalWords}',
                ),
                const SizedBox(height: 16),
                _StatCard(
                  icon: Icons.check_circle,
                  label: loc.mastered_words,
                  value: '${stats.masteredWords}',
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<StatsData> _loadStats(
      LearningService ls,
      SRSService ss,
      ) async {
    final allWords = await ls.getAllWords();
    final allSrs   = await ss.fetchAllData();
    final mastered = allSrs.where((s) => s.repetition >= kMasterRepetitionThreshold).length;
    return StatsData(
      totalWords: allWords.length,
      masteredWords: mastered,
    );
  }
}

/// A simple card showing one stat.
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final col = Theme.of(context).primaryColor;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ListTile(
        leading: Icon(icon, color: col),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: Text(value,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: col)),
      ),
    );
  }
}
