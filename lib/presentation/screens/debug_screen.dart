import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:learn_languages/domain/entities/user_word_status.dart';
import 'package:learn_languages/domain/entities/word.dart';
import 'package:learn_languages/domain/repositories/i_user_word_status_repository.dart';
import 'package:learn_languages/domain/repositories/i_word_repository.dart';

import '../../core/di.dart';
import '../../data/remote/appwrite_service.dart';

class DebugScreen extends StatelessWidget {
  const DebugScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final wordRepo = getIt<IWordRepository>();
    final userWordStatusRepo = getIt<IUserWordStatusRepository>();
    final appwriteService = getIt<AppwriteService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Debug: Word Status Info')),
      body: FutureBuilder<List<Object>>(
        future: Future.wait([
          wordRepo.fetchTopN('en', 100), // Placeholder for language
          appwriteService.account.get().then((user) => userWordStatusRepo.fetchByStatus(user.$id, WordStatus.inProgress)),
        ]),
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || snap.data == null) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final allWords = snap.data![0] as List<Word>;
          final allStatuses = snap.data![1] as List<UserWordStatus>;
          final statusMap = {for (var s in allStatuses) s.wordId: s};

          return ListView.builder(
            itemCount: allWords.length,
            itemBuilder: (_, i) {
              final w = allWords[i];
              final s = statusMap[w.id];

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text(w.text, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Status: ${s?.status.name ?? 'N/A'}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}