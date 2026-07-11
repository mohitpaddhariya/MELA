# MELA Cheat Sheet — Sync/Storage/Camera/Permissions (verified 2026-07-11)

## Install (pubspec.yaml — verified latest on pub.dev)
```yaml
dependencies:
  web_socket_channel: ^3.0.3
  hive: ^2.2.3            # NOT hive_ce; hive_flutter needs hive ^2.x
  hive_flutter: ^1.1.0
  path_provider: ^2.1.6
  image_picker: ^1.2.3
```
Node relay: `npm init -y && npm i ws` (ws 8.21.0). Laptop LAN IP on macOS: `ipconfig getifaddr en0`.

## 1) WebSocket client + MANUAL reconnect (package does NOT auto-reconnect)
```dart
import 'dart:async'; import 'dart:convert'; import 'dart:math';
import 'package:web_socket_channel/web_socket_channel.dart';

class SyncClient {
  final Uri url = Uri.parse('ws://192.168.1.10:8080'); // laptop LAN IP
  WebSocketChannel? _ch; int _attempt = 0; bool _closed = false;
  void Function(Map<String, dynamic>)? onMessage;

  Future<void> connect() async {
    if (_closed) return;
    try {
      _ch = WebSocketChannel.connect(url);
      await _ch!.ready;                       // throws SocketException or WebSocketChannelException on failure
      _attempt = 0;
      _ch!.stream.listen(
        (msg) => onMessage?.call(jsonDecode(msg as String)),
        onDone: _scheduleReconnect,           // server died / socket closed
        onError: (e) => _scheduleReconnect(), // ALWAYS handle or app crashes
        cancelOnError: true,
      );
    } catch (_) { _scheduleReconnect(); }
  }
  void _scheduleReconnect() {
    if (_closed) return;
    final delay = Duration(milliseconds: min(30000, 500 * pow(2, _attempt++).toInt()));
    Timer(delay, connect);
  }
  void send(Map<String, dynamic> m) => _ch?.sink.add(jsonEncode(m));
  void dispose() { _closed = true; _ch?.sink.close(); }
}
```

## 2) Hive — plain JSON strings, no codegen
```dart
import 'package:hive_flutter/hive_flutter.dart';
Future<Box<String>> initDb() async {
  await Hive.initFlutter();                  // uses path_provider internally — no manual path needed
  return Hive.openBox<String>('cards');
}
// write (await it! writes are async; unawaited writes can be lost on kill):
await box.put(card['id'] as String, jsonEncode(card));
await box.flush();                           // force fsync before demo-critical moments
// read all:
final cards = box.values.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();
```
Hive keeps data in memory + appends to file; app kill loses only un-awaited writes. `Hive.close()` not needed for demo.

## 3) image_picker
```dart
final picker = ImagePicker();
final XFile? shot = await picker.pickImage(source: ImageSource.camera,  maxWidth: 1024, imageQuality: 80);
final XFile? pick = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1024, imageQuality: 80);
if (shot != null) { final bytes = await shot.readAsBytes(); }
```

## Platform config — copy exactly
**ios/Runner/Info.plist** (inside top-level `<dict>`):
```xml
<key>NSCameraUsageDescription</key><string>Take photos of found items</string>
<key>NSPhotoLibraryUsageDescription</key><string>Pick item photos</string>
<key>NSMicrophoneUsageDescription</key><string>Video capture</string>
<key>NSLocalNetworkUsageDescription</key><string>Sync lost-and-found cards over local network</string>
<key>NSBonjourServices</key><array><string>_dartVmService._tcp</string></array>
<key>NSAppTransportSecurity</key><dict><key>NSAllowsArbitraryLoads</key><true/></dict>
```
**android/app/src/main/AndroidManifest.xml**:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<application android:usesCleartextTraffic="true" ...>
```
No Podfile or gradle edits needed for these packages. Do NOT add `android.permission.CAMERA` — if it's in the manifest, image_picker then REQUIRES it granted; absent, the camera intent needs no runtime permission. Android 13+ gallery uses the system Photo Picker: zero permissions.

## 4) Node relay (relay.js — run `node relay.js`)
```js
const { WebSocketServer, WebSocket } = require('ws');
const wss = new WebSocketServer({ host: '0.0.0.0', port: 8080 });
wss.on('connection', (ws, req) => {
  console.log('client:', req.socket.remoteAddress);
  ws.isAlive = true;
  ws.on('pong', () => { ws.isAlive = true; });
  ws.on('message', (data, isBinary) => {
    for (const c of wss.clients)                       // re-broadcast to all OTHERS
      if (c !== ws && c.readyState === WebSocket.OPEN) c.send(data, { binary: isBinary });
  });
  ws.on('error', console.error);
});
setInterval(() => {                                    // heartbeat: kill dead clients
  for (const ws of wss.clients) {
    if (ws.isAlive === false) { ws.terminate(); continue; }
    ws.isAlive = false; ws.ping();
  }
}, 10000);
console.log('relay on 0.0.0.0:8080');
```

## GOTCHAS (demo-killers)
1. **Dart itself blocks ws:// (cleartext) on BOTH platforms** — error "Insecure HTTP is not allowed by platform". Fix is build-time only: `android:usesCleartextTraffic="true"` + iOS `NSAllowsArbitraryLoads=true`. Full rebuild (not hot reload) after changing these.
2. **iOS Local Network permission**: prompt fires on FIRST traffic to a LAN IP (iOS 14+). If missing `NSLocalNetworkUsageDescription`, connection just hangs/times out with no error. Warm it up: open the WS connection on app launch, tap Allow BEFORE demo. If it was denied: Settings > Privacy & Security > Local Network > toggle app on, then RESTART the app (iOS 17/18 behave inconsistently until relaunch; delete+reinstall resets the prompt ⚠ unverified).
3. **Sender text on Dart side**: ws `data` arrives as a Buffer; the relay above re-sends it as binary if received binary. Send with `channel.sink.add(jsonEncode(...))` (String) and it stays text end-to-end.
4. **Hotspot on iPhone**: if the iPhone hosts the hotspot, the laptop's IP changes (usually 172.20.10.x) — re-run `ipconfig getifaddr en0` AFTER joining the hotspot, and note en0 may become the hotspot link. Android hotspot host phone CAN reach the laptop's IP on its own hotspot (no special config), but macOS firewall may block node — allow incoming for node or disable firewall.
5. **Unhandled WS stream error crashes the app** — always pass `onError` to `.listen()`; `WebSocketChannel.connect` does not throw on bad host, failures surface via `await channel.ready` / the stream.
6. **Hive writes are async** — `box.put()` without `await` can be lost if the app is killed; await puts and call `box.flush()` after each card save.

## Sources
- https://pub.dev/packages/web_socket_channel (3.0.3) · https://pub.dev/packages/hive (2.2.3) · https://pub.dev/packages/hive_flutter (1.1.0) · https://pub.dev/packages/image_picker (1.2.3) · https://pub.dev/packages/path_provider (2.1.6)
- https://docs.flutter.dev/release/breaking-changes/network-policy-ios-android (cleartext policy)
- https://github.com/websockets/ws (broadcast + heartbeat patterns, v8.21.0)
- https://developer.apple.com/documentation/bundleresources/information-property-list/nslocalnetworkusagedescription
