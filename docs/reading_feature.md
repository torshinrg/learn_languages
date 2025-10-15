# Reading Feature Overview

This release introduces the first iteration of the Reading experience. It lets learners browse available materials for their active learning language, open a title, and resume from the last sentence they read.

## High-level flow

- **Library** (`ReadingLibraryScreen`) lists materials stored in Appwrite, filtered by the learner’s current language. Users can search by title, restrict to books, and see a quick resume indicator sourced from local progress.
- **Reader** (`ReaderScreen`) streams sentences ordered by `material_sentences.order`, highlights tokens based on the learner’s vocabulary status, and offers audio playback when an `audio_id` exists.
- **Word lookups** open a bottom sheet with dictionary information, inline translations powered by the hosted translator service, example sentences, and actions to mark the word as New/In progress/Known. Updates persist through the existing `IUserWordStatusRepository` implementations.
- **Progress** persists locally via `ReadingProgressStore` (SharedPreferences) and is applied automatically when reopening a material.

## Key components

| Module | Responsibility |
| --- | --- |
| `RemoteReadingMaterialRepository` | Lists reading materials by language with optional type/search filters. |
| `RemoteMaterialSentenceRepository` | Fetches ordered sentences with embedded token data per material. |
| `ReadingProgressStore` | Local persistence for `lastOrder` and timestamp per material. |
| `ReadingLibraryProvider` | Library state (filters, search, progress hydration). |
| `ReaderProvider` | Material pagination, token ↔ word/status lookups, audio playback, progress syncing. |
| `TokenizedSentence` | Simple token renderer with status-aware coloring. |
| `WordBottomSheet` | Dictionary card with translator results, example sentences, and vocabulary status controls. |

## Routing

- `/reading` → `ReadingLibraryScreen`
- `/reading/detail` → `ReaderScreen` (expects `ReaderScreenArguments` with `materialId`)

## Local progress format

Progress is stored in SharedPreferences under keys `reading_progress:<materialId>` with payload:

```json
{
  "order": <int>,
  "updatedAt": "ISO8601"
}
```

## Next steps

- Prefetch additional pages while the reader is active to smooth long materials.
- Extend word lookups to surface multiple matches and richer dictionary metadata.
- Sync reading progress to Appwrite once the remote schema is finalised.
