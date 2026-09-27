import 'package:flutter/material.dart';

/// Presents static guidance for every study area and recovery control.
class HelpTab extends StatelessWidget {
  const HelpTab({super.key});

  @override
  Widget build(BuildContext context) {
    final sections = <({String title, String body})>[
      (
        title: 'Getting Started',
        body:
            'Use the top tabs to move between Games, Grammar, Structure, Sentence, Help, and Information. A useful study path is to choose a category in Grammar, open a few examples, compare their plain and tagged forms, and then practice in Games.',
      ),
      (
        title: 'Games Tab',
        body:
            'Choose Crossword, Slide, or Drag from the inner tabs. Games opens on Drag.\n\n'
            '• Crossword: select a numbered cell and type one letter. Correct entries appear green and incorrect entries red. The clue list gives the direction, length, and word type. Select a clue, or select the same grid cell twice, for a sentence hint and the option to reveal that word. Hint summarizes all words in the puzzle, Clear Cell removes the selected entry, and New Puzzle starts over.\n\n'
            '• Slide: drag each vertical letter column until one letter lines up with the horizontal target row, then select Submit. Correct positions remain revealed while the other columns stay movable. Select the underlined word type for its definition, use Hint for a sentence containing the answer, or select New Word for another round.\n\n'
            '• Drag: move each word from the word list to the matching blank in the tagged sentence. Matching colors confirm a correct placement. An incorrect drop flashes red and leaves the word available to try again. Select New Sentence for another round.',
      ),
      (
        title: 'Grammar Tab',
        body:
            'Choose a grammar category with the inner tabs. Its definition appears above the values when available, and the last selected category is remembered. Search matches anywhere in a value and places results that begin with your search first. Select an underlined value to open matching sentences. Each result starts as plain text; select it to toggle the tagged structure.',
      ),
      (
        title: 'Structure Tab',
        body:
            'Browse sentences with parenthesized grammar tags that identify their structure. Search filters and sorts the entries as you type.',
      ),
      (
        title: 'Sentence Tab',
        body:
            'Browse the same study material as plain sentences without grammar tags. Search filters and sorts the examples as you type.',
      ),
      (
        title: 'Information Tab',
        body:
            'Use Contact Us to send a question, correction, or suggestion. The form sends your name, return email, and message together with app and device details such as package, version, platform, layout, and submission time. Submissions downloads and displays entries associated with this app. Both views require an internet connection; study and game features use bundled data.',
      ),
      (
        title: 'Theme And Preferences',
        body:
            'Use the palette icon in the app bar to switch between System, Light, and Dark themes. Theme and selected grammar category preferences are saved on this device. Web preferences depend on browser storage.',
      ),
      (
        title: 'Database And Troubleshooting',
        body:
            'Use the storage icon in the app bar to open Assets DB Diagnostics and review the loaded grammar, sentence, and definition counts. If content is missing, select Restore and wait for confirmation. Native builds first restore the packaged database; web builds and native fallback recovery rebuild it from bundled exports. Web data and preferences use browser storage and can be removed when browser site data is cleared.',
      ),
      (
        title: 'Offline Use And Privacy',
        body:
            'Grammar categories, definitions, sentence collections, and games are bundled with the app and do not need a continuous internet connection. Network access is used only when you submit the Contact Us form or open Submissions. The app does not include advertising or analytics packages.',
      ),
      (
        title: 'Learning Tips',
        body:
            'Start in Grammar to learn a category and open examples. Use Structure to study annotated patterns and Sentence to focus on natural wording. Finish with Crossword for vocabulary recall, Slide for spelling and category cues, or Drag for sentence reconstruction.',
      ),
    ];

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Help', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Grammer Study connects grammar categories, tagged structures, plain examples, and practice games. This guide explains the main controls and how the study data is used.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            for (final section in sections) ...[
              _buildSection(title: section.title, content: section.body),
              const SizedBox(height: 18),
            ],
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required String content}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(content, style: const TextStyle(fontSize: 14, height: 1.6)),
      ],
    );
  }
}
