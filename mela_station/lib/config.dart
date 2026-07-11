import 'dart:io' show Platform;

/// Demo-day config. Hardcode what won't be seen (CLAUDE.md rule);
/// both values are editable from the Board screen at runtime.
class MelaConfig {
  /// Station id — "A" on the iPhone/first phone, "B" on the second.
  static String station = 'A';

  /// Hub over the demo hotspot LAN; Mac dev runs default to localhost.
  static String hubUrl =
      Platform.isMacOS ? 'ws://127.0.0.1:8765' : 'ws://192.168.43.1:8765';

  /// Flip to swap MockGemmaService -> real FlutterGemmaService (Stage 4).
  static bool useMockAi = true;

  static int _seq = 100;
  static String nextCardId() => '$station-${++_seq}';
}
