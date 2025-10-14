# Repository Guidelines

## Project Structure & Modules
- `lib/`: app source. Organize by features: `core/` (services, utils), `features/` (screens, widgets), `data/` (repos, models).
- `test/`: unit/widget tests mirroring `lib/` structure (`*_test.dart`).
- `assets/`: images, fonts, JSON; declare in `pubspec.yaml`.
- Root configs: `pubspec.yaml`, `analysis_options.yaml`.

## Build, Test, and Development
- Install deps: `flutter pub get`.
- Run app: `flutter run` (add `-d <device>` as needed).
- Analyze lints: `flutter analyze`.
- Format code: `dart format lib test`.
- Generate code (if used): `flutter pub run build_runner build --delete-conflicting-outputs`.
- Run tests: `flutter test`.

## Coding Style & Naming Conventions
- Dart/Flutter style, 2‑space indentation, max line length ~80; prefer trailing commas for clean diffs.
- Files: `snake_case.dart`; Classes/Enums: `PascalCase`; variables/methods: `lowerCamelCase`.
- Booleans use auxiliaries: `isLoading`, `hasError`, `canSubmit`.
- Prefer composition, functional/declarative widgets, `const` constructors, and arrow syntax for simple getters/functions.
- Keep screens structured: exported widget → private subwidgets → helpers/extensions → constants.

## Testing Guidelines
- Framework: `flutter_test`. Name files `*_test.dart` mirroring `lib/` paths.
- Scope: unit tests for services/repos and widget tests for UI; keep tests fast and deterministic.
- Mocks/Fakes: isolate external services (e.g., Appwrite) behind interfaces; inject via GetIt.
- Commands: run with `flutter test`; add `-r expanded` for verbose output.

## Commit & Pull Request Guidelines
- Use Conventional Commits: `feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`.
  - Example: `feat(auth): add email/password login with Provider`.
- PRs must include: clear description, linked issue, screenshots/recordings for UI, and a short test plan.
- Before opening PR: `dart format`, `flutter analyze`, `flutter test` all pass.

## Security & Configuration Tips
- Do not hardcode secrets. Pass runtime config via `--dart-define`.
  - Example: `flutter run --dart-define=APPWRITE_ENDPOINT=... --dart-define=APPWRITE_PROJECT_ID=...`.
- Avoid logging sensitive data; prefer `log()` over `print()`.
- Keep API/DB code in `core/services/`; handle errors explicitly and surface user‑friendly messages.

## Architecture & Migration Notes
- Status: refactoring from a fully offline app to an online app with Appwrite.
- Backend: Appwrite (Auth, Database). Collections (name → id):
  - tasks → 686dc239001f86d73af8
  - user_word_status → 686dbee10039c42a91f9
  - material_sentences → 686dbcd6002465ccf468
  - materials_types → 686daab3001d908cc80c
  - reading_materials → 686daa12002cd5d38a9a
  - word_sentence_links → 686da90c002dfb68b114
  - languages → 686da5820011a3e3cde8
  - sentences → 686c6bef001892379efa
  - words → 686c67d800103afca060
- Keep a clean separation between offline caches (e.g., `sqflite`) and online sources via repository interfaces; inject implementations with GetIt.
