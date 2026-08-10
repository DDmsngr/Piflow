import 'package:flame/flame.dart';
import 'package:flutter/material.dart';

import '../game/audio.dart';
import '../game/models.dart';
import 'home_screen.dart';

/// Shown while game assets preload. Minimum display of 1.2s so it doesn't
/// blink on fast machines.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final started = DateTime.now();

    // Preload all sprites the game touches so entering a level is instant.
    final images = <String>[
      'bg_game.png',
      'bg_menu.png',
      'board_frame.png',
      for (final c in PiggyColor.values) 'piggy_${c.name}.png',
      for (final c in PiggyColor.values) 'piggy_${c.name}_shoot.png',
      for (final c in PiggyColor.values) 'block_${c.name}.png',
      for (final c in PiggyColor.values) 'ball_${c.name}.png',
      for (final t in PiggyType.values)
        if (t.spriteAsset != null) t.spriteAsset!,
    ];
    try {
      await Flame.images.loadAll(images);
    } catch (_) {}
    await AudioService.preload();

    // Enforce min splash duration so the branding registers.
    final elapsed = DateTime.now().difference(started);
    final minShow = const Duration(milliseconds: 1200);
    if (elapsed < minShow) {
      await Future.delayed(minShow - elapsed);
    }

    if (!mounted) return;
    // Chromium browsers block audio until a user gesture; on Android it'll
    // just start. If the browser blocks, bgm will retry on the first tap
    // in HomeScreen (see HomeScreen._openLevel).
    AudioService.startBgm();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const HomeScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/splash.jpg',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: const Color(0xFF6ECF3A)),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 60),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(8),
                child: const CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Color(0xFF3B7CB3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
