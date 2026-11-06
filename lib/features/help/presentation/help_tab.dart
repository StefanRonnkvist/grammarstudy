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
            'The six top-level tabs are Games, Grammar, Structure, Sentence, Help, and Information. Try Grammar first: choose a category, review its definition and values, then open a value to see sentences that use it. Compare each example in plain and tagged form, and practise what you learned in Games.',
      ),
      (
        title: 'Games Tab',
        body:
            'Choose Crossword, Slide, or Drag from the game tabs. Games opens on Drag. Your current round and game progress are not saved between sessions.\n\n'
            '• Crossword: select a numbered grid cell and type the active word one letter at a time. A cell shared by Across and Down clues lets you choose which word to answer. Complete a word to see correct letters in green and incorrect letters in red. Clues give direction, length, and word type. Select a clue or tap its selected grid cell again to see a sentence hint and optionally reveal the word. Hint shows masked words and types for the whole puzzle. Clear Cell clears editable letters in the active word; crossing or revealed letters stay. New Puzzle generates another grid.\n\n'
            '• Slide: drag vertical letter columns until the target letters line up with the horizontal row, then select Submit. The correct-letter count shows your result; correct positions lock in place while other columns remain movable. Select the word type for its definition, Hint for a sentence example, or New Word for another round.\n\n'
            '• Drag: drag each word from the word list to its matching blank in the tagged sentence. Correct placements are confirmed by color and become fixed. Incorrect drops flash red; the word stays available to try again. Select New Sentence for another round.'
      ),
      (
        title: 'Grammar',
        body:
            'Choose a category from the inner tabs. Its definition appears above the values when available. Search filters the values as you type and ranks values that start with your search first. Select a value to open its matching sentences. Each result starts as plain text; select it to switch to the tagged structure. Your last selected category is remembered on this device.',
      ),
      (
        title: 'Structure And Sentence',
        body:
            'Structure shows the study sentences with parenthesized grammar tags. Sentence shows the same collection as plain text without tags. Search either list as you type; entries beginning with your search are ranked first.',
      ),
      (
        title: 'Information: Contact Us And Submissions',
        body:
            'Contact Us lets you send a question, correction, or suggestion. The form sends your name, return email, and message along with app diagnostics: package name, app version and build, platform, layout, orientation, and submission time. Submissions loads a remote CSV and shows entries associated with this app. Both features need an internet connection; grammar reference and games use bundled data.',
      ),
      (
        title: 'Theme And Preferences',
        body:
            'Use the palette icon in the app bar to choose System, Light, or Dark theme. Theme and the selected Grammar category are saved on this device. Game rounds and progress are not saved between sessions. On web, saved preferences and study data depend on browser storage and may be removed if site data is cleared.',
      ),
      (
        title: 'Database And Troubleshooting',
        body:
            'Select the storage icon in the app bar to open Database Diagnostics and review loaded grammar, sentence, and definition counts. If study content is missing, choose Restore and wait for the confirmation message. Native builds restore the packaged database when possible; web and native fallback recovery rebuild from the exports bundled with the app. If browser storage was cleared, reopen the app to seed the study data again.',
      ),
      (
        title: 'Offline Use And Privacy',
        body:
            'Grammar categories, definitions, sentence examples, and games are bundled with the app and work offline. Internet access is used to send Contact Us or load Submissions. Contact Us sends the information described above. The app does not include advertising or analytics packages.',
      ),
      (
        title: 'Study Tips',
        body:
            'Use Grammar to learn a category and find examples. Compare the tagged patterns in Structure with the readable examples in Sentence. Practise vocabulary with Crossword, spelling and word categories with Slide, or sentence structure with Drag.',
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
              'Grammar Study connects grammar categories, tagged structures, plain examples, and practice games. This guide explains the main controls and how the study data is used.',
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
