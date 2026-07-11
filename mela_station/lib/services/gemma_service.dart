import 'dart:typed_data';

/// THE AI SEAM (frozen interface — Coder's flutter_gemma implementation
/// plugs in here; everything else in the app codes against this).
///
/// The model does EXACTLY two things: text -> attributes, image -> attributes.
/// It never matches, never scores, never controls flow. Attribute maps use
/// the keys in MelaCard.attributeKeys; missing info = "unknown".
abstract class GemmaService {
  /// Load the model ONCE at app start (~10-20s on device). Keep warm forever.
  Future<void> init();

  bool get isReady;

  /// Structure a (Hindi) transcript into attribute fields.
  /// [existing] = current card attributes when merging a follow-up answer;
  /// implementations should bias toward only filling gaps.
  Future<Map<String, String>> extractFromText(String text,
      {Map<String, String>? existing});

  /// Same schema from one consented photo (Gemma vision).
  Future<Map<String, String>> extractFromImage(Uint8List imageBytes);
}
