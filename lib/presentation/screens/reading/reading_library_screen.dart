import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../../core/di.dart';
import '../../../data/local/reading_progress_store.dart';
import '../../../domain/entities/reading_material.dart';
import '../../../domain/repositories/i_reading_material_repository.dart';
import '../../../services/learning_service.dart';
import '../../providers/reading_library_provider.dart';
import '../../providers/settings_provider.dart';
import 'reader_screen.dart';

class ReadingLibraryScreen extends StatelessWidget {
  const ReadingLibraryScreen({super.key});

  static const routeName = '/reading';

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ReadingLibraryProvider>(
      create:
          (ctx) => ReadingLibraryProvider(
            getIt<IReadingMaterialRepository>(),
            getIt<ReadingProgressStore>(),
            getIt<LearningService>(),
            ctx.read<SettingsProvider>(),
          )..init(),
      child: const _ReadingLibraryView(),
    );
  }
}

class _ReadingLibraryView extends StatefulWidget {
  const _ReadingLibraryView();

  @override
  State<_ReadingLibraryView> createState() => _ReadingLibraryViewState();
}

class _ReadingLibraryViewState extends State<_ReadingLibraryView> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Consumer<ReadingLibraryProvider>(
      builder: (ctx, provider, _) {
        final loc = AppLocalizations.of(context)!;
        final filters = provider.availableFilters;
        return Scaffold(
          appBar: AppBar(title: Text(loc.readingTitle)),
          body: RefreshIndicator(
            onRefresh: provider.reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    labelText: loc.readingSearch,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: provider.setSearchTerm,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  children:
                      filters
                          .map(
                            (filter) => ChoiceChip(
                              label: Text(
                                filter == 'book'
                                    ? loc.readingFilterBooks
                                    : loc.readingFilterAll,
                              ),
                              selected: provider.activeFilter == filter,
                              onSelected: (_) => provider.setFilter(filter),
                            ),
                          )
                          .toList(),
                ),
                const SizedBox(height: 16),
                if (provider.isLoading && provider.materials.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                if (provider.errorMessage != null && provider.materials.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      loc.readingError,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                if (provider.materials.isEmpty &&
                    !provider.isLoading &&
                    provider.errorMessage == null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      loc.readingEmpty,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                ...provider.materials.map(
                  (material) => _ReadingMaterialTile(
                    material: material,
                    progress: provider.progressFor(material.id),
                    localization: loc,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ReadingMaterialTile extends StatelessWidget {
  const _ReadingMaterialTile({
    required this.material,
    this.progress,
    required this.localization,
  });

  final ReadingMaterial material;
  final ReadingProgressRecord? progress;
  final AppLocalizations localization;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typeName = material.typeName.toLowerCase();
    final typeLabel =
        typeName == 'book'
            ? localization.readingFilterBooks
            : (material.typeName.isEmpty ? null : material.typeName);
    final subtitleParts =
        <String?>[material.author, typeLabel]
            .where((element) => element != null && element!.isNotEmpty)
            .cast<String>()
            .toList();

    final resumeOrder = progress?.lastOrder ?? 0;
    final progressLabel =
        resumeOrder > 0
            ? localization.readingResume(resumeOrder)
            : localization.readingStart;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        title: Text(material.title),
        subtitle:
            subtitleParts.isEmpty
                ? Text(progressLabel)
                : Text('${subtitleParts.join(' • ')}\n$progressLabel'),
        isThreeLine: subtitleParts.isNotEmpty,
        trailing: Icon(Icons.chevron_right, color: theme.colorScheme.primary),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder:
                  (_) =>
                      ReaderScreen(materialId: material.id, material: material),
            ),
          );
        },
      ),
    );
  }
}
