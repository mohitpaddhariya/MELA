import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';
import 'package:path_provider/path_provider.dart';

import 'config.dart';
import 'screens/board.dart';
import 'screens/found_intake.dart';
import 'screens/lost_intake.dart';
import 'screens/matches.dart';
import 'services/card_store.dart';
import 'services/flutter_gemma_service.dart';
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
  // Register the LiteRT-LM engine (1.x API) — must happen before any
  // FlutterGemma call. try/catch survives hot-restart double-init.
  try {
    FlutterGemma.initialize(inferenceEngines: const [LiteRtLmEngine()]);
  } catch (_) {}
  await store.init(); // restart-safe truth first
  // A revived station must come back as ITSELF (station id + hub IP).
  MelaConfig.station = store.getSetting('station') ?? MelaConfig.station;
  MelaConfig.hubUrl = store.getSetting('hubUrl') ?? MelaConfig.hubUrl;
  // Brain default: REAL Gemma whenever the model file is present (all
  // platforms). Init failure degrades to mock inside FlutterGemmaService —
  // the app can no longer crash from a bad model load. The persisted Board
  // toggle always wins if the user set it explicitly.
  if (Platform.isAndroid) {
    // Creates Android/data/<pkg>/files as APP-OWNED (shell-made dirs are
    // invisible to the app). Model gets adb-pushed here after first run.
    final ext = await getExternalStorageDirectory();
    if (ext != null) {
      FlutterGemmaService.androidExternalModelPath =
          '${ext.path}/gemma-4-E2B-it.litertlm';
    }
  }
  final mockSetting = store.getSetting('useMockAi');
  final modelPresent =
      FlutterGemmaService.sideloadPaths.any((p) => File(p).existsSync());
  for (final p in FlutterGemmaService.sideloadPaths) {
    debugPrint('MELA brain probe: $p -> ${File(p).existsSync()}');
  }
  MelaConfig.useMockAi =
      mockSetting != null ? mockSetting != 'false' : !modelPresent;
  debugPrint('MELA brain: useMockAi=${MelaConfig.useMockAi} '
      '(setting=$mockSetting, modelPresent=$modelPresent)');

  // THE AI SEAM: flip MelaConfig.useMockAi=false for the real on-device brain.
  gemma = MelaConfig.useMockAi ? MockGemmaService() : FlutterGemmaService();

  // Sync + chirp are wired and running BEFORE any heavy init: a slow or
  // failed model load must never kill the resync/chirp demo beats.
  sync = SyncService(store);
  sync.onMatchCandidate = (cardId, foundAt) {
    speech.speak('संभावित मिलान मिला। कार्ड $cardId। स्टेशन $foundAt पर।');
  };
  sync.start();

  runApp(const MelaApp());

  // Heavy init AFTER first frame, independently — errors stay local.
  unawaited(speech.init().catchError((e) => debugPrint('speech init: $e')));
  unawaited(gemma.init().catchError((e) => debugPrint('gemma init: $e')));
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
      BoardScreen(store: store, sync: sync, gemma: gemma),
      LostIntakeScreen(gemma: gemma, speech: speech, sync: sync),
      FoundIntakeScreen(
          gemma: gemma,
          speech: speech,
          sync: sync,
          onFiled: () => setState(() => _tab = 3)),
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
