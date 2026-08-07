import 'dart:math';
import 'dart:typed_data';

// ─── WAV tone generators (used by the active-session audio feedback) ────────────

Uint8List makeBeepWav({required int hz, required int ms, int amplitude = 26000}) {
  const sampleRate = 44100;
  final numSamples = sampleRate * ms ~/ 1000;
  final totalSize = 44 + numSamples * 2;
  final buf = ByteData(totalSize);
  void setStr(int offset, String s) {
    for (int i = 0; i < s.length; i++) { buf.setUint8(offset + i, s.codeUnitAt(i)); }
  }
  setStr(0, 'RIFF'); buf.setUint32(4, totalSize - 8, Endian.little);
  setStr(8, 'WAVE'); setStr(12, 'fmt ');
  buf.setUint32(16, 16, Endian.little); buf.setUint16(20, 1, Endian.little);
  buf.setUint16(22, 1, Endian.little); buf.setUint32(24, sampleRate, Endian.little);
  buf.setUint32(28, sampleRate * 2, Endian.little); buf.setUint16(32, 2, Endian.little);
  buf.setUint16(34, 16, Endian.little); setStr(36, 'data');
  buf.setUint32(40, numSamples * 2, Endian.little);
  final dur = ms / 1000.0;
  for (int i = 0; i < numSamples; i++) {
    final t = i / sampleRate;
    double env = 1.0;
    if (t < 0.015) { env = t / 0.015; }
    else if (t > dur - 0.060) { env = (dur - t) / 0.060; }
    final sample = (sin(2 * pi * hz * t) * env * amplitude).round().clamp(-32768, 32767);
    buf.setInt16(44 + i * 2, sample, Endian.little);
  }
  return buf.buffer.asUint8List();
}

Uint8List generateBeepWav() => makeBeepWav(hz: 880, ms: 350);

Uint8List generateTickBeepWav() => makeBeepWav(hz: 440, ms: 120, amplitude: 20000);

Uint8List generateDoneBeepWav() {
  const sampleRate = 44100;
  const durationMs = 600;
  final numSamples = sampleRate * durationMs ~/ 1000;
  final totalSize = 44 + numSamples * 2;
  final buf = ByteData(totalSize);
  void setStr(int offset, String s) {
    for (int i = 0; i < s.length; i++) { buf.setUint8(offset + i, s.codeUnitAt(i)); }
  }
  setStr(0, 'RIFF'); buf.setUint32(4, totalSize - 8, Endian.little);
  setStr(8, 'WAVE'); setStr(12, 'fmt ');
  buf.setUint32(16, 16, Endian.little); buf.setUint16(20, 1, Endian.little);
  buf.setUint16(22, 1, Endian.little); buf.setUint32(24, sampleRate, Endian.little);
  buf.setUint32(28, sampleRate * 2, Endian.little); buf.setUint16(32, 2, Endian.little);
  buf.setUint16(34, 16, Endian.little); setStr(36, 'data');
  buf.setUint32(40, numSamples * 2, Endian.little);
  for (int i = 0; i < numSamples; i++) {
    final t = i / sampleRate;
    final hz = t < 0.30 ? 660 : 880;
    double env = 1.0;
    if (t < 0.010) { env = t / 0.010; }
    else if (t > 0.540) { env = (0.600 - t) / 0.060; }
    final sample = (sin(2 * pi * hz * t) * env * 24000).round().clamp(-32768, 32767);
    buf.setInt16(44 + i * 2, sample, Endian.little);
  }
  return buf.buffer.asUint8List();
}
