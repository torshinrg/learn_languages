import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';

import '../../core/constants.dart';
import '../../domain/entities/task.dart';
import '../../domain/repositories/i_task_repository.dart';
import 'appwrite_service.dart';

class RemoteTaskRepository implements ITaskRepository {
  RemoteTaskRepository(this._service);

  final AppwriteService _service;
  final List<Document> _sentenceTaskDocs = [];
  final Map<String, Task> _sentenceTaskMap = {};
  List<Task> _sentenceTasks = [];
  bool _sentenceTasksLoaded = false;
  bool _sentenceTasksLoading = false;

  @override
  Future<List<Task>> fetchBySentence(
    String sentenceId, {
    String? sentenceGroupId,
  }) async {
    await _ensureSentenceTasksLoaded();

    if (_sentenceTaskDocs.isEmpty) {
      return const [];
    }

    final matchingDocs =
        _sentenceTaskDocs.where((doc) {
          return _matchesCandidate(doc.data, sentenceId, sentenceGroupId);
        }).toList();

    if (matchingDocs.isEmpty) {
      return const [];
    }

    matchingDocs.sort((a, b) {
      final aOrder = _parseOrder(a.data['order'] ?? a.data['position']);
      final bOrder = _parseOrder(b.data['order'] ?? b.data['position']);
      return aOrder.compareTo(bOrder);
    });

    final tasks = <Task>[];
    for (final doc in matchingDocs) {
      final task = _sentenceTaskMap[doc.$id] ?? Task.fromMap(doc.data);
      if (_isSentenceTask(task)) {
        tasks.add(task);
      }
    }
    return tasks;
  }

  @override
  Future<List<Task>> fetchAllSentenceTasks() async {
    await _ensureSentenceTasksLoaded();
    return List<Task>.from(_sentenceTasks);
  }

  int _parseOrder(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  bool _matchesCandidate(
    Map<String, dynamic> data,
    String sentenceId,
    String? sentenceGroupId,
  ) {
    final targets = {
      'sentenceId',
      'sentence',
      'sentenceID',
      'sentence_id',
      'sentenceRef',
      'sentence_ref',
      'target',
      'targetId',
      'target_id',
    };

    bool matchesSentence = targets.any((key) {
      final value = data[key];
      return _hasMatch(value, sentenceId);
    });

    if (!matchesSentence) {
      matchesSentence = _hasMatch(data.values, sentenceId);
    }

    if (!matchesSentence &&
        sentenceGroupId != null &&
        sentenceGroupId.isNotEmpty) {
      final groupKeys = {
        'groupId',
        'group_id',
        'sentenceGroupId',
        'sentence_group_id',
      };
      matchesSentence = groupKeys.any((key) {
        final value = data[key];
        return _hasMatch(value, sentenceGroupId);
      });
      if (!matchesSentence) {
        matchesSentence = _hasMatch(data.values, sentenceGroupId);
      }
    }

    return matchesSentence;
  }

  Future<void> _ensureSentenceTasksLoaded() async {
    if (_sentenceTasksLoaded || _sentenceTasksLoading) {
      while (_sentenceTasksLoading) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      return;
    }
    _sentenceTasksLoading = true;
    try {
      const int pageSize = 100;
      String? cursor;
      while (true) {
        final queries = <String>[
          Query.equal('type', ['sentence', 'Sentence']),
          Query.limit(pageSize),
          if (cursor != null) Query.cursorAfter(cursor),
        ];
        final result = await _service.listDocumentsRaw(
          databaseId: kAppwriteDatabaseId,
          collectionId: kAppwriteTasks,
          queries: queries,
        );

        for (final doc in result.documents) {
          final task = Task.fromMap(doc.data);
          if (!_isSentenceTask(task)) continue;
          if (_sentenceTaskMap.containsKey(doc.$id)) continue;
          _sentenceTaskDocs.add(doc);
          _sentenceTaskMap[doc.$id] = task;
        }
        if (result.documents.length < pageSize) {
          break;
        }
        cursor = result.documents.last.$id;
      }
      _sentenceTasks =
          _sentenceTaskMap.values
              .where((task) => (task.languageId ?? '').isNotEmpty)
              .toList();
      _sentenceTasksLoaded = true;
    } finally {
      _sentenceTasksLoading = false;
    }
  }

  bool _hasMatch(dynamic value, String target) {
    if (value == null) return false;
    if (value is String) return value == target;
    if (value is num) return value.toString() == target;
    if (value is Map) {
      final idValue = value['\$id'] ?? value['id'];
      if (idValue is String && idValue == target) {
        return true;
      }
      if (idValue is num && idValue.toString() == target) {
        return true;
      }
      return value.values.any((entry) => _hasMatch(entry, target));
    }
    if (value is Iterable) {
      for (final item in value) {
        if (_hasMatch(item, target)) {
          return true;
        }
      }
    }
    return false;
  }

  bool _isSentenceTask(Task task) {
    final normalizedType = task.type.toLowerCase();
    return normalizedType == 'sentence' ||
        normalizedType == 'sentence_task' ||
        normalizedType == 'sentence-task' ||
        normalizedType.isEmpty;
  }
}
