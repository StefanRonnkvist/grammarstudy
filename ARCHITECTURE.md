# Grammar Study — Architecture & Logic Map

Flutter study app: local (Hive) grammar database + 6 top-level study areas + 3 mini-games
+ a contact/submissions module. No server state; everything is seeded from bundled assets.

---

## 1. Layer model

```
lib/
├── main.dart                    Entry point + bootstrap state machine
├── app/                         App shell (MaterialApp, theme, tabs)
├── core/                        Cross-cutting pure utilities & shared widgets
├── data/                        Persistence: schema + Hive-backed repository
└── features/                    Vertical slices (domain/ + presentation/)
```

Dependency direction (strict, one-way):

```
main → app → features → data → (Hive/assets)
                 ↘ core   (imported by everyone; imports nobody internal)
```

* `core/` never imports `app/`, `data/` or `features/`.
* `features/` never imports `app/`.
* `app/` is the only place that knows about `MaterialApp` composition.

---

## 2. Startup / bootstrap flow (`lib/main.dart`)

`main()` → `WidgetsFlutterBinding.ensureInitialized()` → `runApp(AppBootstrap())`.

`AppBootstrap` is a 3-state machine, resolved in `build()`:

| State | Condition | Rendered widget |
|---|---|---|
| error | `_startupError != null` | `DatabaseLoadErrorApp` |
| ready | `_isReady == true` | `MainApp` |
| loading | default | `MaterialApp(home: SplashScreen())` |

`_initializeApp()` runs in `initState` and awaits **both** futures in parallel:

```dart
Future.wait([
  initializeStudyDatabase(),                       // data/bootstrap
  Future.delayed(Duration(milliseconds: 1800)),   // min splash time
]);
```

Design notes:
* Splash duration is a *floor*, not a timeout — the DB always wins when it is slow.
* Errors are both reported to `FlutterError.reportError` (observability) and captured
  into state (user-facing recovery UI).
* All `setState` calls are guarded by `mounted`.
* Error branch is checked **before** the ready branch, so a late error can never be masked.

---

## 3. Database bootstrap (`app/bootstrap/database_bootstrap.dart`)

`initializeStudyDatabase()` branches on platform:

* **Web** (`kIsWeb`): `Hive.initFlutter()` → seed from assets.
* **Native**:
  1. `getApplicationSupportDirectory()`
  2. `_migrateLegacyHiveBoxIfNeeded(...)` — best-effort copy of
     `words_database_v2.hive` from Documents → Application Support.
     *skipped if dirs are equal, source missing, or destination already present;
     all exceptions swallowed* (assets can always re-seed).
  3. `Hive.initFlutter(appSupportDirectory.path)`
  4. seed from assets.

---

## 4. Data layer (`lib/data/`)

### 4.1 `study_database_schema.dart` — the single source of truth
Box name `assets_database_v1`, six data keys, plus asset paths. `schemaVersion = 1`
is the contract: **bump it whenever the stored shape changes**; startup then
auto-replaces stale data.

### 4.2 `study_database_service.dart` — `StudyDatabaseService`

Restore priority (same for `initializeFromAssetsIfNeeded` and `restoreBundledDatabase`):

```
forceRefresh?  → restoreBundledDatabase()
version == current? → no-op            (keeps user data)
   ↓ otherwise
1. _restoreFromPrebuiltAsset   native only: copy bundled .hive over active file,
                               reopen, verify schemaVersion  → bool
2. _seedBoxFromSourceAssets    fallback: parse text/JSON exports → put() in box
```

Key invariants:
* `_seedBoxFromSourceAssets` writes the schema-version key **last**, so a seed
  interrupted midway can never be mistaken for a complete database.
* Prebuilt restore is validated by re-reading `__schema_version__` after reopen.
* Every read goes through defensive casters (`_readStringList`, `_readStringListMap`,
  `_readStringMap`) — Hive values are `dynamic`, so malformed data degrades to
  empty rather than crashing.
* `_flattenUniqueValues` dedupes case-insensitively while preserving first-seen spelling.
* `_loadStringMapAsset` lower-cases definition keys for lookup.
* If definitions are missing, a placeholder is synthesised per grammar type.
* `readSummary()` returns an immutable `StudyDatabaseSummary` of record counts,
  used by the diagnostics dialog.

