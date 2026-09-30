import 'package:flutter/material.dart';

import '../../contact/presentation/contact_page.dart';
import '../../contact/presentation/submissions_csv_page.dart';

/// Groups the support form and this application's remote submissions.
class InformationTab extends StatefulWidget {
  const InformationTab({super.key});

  @override
  State<InformationTab> createState() => _InformationTabState();
}

class _InformationTabState extends State<InformationTab>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Contact Us'),
            Tab(text: 'Submissions'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // The tab already provides scrolling, so the page must not add
              // its own Scaffold or the nested layout gets an unbounded height.
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: createContactPage(
                  serverUrl: 'https://stefanronnkvist.com/contact.php',
                  wrapInScaffold: false,
                ),
              ),
              const SubmissionsCsvCardsView(),
            ],
          ),
        ),
      ],
    );
  }
}
