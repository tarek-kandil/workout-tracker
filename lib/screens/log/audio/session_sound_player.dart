import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'session_sounds.dart';

/// Owns the audio players and haptic + sound cues used during a live session.
///
/// Call [load] once (e.g. from `initState`) to generate the tone buffers, and
/// [dispose] to release the players. The `play*` methods are fire-and-forget.
class SessionSoundPlayer {
  final AudioPlayer _player = AudioPlayer();
  final AudioPlayer _sfx = AudioPlayer();
  Uint8List? _beepBytes;
  Uint8List? _tickBytes;
  Uint8List? _doneBytes;

  void load() {
    _beepBytes = generateBeepWav();
    _tickBytes = generateTickBeepWav();
    _doneBytes = generateDoneBeepWav();
  }

  Future<void> playBeep() async {
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 110));
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 110));
    HapticFeedback.heavyImpact();
    if (_beepBytes != null) await _player.play(BytesSource(_beepBytes!));
  }

  Future<void> playTick() async {
    HapticFeedback.lightImpact();
    if (_tickBytes != null) await _sfx.play(BytesSource(_tickBytes!));
  }

  Future<void> playGoSound() async {
    HapticFeedback.mediumImpact();
    if (_beepBytes != null) await _sfx.play(BytesSource(_beepBytes!));
  }

  Future<void> playDoneSound() async {
    HapticFeedback.heavyImpact();
    if (_doneBytes != null) await _sfx.play(BytesSource(_doneBytes!));
  }

  void dispose() {
    _player.dispose();
    _sfx.dispose();
  }
}
