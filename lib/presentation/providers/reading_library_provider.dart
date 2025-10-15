import 'package:flutter/foundation.dart';

import '../../data/local/reading_progress_store.dart';
import '../../domain/entities/reading_material.dart';
import '../../domain/repositories/i_reading_material_repository.dart';
import '../../services/learning_service.dart';
import 'settings_provider.dart';

class ReadingLibraryProvider extends ChangeNotifier {
  ReadingLibraryProvider(
    this._materialsRepository,
    this._progressStore,
    this._learningService,
    this._settingsProvider,
  ) {
    _settingsProvider.addListener(_handleSettingsChanged);
  }

  final IReadingMaterialRepository _materialsRepository;
  final ReadingProgressStore _progressStore;
  final LearningService _learningService;
  final SettingsProvider _settingsProvider;

  final List<ReadingMaterial> _materials = [];
  final List<ReadingMaterial> _visibleMaterials = [];
  Map<String, ReadingProgressRecord> _progressByMaterial = {};

  bool _isLoading = false;
  bool _initialized = false;
  String? _currentLanguageId;
  String? _errorMessage;
  String _activeFilter = _Filters.all;
  String _searchTerm = '';

  List<ReadingMaterial> get materials => List.unmodifiable(_visibleMaterials);
  bool get isLoading => _isLoading;
  bool get isInitialized => _initialized;
  String? get errorMessage => _errorMessage;
  String get activeFilter => _activeFilter;
  String get searchTerm => _searchTerm;
  List<String> get availableFilters => const [_Filters.all, _Filters.book];
  String? get currentLanguageId => _currentLanguageId;

  ReadingProgressRecord? progressFor(String materialId) =>
      _progressByMaterial[materialId];

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await reload();
  }

  Future<void> reload() async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final code =
          _settingsProvider.learningLanguageCodes.isNotEmpty
              ? _settingsProvider.learningLanguageCodes.first
              : null;
      if (code == null) {
        _materials..clear();
        _visibleMaterials..clear();
        _progressByMaterial = {};
        _setLoading(false);
        return;
      }

      final languageId = await _learningService.resolveLanguageId(code);
      _currentLanguageId = languageId;
      if (languageId == null) {
        _materials..clear();
        _visibleMaterials..clear();
        _progressByMaterial = {};
        _errorMessage = 'missing_language_id';
        _setLoading(false);
        return;
      }

      final materials = await _materialsRepository.listByLanguage(languageId);
      _materials
        ..clear()
        ..addAll(materials);

      await _refreshProgress();
      _applyFilters();
    } catch (e) {
      _errorMessage = e.toString();
      _materials.clear();
      _visibleMaterials.clear();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> refreshProgressOnly() async {
    await _refreshProgress();
    _applyFilters();
    notifyListeners();
  }

  void setFilter(String filter) {
    if (_activeFilter == filter) return;
    _activeFilter = filter;
    _applyFilters();
    notifyListeners();
  }

  void setSearchTerm(String value) {
    final normalized = value.trim();
    if (_searchTerm == normalized) return;
    _searchTerm = normalized;
    _applyFilters();
    notifyListeners();
  }

  @override
  void dispose() {
    _settingsProvider.removeListener(_handleSettingsChanged);
    super.dispose();
  }

  Future<void> _refreshProgress() async {
    _progressByMaterial = await _progressStore.allProgress();
  }

  void _applyFilters() {
    _visibleMaterials
      ..clear()
      ..addAll(_materials.where(_matchesFilters));
  }

  bool _matchesFilters(ReadingMaterial material) {
    if (_activeFilter == _Filters.book) {
      if (material.typeName.toLowerCase() != 'book') {
        return false;
      }
    }

    if (_searchTerm.isEmpty) return true;
    return material.title.toLowerCase().contains(_searchTerm.toLowerCase());
  }

  void _handleSettingsChanged() {
    if (!_initialized) return;
    // When active language changes, reload materials.
    reload();
  }

  void _setLoading(bool value) {
    if (_isLoading == value) return;
    _isLoading = value;
    notifyListeners();
  }
}

class _Filters {
  static const all = 'all';
  static const book = 'book';
}
