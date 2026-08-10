import 'dart:math' as math;

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SFX + BGM manager. Two independent toggles (sfx, music) — each persisted
/// in SharedPreferences.
class AudioService {
  static bool _preloaded = false;
  static bool _sfxEnabled = true;
  static bool _musicEnabled = true;
  static bool _loadedFromPrefs = false;
  static bool _bgmPlaying = false;
  static bool _bgmInitialized = false;

  static const String _prefsKeySfx = 'piflow_sound_enabled';
  static const String _prefsKeyMusic = 'piflow_music_enabled';

  static final math.Random _rng = math.Random();

  static const List<String> _pops = [
    'floraphonic-infographic-pop-4-197870.mp3',
    'floraphonic-infographic-pop-5-197872.mp3',
    'floraphonic-infographic-pop-8-197875.mp3',
    'floraphonic-bloop-3-186532.mp3',
  ];

  static const String _shoot = 'floraphonic-minimal-pop-click-ui-1-198301.mp3';
  static const String _click = 'floraphonic-minimal-pop-click-ui-3-198303.mp3';
  static const String _launch = 'floraphonic-bloop-4-186533.mp3';
  static const String _win = 'floraphonic-bloop-1-184019.mp3';
  static const String _lose = 'rohhsadotcom-tonal-circuit-error-407662.mp3';
  static const String _bgm = 'paulyudin-ambient-ambient-music-574003.mp3';

  static bool get sfxEnabled => _sfxEnabled;
  static bool get musicEnabled => _musicEnabled;

  /// Legacy compat: keep the old `enabled` getter (used by GameScreen tap
  /// feedback). Reads the sfx toggle.
  static bool get enabled => _sfxEnabled;

  static Future<void> loadEnabled() async {
    if (_loadedFromPrefs) return;
    _loadedFromPrefs = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _sfxEnabled = prefs.getBool(_prefsKeySfx) ?? true;
      _musicEnabled = prefs.getBool(_prefsKeyMusic) ?? true;
    } catch (_) {
      _sfxEnabled = true;
      _musicEnabled = true;
    }
  }

  static Future<void> setSfxEnabled(bool value) async {
    _sfxEnabled = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKeySfx, value);
    } catch (_) {}
  }

  static Future<void> setMusicEnabled(bool value) async {
    _musicEnabled = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKeyMusic, value);
    } catch (_) {}
    if (value) {
      await startBgm();
    } else {
      await stopBgm();
    }
  }

  // Legacy shim so existing settings screen keeps working.
  static Future<void> setEnabled(bool value) => setSfxEnabled(value);

  static Future<void> preload() async {
    if (_preloaded) return;
    _preloaded = true;
    await loadEnabled();
    try {
      await FlameAudio.audioCache.loadAll([
        ..._pops,
        _shoot,
        _click,
        _launch,
        _win,
        _lose,
        _bgm,
      ]);
    } catch (e) {
      debugPrint('Audio preload failed: $e');
    }
  }

  /// Start (or restart) the looping background track. Idempotent.
  static Future<void> startBgm() async {
    if (!_musicEnabled) return;
    if (_bgmPlaying) return;
    try {
      if (!_bgmInitialized) {
        await FlameAudio.bgm.initialize();
        _bgmInitialized = true;
      }
      await FlameAudio.bgm.play(_bgm, volume: 0.25);
      _bgmPlaying = true;
    } catch (e) {
      // Browsers block autoplay until first user gesture — that's fine, we'll
      // retry from onTap in HomeScreen.
      debugPrint('BGM start failed: $e');
    }
  }

  static Future<void> stopBgm() async {
    if (!_bgmPlaying) return;
    _bgmPlaying = false;
    try {
      await FlameAudio.bgm.stop();
    } catch (e) {
      debugPrint('BGM stop failed: $e');
    }
  }

  static void _play(String name, {double volume = 1}) {
    if (!_sfxEnabled) return;
    try {
      FlameAudio.play(name, volume: volume);
    } catch (_) {}
  }

  static void pop() {
    final name = _pops[_rng.nextInt(_pops.length)];
    _play(name, volume: 0.7);
  }

  static void shoot() => _play(_shoot, volume: 0.35);
  static void click() => _play(_click, volume: 0.5);
  static void launch() => _play(_launch, volume: 0.6);
  static void win() => _play(_win, volume: 0.9);
  static void lose() => _play(_lose, volume: 0.7);
}
