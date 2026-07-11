import 'package:flutter/material.dart';

import 'config.dart';
import 'screens/board.dart';
import 'screens/found_intake.dart';
import 'screens/lost_intake.dart';
import 'screens/matches.dart';
import 'services/card_store.dart';
import 'services/gemma_service.dart';
import 'services/mock_gemma_service.dart';
import 'services/speech_service.dart';
import 'services/sync_service.dart';

// App-lifetime singletons (hackathon-simple, CLAUDE.md approved).
final store = CardStore();
final speech = SpeechService();
late final GemmaService gemma;
late final SyncService sync;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await store.init(); // restart-safe truth first

  // THE AI SEAM: Stage 4 flips MelaConfig.useMockAi and constructs the real
  // FlutterGemmaService here. Nothing else in the app changes.
  gemma = MockGemmaService();

  sync = SyncService(store);
  runApp(const MelaApp());

  // Heavy init AFTER first frame — never block a demo launch.
  await speech.init();
  await gemma.init();
  sync.start();
  sync.onMatchCandidate = (cardId, foundAt) {
    speech.speak('संभावित मिलान मिला। कार्ड $cardId। स्टेशन $foundAt पर।');
  };
}

class MelaApp extends StatelessWidget {
  const MelaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MELA Station',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      BoardScreen(store: store, sync: sync),
      LostIntakeScreen(gemma: gemma, speech: speech, sync: sync),
      FoundIntakeScreen(
          gemma: gemma, sync: sync, onFiled: () => setState(() => _tab = 3)),
      MatchesScreen(store: store, sync: sync),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text('MELA — Station ${MelaConfig.station}'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: screens[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Board'),
          NavigationDestination(
              icon: Icon(Icons.person_search), label: 'गुमशुदा'),
          NavigationDestination(icon: Icon(Icons.face), label: 'मिला'),
          NavigationDestination(
              icon: Icon(Icons.compare_arrows), label: 'Matches'),
        ],
      ),
    );
  }
}
