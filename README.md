# Learn Languages

Learn Languages is a cross‑platform Flutter application for practicing new languages through spaced repetition, pronunciation exercises and daily reminders. The project is set up for Android, iOS, web, macOS, Linux and Windows.

## Features

- Vocabulary and sentence practice using spaced repetition
- Speech recognition and pronunciation scoring
- Custom words and sentences
- Daily study reminders and streak tracking
- Localization for English, Spanish, Russian, German, French, Italian and Portuguese

## Repository Structure

- `lib/` – main application code
- `assets/` – bundled databases, models and icons

## Environment Configuration

Runtime secrets and API endpoints are provided through the root `.env` file. Add the following keys before running the app locally:

- `APPWRITE_ENDPOINT` / `APPWRITE_PROJECT_ID` – existing Appwrite configuration.
- `TRANSLATOR_BASE_URL` – base URL of the LibreTranslate-compatible server (`https://…`).
- `TRANSLATOR_API_KEY` – optional bearer/API key for the translator (leave empty for public instances).

The app logs a warning when the translator key is missing and disables translations entirely when the base URL is not set.

## License
This project is licensed under the Creative Commons Attribution-NonCommercial 4.0 International License. See [LICENSE](LICENSE) for details.
