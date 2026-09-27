# Grammer Study

Grammer Study is a Flutter grammar reference and practice app. It combines categorized vocabulary, definitions, tagged sentence structures, plain examples, and three interactive games. Study content ships with the app, so reference and game features work without a continuous internet connection.

## Features

- **Games tab** - Three practice modes:
  - **Crossword:** solve generated puzzles with direction, length, word-type clues, sentence hints, immediate letter feedback, and optional word reveals.
  - **Slide:** align draggable letter columns, submit the arrangement, and lock correctly placed letters in a hidden word.
  - **Drag:** rebuild tagged sentences by moving removed words to their matching positions.
- **Grammar tab** - Browse searchable values by category, read available definitions, and open matching sentences. Each result toggles between plain and tagged text.
- **Structure tab** - Search and browse tagged sentence structures with live filtering.
- **Sentence tab** - Search and browse plain sentence examples with live filtering.
- **Help tab** - Read guidance for the main tabs, game controls, themes, and database recovery.
- **Information tab** - Send a question or correction through Contact Us and load submissions associated with this app.
- **Theme support** - System, light, and dark modes saved locally.
- **Assets DB diagnostics** - Inspect loaded data counts and restore bundled database content.
- **Local study data** - Native builds restore from a bundled Hive database when possible; every platform can rebuild the same content from bundled exports.
- **Responsive layout** - Game layouts adapt for phones, tablets, and larger screens.

## Platforms

Flutter runner projects are configured for Android, iOS, web, Windows, Linux, and macOS. The repository includes release build tasks for Android APK/App Bundle, web, Windows, and Windows MSIX.

## Package

`com.stefanronnkvist.paid.grammarstudy`

## Version

`1.0.38+40`

## Google Play Listing

Store listing copy is maintained in:

- [store_listing/google_play_short_synopsis.txt](store_listing/google_play_short_synopsis.txt) - maximum 80 characters
- [store_listing/google_play_long_synopsis.txt](store_listing/google_play_long_synopsis.txt) - maximum 4,000 characters

- Short synopsis (80-character limit):
  Explore grammar in real sentences and practice with three interactive games.

- Long synopsis highlights:
  - Searchable grammar categories with definitions and matching sentence examples.
  - Tagged Structure and plain Sentence reference views.
  - Crossword, Slide, and Drag practice modes with contextual hints.
  - Offline study content, theme options, responsive layouts, and database recovery tools.

## Build

```powershell
flutter pub get
flutter build apk --release
flutter build appbundle --release
flutter build web --release
flutter build windows --release
dart run msix:create --build-windows=false
```

On Windows, `scripts/build-release.ps1` builds a versioned APK, App Bundle, or MSIX from the version in `pubspec.yaml`:

```powershell
.\scripts\build-release.ps1 -Target apk
.\scripts\build-release.ps1 -Target appbundle
.\scripts\build-release.ps1 -Target msix
```

## Data Workflow

1. Runtime-ready source exports are stored in [assets/db_exports](assets/db_exports):
	- [assets/db_exports/word_type_categories_with_associated_words.json](assets/db_exports/word_type_categories_with_associated_words.json)
	- [assets/db_exports/word_type_definitions.json](assets/db_exports/word_type_definitions.json)
	- [assets/db_exports/sentences_with_word_type.txt](assets/db_exports/sentences_with_word_type.txt)
	- [assets/db_exports/sentences_without_word_type.txt](assets/db_exports/sentences_without_word_type.txt)
2. The bundled native snapshot is stored at [assets/prebuilt_db/assets_database_v1.hive](assets/prebuilt_db/assets_database_v1.hive).
3. At startup, the app opens Hive and checks the schema version. Native platforms prefer the prebuilt snapshot; web and native fallback recovery seed Hive from the exports.
4. The storage icon opens diagnostics for loaded counts and can restore the bundled content. Web data uses browser storage and may be removed when site data is cleared.

## Assets

Runtime/build assets currently used:

- `assets/db_exports/word_type_categories_with_associated_words.json` — grammar categories and values
- `assets/db_exports/word_type_definitions.json` — word-type definitions
- `assets/db_exports/sentences_with_word_type.txt` — tagged sentence structures
- `assets/db_exports/sentences_without_word_type.txt` — plain sentence examples
- `assets/prebuilt_db/assets_database_v1.hive` — bundled prebuilt Hive database used for restore/seed

## Connectivity And Data

- Grammar content, preferences, and game data are stored locally. On web, persistence depends on browser storage.
- Contact Us sends the entered name, email, and question together with package, version, build, platform, layout, orientation, and submission time diagnostics to the configured contact endpoint.
- Submissions downloads the app's submissions CSV and filters it for the current package.
- No analytics or advertising dependencies are included.

## Developer

Stefan Ronnkvist