---

## 5. App shell (`lib/app/`)

```
main_app.dart
  ThemeController (ChangeNotifier)  ← SharedPreferences key "theme_mode"
  MainApp (StatefulWidget)          ← ListenableBuilder → MaterialApp(theme/darkTheme)
      └─ HomeScreen
```

* Theme is *optimistically applied then persisted*: `setThemeMode` notifies first,
  awaits `SharedPreferences` write after.
* Unknown/missing stored values fall back to `ThemeMode.system`.
* `buildAppTheme(brightness)` = Material 3 from a single blue seed colour.

`home_screen.dart`
* `DefaultTabController(length: homeTabLabels.length)` + `TabBarView`.
* `TabBar.isScrollable` decided by `shouldUseScrollableTabs(context, labels, maxWidth)`
  inside a `LayoutBuilder` (text-measurement based, not a magic breakpoint).
* AppBar actions: **DB diagnostics** dialog (counts + "Restore bundled data"),
  **theme** `PopupMenuButton`.
* Body = `WebStorageNotice` (web-only, session-dismissible banner) + `HomeTabView`.

`home_tabs.dart` — ordered label list; `home_tab_view.dart` — matching widget list
(order must stay in sync).

---

## 6. Core (`lib/core/`) — shared, feature-agnostic

| Area | File | Responsibility |
|---|---|---|
| layout | `responsive.dart` | `wideLayoutBreakpoint = 900`, `isWideLayout`, tab scrollability heuristics |
| layout | `text_measurement.dart` | `fitFontSizeToWidth`, `halfTextStyle`, `readableTextColorOn`, `buildHighlightedSpan` (search highlight rendering) |
| search | `search_filter.dart` | `filterAndSortItems` — case-insensitive contains + stable sort |
| text | `text_utils.dart` | whitespace/case normalisation, `buildWordPattern`, `containsWholeWord`, `findSentenceForWord`, `stripGrammarTags` |
| widgets | `searchable_collection_view.dart` | reusable async-list + search scaffold (loading / error+retry / empty / no-matches) |
| widgets | `status_views.dart` | `LoadingView`, `ErrorRetryView`, `EmptyStateView`, `SearchField`, `NumberedListTile`, `RichNumberedListTile` |
| widgets | `dialog_views.dart` | `showWordTypeDefinitionDialog`, `showMessageDialog` |

Grammar-tag conventions used app-wide (see `text_utils.dart`):
tags are parenthesised, e.g. `This (det) is (vb) ...`; `normalizeTagWord` uppercases,
`stripGrammarTags` removes them, `findSentenceForWord` locates an example sentence.

---

## 7. Features (`lib/features/`) — vertical slices

Each slice: `domain/` (pure Dart, no Flutter) + `presentation/` (widgets).

### 7.1 games/ — hub + 3 games
* `presentation/games_tab.dart` — loads all three data sets once into an immutable
  `GameData` (single `FutureBuilder`, one reload path), then renders chooser → game.
* **crossword** (`domain/`):
  * `crossword_models.dart` — 13×13 grid, target 6 words, 40 generation attempts;
    `CrosswordCandidate`, `CrosswordPlacedWord` (`directionLabel`), `CrosswordPuzzle` (`wordById`).
  * `crossword_generator.dart` — `buildCrosswordCandidates` → shuffle → `_buildPuzzle`:
    `canPlaceWord` (bounds + adjacency + per-direction letter match), `countIntersections`
    (prefer ≥2 crossings for a connected grid), `placeWord`, `cellKey`/`parseCellKey`.
    Returns `null` on failure → regenerate.
  * `crossword_navigation.dart` — cell traversal: `nextCellInWord`,
    `nextFilledCellRowMajor`, `nextCellKeyAfterEntry`; clue numbering
    (`buildClueNumbersByCell`, `buildStartNumberByWordId`); validation
    `isWordCorrectlyAnswered`, `hiddenWordPattern`.
