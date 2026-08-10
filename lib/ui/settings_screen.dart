import 'package:flutter/material.dart';

import '../game/audio.dart';
import '../game/progress.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _sfxOn = AudioService.sfxEnabled;
  bool _musicOn = AudioService.musicEnabled;
  bool _resetting = false;

  Future<void> _toggleSfx(bool v) async {
    setState(() => _sfxOn = v);
    await AudioService.setSfxEnabled(v);
    if (v) AudioService.click();
  }

  Future<void> _toggleMusic(bool v) async {
    setState(() => _musicOn = v);
    await AudioService.setMusicEnabled(v);
  }

  Future<void> _confirmReset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF224F73),
        title: const Text('Сбросить прогресс?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: const Text(
          'Все пройденные уровни станут снова закрытыми.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB03A3A)),
            child: const Text('Сбросить', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _resetting = true);
    await Progress.reset();
    if (!mounted) return;
    setState(() => _resetting = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Прогресс сброшен')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF3B7CB3),
      appBar: AppBar(
        backgroundColor: const Color(0xFF224F73),
        foregroundColor: Colors.white,
        title: const Text('Настройки',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.6)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _tile(
              child: SwitchListTile(
                value: _sfxOn,
                onChanged: _toggleSfx,
                title: const Text('Звуки',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                subtitle: Text(
                  _sfxOn ? 'Эффекты (лопание, выстрел)' : 'Тишина',
                  style: const TextStyle(color: Colors.white70),
                ),
                secondary: Icon(
                  _sfxOn ? Icons.volume_up : Icons.volume_off,
                  color: Colors.white,
                ),
                activeThumbColor: const Color(0xFFFFD338),
                inactiveThumbColor: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            _tile(
              child: SwitchListTile(
                value: _musicOn,
                onChanged: _toggleMusic,
                title: const Text('Музыка',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                subtitle: Text(
                  _musicOn ? 'Ambient фон' : 'Отключена',
                  style: const TextStyle(color: Colors.white70),
                ),
                secondary: Icon(
                  _musicOn ? Icons.music_note : Icons.music_off,
                  color: Colors.white,
                ),
                activeThumbColor: const Color(0xFFFFD338),
                inactiveThumbColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            _tile(
              child: ListTile(
                leading: const Icon(Icons.restart_alt, color: Colors.white),
                title: const Text('Сбросить прогресс',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                subtitle: const Text('Закроет все пройденные уровни',
                    style: TextStyle(color: Colors.white70)),
                trailing: _resetting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.chevron_right, color: Colors.white70),
                onTap: _resetting ? null : _confirmReset,
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                'PiFlow v0.1',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF224F73),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.3), width: 2),
      ),
      child: child,
    );
  }
}
