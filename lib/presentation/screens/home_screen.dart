// lib/presentation/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:learn_languages/presentation/screens/stats_screen.dart';
import 'package:provider/provider.dart';

import '../providers/home_provider.dart';
import '../providers/settings_provider.dart';
import 'debug_screen.dart';
import 'study_screen.dart';
import 'review_screen.dart';
import 'vocabulary_screen.dart';
import 'settings_screen.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late HomeProvider _home;
  late SettingsProvider _settings;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _home = context.read<HomeProvider>();
    _settings = context.read<SettingsProvider>();
    _home.refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // on resume, reload settings (reset studiedCount/streak if day changed)
      _settings.reload();
      // and refresh due/study state
      _home.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dueCount = context.watch<HomeProvider>().dueCount;
    final canStudy = context.watch<HomeProvider>().canStudy;
    final studied = context.watch<SettingsProvider>().studiedCount;
    final daily = context.watch<SettingsProvider>().dailyCount;
    final progress = daily > 0 ? (studied / daily).clamp(0.0, 1.0) : 0.0;
    final streak = context.watch<SettingsProvider>().streakCount;
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Column(
            children: [
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
                color: Colors.white,
                child: ListTile(
                  leading: Icon(
                    Icons.local_fire_department,
                    color: Theme.of(context).primaryColor,
                  ),
                  title: Text(
                    '${loc.streak} $streak ${streak == 1 ? '${loc.day}' : '${loc.days}'}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (dueCount > 0)
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                  color: Colors.white,
                  child: ListTile(
                    leading: Icon(
                      Icons.refresh,
                      color: Theme.of(context).primaryColor,
                    ),
                    title: Text(
                      loc.reviewsDue(dueCount),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    trailing: TextButton(
                      onPressed:
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ReviewScreen(),
                            ),
                          ).then((_) => _home.refresh()),
                      child: Text(loc.review),
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc.today_session,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$studied / $daily ${loc.new_words_learned}',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.play_arrow),
                          label: Text(loc.start_study),
                          onPressed:
                              canStudy
                                  ? () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const StudyScreen(),
                                    ),
                                  ).then((_) => _home.refresh())
                                  : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              Row(
                children: [
                  _ActionTile(
                    icon: Icons.refresh,
                    label: loc.review,
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ReviewScreen(),
                          ),
                        ).then((_) => _home.refresh()),
                  ),
                  const SizedBox(width: 12),
                  _ActionTile(
                    icon: Icons.bookmark,
                    label: loc.vocabulary,
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const VocabularyScreen(),
                          ),
                        ),
                  ),
                  const SizedBox(width: 12),
                  _ActionTile(
                    icon: Icons.bar_chart,
                    label: loc.stats,
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const StatsScreen(),
                          ),
                        ),
                  ),
                  const SizedBox(width: 12),
                  _ActionTile(
                    icon: Icons.settings,
                    label: loc.settings,
                    onTap:
                        () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SettingsScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),

      floatingActionButton: FloatingActionButton(
        tooltip: 'Debug SRS data',
        child: const Icon(Icons.bug_report),
        onPressed:
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DebugScreen()),
            ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

/// Small tile used in the “Review / Vocabulary / Stats” row.
class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final col = Theme.of(context).primaryColor;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: col.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon, size: 28, color: col),
              const SizedBox(height: 8),
              Text(label, style: TextStyle(color: col)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Icon + label for the bottom nav.
class _NavIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _NavIcon({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final col = Theme.of(context).primaryColor;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: col),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: col)),
        ],
      ),
    );
  }
}
