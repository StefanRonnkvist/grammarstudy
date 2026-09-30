# Grammar Study

Grammar Study is a Flutter grammar reference and practice app. It combines categorized vocabulary, definitions, tagged sentence structures, plain examples, and three interactive games. Study content ships with the app, so reference and game features work without a continuous internet connection.

## Features

- **Games tab** - Three practice modes (opens on Drag):
  - **Crossword:** solve generated puzzles with direction, length, word-type clues, sentence hints, immediate letter feedback, and optional word reveals.
  - **Slide:** align draggable letter columns, submit the arrangement, and lock correctly placed letters in a hidden word.
  - **Drag:** rebuild tagged sentences by moving removed words to their matching positions.
- **Grammar tab** - Browse searchable values by category, read available definitions, and open matching sentences. Each result toggles between plain and tagged text.
- **Structure tab** - Search and browse tagged sentence structures with live filtering.
- **Sentence tab** - Search and browse plain sentence examples with live filtering.
- **Help tab** - Read guidance for the six top tabs, game controls, themes, database recovery, and offline/privacy behaviour.
- **Information tab** - Send a question or correction through Contact Us and review this app's submissions.
- **Theme support** - System, light, and dark modes saved locally.
- **DB diagnostics** - Inspect loaded data counts and restore bundled database content.
- **Local study data** - Native builds restore from a bundled Hive database when possible; every platform can rebuild the same content from bundled exports.
- **Responsive layout** - Game layouts adapt for phones, tablets, and larger screens.

## Platforms

Flutter runner projects are configured for Android, iOS, web, Windows, Linux, and macOS. The repository includes release build tasks for Android APK/App Bundle, web, Windows, and Windows MSIX.

## Package

`com.stefanronnkvist.paid.grammarstudy`

## Version

`1.0.43+45`

## Google Play Listing

Store listing copy is maintained in:

- [store_listing/google_play_short_synopsis.txt](store_listing/google_play_short_synopsis.txt) - maximum 80 characters
- [store_listing/google_play_long_synopsis.txt](store_listing/google_play_long_synopsis.txt) - maximum 4,000 characters

- Short synopsis (80-character limit):
  Explore grammar in real sentences and practice with three interactive games.

- Long synopsis highlights:
  - Grammar categories with definitions, searchable values, and matching sentences.
  - Structure tab for tagged sentences and Sentence tab for plain examples.
  - Crossword, Slide, and Drag practice modes with contextual hints.
  - Offline study content, theme options, responsive layouts, and database recovery tools.
  - Contact Us and Submissions for questions and app-specific feedback.

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

## Project Structure

Code is organised into four layers so that features stay independent.

```
lib/
  main.dart                 Entry point and startup gate
  app/
    bootstrap/              Database startup and failure recovery
    home/                   App bar, top tabs, and tab routing
    theme/                  Light and dark theme construction
  core/                     Shared, feature-agnostic helpers
    layout/                 Responsive breakpoints and text measurement
    search/                 Prefix-ranked filtering and sorting
    text/                   Normalization and word matching
    widgets/                Reusable status, search, and dialog views
  data/                     Study database access and schema
  features/
    games/                  crossword | slide | drag, each with domain + presentation
    grammar/                Category browsing and value-to-sentence dialogs
    structure/              Tagged sentence reference
    sentence/               Plain sentence reference
    help/                   In-app guidance
    information/            Contact and submissions grouping
    contact/                Support form, submissions list, and CSV parsing
```

Each feature splits into `domain/` (pure logic and models, no Flutter
dependency beyond types) and `presentation/` (widgets). Game rules live in
`domain/` so they can be tested without a widget tree.

## Tests

Game rules, text normalization, and search behaviour are covered by unit tests
that run without a widget tree:

```powershell
flutter test
```

| Suite | Covers |
| --- | --- |
| `test/core/text_and_search_test.dart` | Normalization, word matching, tag stripping, prefix-ranked search |
| `test/data/study_database_service_test.dart` | Seeding from bundled exports, schema versioning, summary counts |
| `test/features/games/crossword/` | Placement rules, puzzle generation, cell navigation, widget behaviour |
| `test/features/games/slide/` | Board generation, alignment evaluation, drag and snap behaviour |
| `test/features/games/drag/` | Sentence tokenizing, round building, drop matching |
| `test/features/contact/` | Submissions CSV parsing, package filtering, contact form validation and URL rules |
| `test/app/home_screen_test.dart` | Tab routing, theme menu, database diagnostics, tab panes |

Widget tests that render data-driven tabs use `test/helpers/test_database.dart`,
which seeds a temporary Hive database from the bundled exports so tests never
depend on a previously built one.

When changing a rule in a `domain/` folder, update the matching suite so the
behaviour stays pinned.

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
