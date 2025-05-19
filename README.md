# Learn Languages

A Flutter mobile app for learning languages via spaced repetition (SM-2) and example sentences with audio from Tatoeba. Designed for busy learners who want micro-sessions (5–10 minutes) each day.

---

## 🚀 Features

- **Daily Study Session**: Learn up to _N_ new words per day (configurable in Settings).  
- **Review Session**: SM-2 quality ratings (Again, Hard, Good, Easy) for overdue words.  
- **Audio Examples**: Play community-recorded audio for each example sentence.  
- **Vocabulary Dashboard**: See words in three states—Learning Now, Pending, Mastered.  
- **Statistics**: Track daily progress, streaks, total and mastered words.  
- **Debug Screen**: Inspect raw SRS data and next-review dates.  
- **Prebuilt SQLite DB**: Ships with a prepopulated Spanish database for fast start.  

---

## 🛠 Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (>= 3.0)  
- Dart SDK (>= 2.17)  
- Android Studio / Xcode / device or emulator  

### Installation

1. **Clone the repository**  
   ```bash
   git clone https://github.com/yourusername/learn_languages.git
   cd learn_languages
````

2. **Download the prebuilt database**
   The `spanish_app.db` isn’t in the repo. Download it from OneDrive:

   ```
   https://1drv.ms/u/c/587a9f7bfd9b095f/ETpwstuEaUZAs9ZgfZ411sQBF9mz53iIFjPcv4EvIEVecQ?e=Nh3qKh
   ```

   and place the file at:

   ```
   assets/databases/spanish_app.db
   ```

3. **Ensure `pubspec.yaml` includes the asset**

   ```yaml
   flutter:
     assets:
       - assets/databases/spanish_app.db
   ```

4. **Fetch dependencies**

   ```bash
   flutter pub get
   ```

5. **Run on your device or emulator**

   ```bash
   flutter run
   ```

---

## 📂 Project Structure

```
lib/
├── core/                      # App-wide constants & DI setup
│   ├── constants.dart
│   └── di.dart
├── data/                      # Data layer (local repos + models)
│   ├── local/
│   │   ├── local_audio_repo.dart
│   │   ├── local_sentence_repo.dart
│   │   ├── local_srs_repo.dart
│   │   └── local_word_repo.dart
│   └── models/
│       └── word_model.dart
├── domain/                    # Domain layer (entities, repos, usecases)
│   ├── entities/
│   ├── repositories/
│   └── usecases/
├── services/                  # Business logic (LearningService, SRSService)
├── presentation/              # UI: providers, screens, widgets
│   ├── providers/
│   ├── screens/
│   └── widgets/
└── main.dart                  # App entry point
```

---

## 🏛 Architecture

* **Dependency Injection**: `get_it` registers database, repos, and services in `core/di.dart`.
* **Data Layer**: `sqflite` for local storage; FTS4 for fast sentence lookup.
* **Domain Layer**: Clean separation—entities, repository interfaces, and use cases (`GetDailyBatch`, `GetDueReviews`, `MarkLearned`).
* **Service Layer**: `LearningService` orchestrates word fetch, sentence fetch, audio fetch, and SRS scheduling.
* **Presentation Layer**:

    * `Provider` package for state management.
    * `HomeScreen`, `StudyScreen`, `ReviewScreen`, `VocabularyScreen`, `StatsScreen`, and `SettingsScreen`.
    * Reusable widgets: `Flashcard`, `PrimaryButton`, `SecondaryButton`.

---

## 🎯 Usage

1. **Home Screen**

    * View your current streak and due reviews.
    * Tap **Start Study** (disabled when daily quota reached).
2. **Study Session**

    * Learn a word, read example sentences, play audio.
    * Tap **Got it** to mark success or **Skip** to move on.
3. **Review Session**

    * Quality ratings for overdue words (0–5 scale).
4. **Vocabulary**

    * Browse words in three categories: Learning Now, Pending, Mastered.
5. **Stats**

    * See daily learned count, streak, total words, mastered count.
6. **Settings**

    * Adjust daily words count.
7. **Debug**

    * Inspect raw SRS entries for fine-tuning.

---

## 🤝 Contributing

1. Fork this repo
2. Create a feature branch (`git checkout -b feature/XYZ`)
3. Commit your changes (`git commit -m "Add XYZ"`)
4. Push to the branch (`git push origin feature/XYZ`)
5. Open a Pull Request

---

## 📝 License

This project is licensed under the **Creative Commons Attribution-NonCommercial 4.0 International (CC BY-NC 4.0)**.
You may use, share, and adapt the code **for non-commercial purposes only**. Any commercial use is strictly prohibited.
See [LICENSE](LICENSE) for full license text.