* **drag** (`domain/`):
  * `drag_models.dart` — `DragSentenceToken`, `DragRound(sentence, removedWords)`,
    `DragWordPayload`, colour palette.
  * `drag_logic.dart` — `parseDragSentenceTokens` (words vs. punctuation-only tokens),
    `buildDragRound`, `buildRandomDragRound`, `isDragTokenCorrect`.
* **slide** (`domain/`):
  * `slide_models.dart` — `SlideVerticalWord` (mutable letter stack, `word` getter),
    `SlideBoard` (`hasWord`, `isSolved`).
  * `slide_logic.dart` — `generateSlideBoard`, `letterInsideTargetSquare`,
    `evaluateSlideBoard` (column → word when ≥2 letters), `clearSlideSubmission`,
    `snapSlideColumn`, `dragSlideColumn`, plus `columnAt`,
    `longestColumnAbove` / `longestColumnBelow` (grid-fit constraints).

### 7.2 grammar/ — the deepest tab
* `presentation/grammar_tab.dart` — loads word-type definitions + categories
  (DropdownButton), persists the selected category in `SharedPreferences`
  (`_restoreSelectedCategory` / `_persistSelectedCategory`), shows a
  `_CategoryDefinitionCard`, and `_showValueMatches` opens the list of words for a value.
* `presentation/grammar_value_dialog.dart` — value-match list.

### 7.3 structure/ & sentence/ — thin data views
Both delegate to `SearchableCollectionView`; they differ only in the repository call
and the copy:
* structure → `readDictionarySentencesContextTagged()` (tags retained)
* sentence → `readDictionarySentencesSource()` (tags stripped)

### 7.4 help/ — static documentation sections (`_buildSection`).

### 7.5 information/ — static page + `package_info_plus` (version/platform), disposed in `dispose()`.

### 7.6 contact/ — the only network module
* `domain/contact_rules.dart` — validation (name ≥2, question ≥5, email regex),
  `formatArtifactVersion`, `contactLayoutName(width)`.
* `domain/contact_response.dart` — response summary, error message, 200-char body cap.
* `domain/submissions_csv.dart` — RFC-style CSV parser (`parseSubmissionsCsv` with
  quoted-field/escaped-quote support), `buildSubmissionsTable`, fixed headers.
* `presentation/contact_page.dart` — form + HTTP POST (`_sendContactRequest`),
  progress state, server response rendering, disposal of the debounce controller.
* `presentation/submissions_csv_page.dart` — loads a CSV asset, renders as a wide
  table or stacked cards depending on width (`SubmissionsCsvCardsView`).

---

## 8. Cross-cutting patterns

| Pattern | Where |
|---|---|
| Async state without a state-management package | `StatefulWidget` + `FutureBuilder` + `ErrorRetryView` |
| `Future.wait` to overlap independent work | bootstrap |
| Repository-as-factory (`futureFactory`) | `SearchableCollectionView`, so every list view is 15 lines |
| Defensive parsing at boundaries | asset loaders and Hive readers |
| Schema-version gate instead of migration code | data layer |
| Best-effort recovery, silent fallback | legacy Hive migration, prebuilt restore |
| `mounted` guards on every async `setState` | all stateful widgets |

---

## 9. Runtime data flow (request/response)

```
Widget (tab)
  └─ StudyDatabaseService().readX()
       └─ Hive.openBox('assets_database_v1')  ← already seeded at startup
            └─ FutureBuilder → list / error
                 └─ SearchableCollectionView → filterAndSortItems → NumberedListTile
```

Writes to storage are limited to: Hive box (startup/restore only) and
`SharedPreferences` (`theme_mode`, grammar category selection).

---

## 10. Invariants worth preserving when refactoring

1. Tab order in `home_tabs.dart` must match the widget order in `home_tab_view.dart`.
2. Bump `StudyDatabaseSchema.schemaVersion` on any stored-shape change.
3. Keep the schema key written last in `_seedBoxFromSourceAssets`.
4. Never let `core/` import `app/`, `data/` or `features/`.
5. Domain logic stays Flutter-free and unit-testable (all `*_logic.dart` / `*_models.dart`).
6. The splash is a minimum duration, not a load timeout.
