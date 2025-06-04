import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:learn_languages/presentation/screens/stats_screen.dart';
import 'package:learn_languages/presentation/screens/study_screen.dart';
import 'package:learn_languages/presentation/screens/review_screen.dart';
import 'package:learn_languages/presentation/screens/settings_screen.dart';
import '../providers/home_provider.dart';
import '../providers/settings_provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:learn_languages/core/app_language.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final homeProvider = context.watch<HomeProvider>();
    final settingsProvider = context.watch<SettingsProvider>();
    final dueCount = homeProvider.dueCount;
    final canStudy = homeProvider.canStudy;
    final studied = settingsProvider.studiedCount;
    final daily = settingsProvider.dailyCount;
    final progress = daily > 0 ? (studied / daily).clamp(0.0, 1.0) : 0.0;
    final streak = settingsProvider.streakCount;
    final lastDate = settingsProvider.lastStreakDate;
    final loc = AppLocalizations.of(context)!;
    final learningCodes = settingsProvider.learningLanguageCodes;
    final leadCode = learningCodes.isNotEmpty
        ? AppLanguageExtension.fromCode(learningCodes.first)?.displayName ?? ''
        : '';

    Future<String?> _showAddLanguageDialog() {
      final available = AppLanguage.values
          .where((lang) =>
              !settingsProvider.learningLanguageCodes.contains(lang.code) &&
              lang.code != settingsProvider.nativeLanguageCode)
          .toList();
      if (available.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No more languages')),
        );
        return Future.value(null);
      }
      return showDialog<String>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('Add language'),
          children: [
            for (final lang in available)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, lang.code),
                child: Text('${lang.flag} ${lang.displayName}'),
              )
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: null,
      ),

      body: Stack(
        children: [
          // Gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFF988E), Color(0xFFAC9AFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 50),
                if (learningCodes.isNotEmpty)
                  _LanguageMenu(
                    codes: learningCodes,
                    onTap: (code) async {
                      if (code == 'add_more') {
                        final newCode = await _showAddLanguageDialog();
                        if (newCode != null) {
                          await context
                              .read<SettingsProvider>()
                              .addLearningLanguage(newCode);
                        }
                        return;
                      }
                      context
                          .read<SettingsProvider>()
                          .switchLearningLanguage(code);
                    },
                  ),
                const SizedBox(height: 20),

                // Streak circle
                Center(
                  child: _StreakVisual(
                    streak: streak,
                    lastDate: lastDate,
                  ),
                ),
                const SizedBox(height: 40),

                // Tilted _SmallCard row, scaled up 1.5x
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Transform.rotate(
                        angle: -0.2,
                        child: Transform.scale(
                          scale: 1.05,
                          child: _SmallCard(
                            title: loc.reviewsDue(dueCount),
                            icon: Icons.check_circle,
                            buttonText: loc.review,
                            onPressed:
                                () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ReviewScreen(),
                                  ),
                                ).then(
                                  (_) => context.read<HomeProvider>().refresh(),
                                ),
                          ),
                        ),
                      ),
                      Transform.rotate(
                        angle: 0.25,
                        child: Transform.scale(
                          scale: 1.3,
                          child: _SmallCard(
                            title: loc.today_session,
                            showProgress: true,
                            progress: progress,
                            buttonText: loc.start_study,
                            onPressed:
                                canStudy
                                    ? () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const StudyScreen(),
                                      ),
                                    ).then(
                                      (_) =>
                                          context
                                              .read<HomeProvider>()
                                              .refresh(),
                                    )
                                    : null,
                            icon: Icons.rocket,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Floating bottom nav pill (Positioned ~1/4 up from bottom)
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.25,
            left: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _NavCircleButton(
                    icon: Icons.check,
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ReviewScreen(),
                          ),
                        ).then((_) => context.read<HomeProvider>().refresh()),
                  ),
                  //_NavCircleButton(icon: Icons.pause, onTap: () {}),
                  _NavCircleButton(
                    icon: Icons.bar_chart,
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const StatsScreen(),
                          ),
                        ),
                  ),
                  _NavCircleButton(
                    icon: Icons.settings,
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
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String buttonText;
  final VoidCallback? onPressed;
  final bool showProgress;
  final double progress;

  const _SmallCard({
    Key? key,
    required this.title,
    required this.icon,
    required this.buttonText,
    required this.onPressed,
    this.showProgress = false,
    this.progress = 0.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    return Container(
      width: 155,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Title Row ───────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),

          // ── Optional Progress Bar ─────────────
          if (showProgress) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                color: primary,
                backgroundColor: primary.withOpacity(0.3),
              ),
            ),
          ],
          const SizedBox(height: 12),

          // ── Button (now height: 60) ───────────
          SizedBox(
            width: double.infinity,
            height: 60, // increased from 50 → 60 to allow two lines
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                buttonText,
                textAlign: TextAlign.center,
                maxLines: 2, // allow up to two lines
                softWrap: true, // enable wrapping
                // no overflow specified, so it will wrap
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakVisual extends StatelessWidget {
  final int streak;
  final String? lastDate;
  const _StreakVisual({required this.streak, required this.lastDate});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now().toIso8601String().split('T').first;
    final bool broken = streak == 0 && lastDate != null && lastDate != today;

    Color color;
    String emoji;
    String message;

    if (broken) {
      color = Colors.black54;
      emoji = '💀';
      message = 'Streak is dead. Bring it back tomorrow!';
    } else if (streak == 0) {
      color = Colors.yellow;
      emoji = '🪔';
      message = "Let's ignite your streak!";
    } else if (streak <= 4) {
      color = Colors.orange;
      emoji = '🔥';
      message = 'Keep going!';
    } else if (streak <= 9) {
      color = Colors.red;
      emoji = '🔥🔥';
      message = 'Momentum!';
    } else if (streak <= 19) {
      color = Colors.deepOrange;
      emoji = '🏮';
      message = 'Torch blazing!';
    } else if (streak <= 29) {
      color = Colors.deepOrangeAccent;
      emoji = '🔥🔥🔥';
      message = 'Bonfire!';
    } else if (streak <= 49) {
      color = Colors.purple;
      emoji = '🔥⭕';
      message = 'Fire ring!';
    } else {
      color = Colors.pinkAccent;
      emoji = '🎆';
      message = 'Legendary streak!';
    }

    return Container(
      width: 160,
      height: 160,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 8),
          Text(
            '$streak',
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NavCircleButton({Key? key, required this.icon, required this.onTap})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: primary,
          shape: BoxShape.circle,
          border: Border.all(color: primary, width: 2),
        ),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}


class _LanguageMenu extends StatelessWidget {
  final List<String> codes;
  final void Function(String) onTap;

  const _LanguageMenu({

    Key? key,
    required this.codes,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {

    final selectedCode = codes.isNotEmpty ? codes.first : '';
    final selectedLang = AppLanguageExtension.fromCode(selectedCode);
    final selectedLabel =
        '${selectedLang?.flag ?? ''} ${selectedLang?.displayName ?? selectedCode}';

    return Container(
      alignment: Alignment.centerLeft,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: PopupMenuButton<String>(
        onSelected: onTap,
        itemBuilder: (context) {
          final items = <PopupMenuEntry<String>>[];
          for (final code in codes) {
            if (code == selectedCode) continue;
            final lang = AppLanguageExtension.fromCode(code);
            final label = '${lang?.flag ?? ''} ${lang?.displayName ?? code}';
            items.add(PopupMenuItem<String>(
              value: code,
              child: Text(label),
            ));
          }
          items.add(const PopupMenuDivider());
          items.add(const PopupMenuItem<String>(
            value: 'add_more',
            child: Text('+ Add'),
          ));
          return items;
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                selectedLabel,
                style: const TextStyle(color: Colors.white),
              ),
              const Icon(Icons.arrow_drop_down, color: Colors.white),
            ],
          ),
        ),

      ),
    );
  }
}
