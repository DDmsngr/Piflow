import 'package:flutter/material.dart';

import '../game/models.dart';

/// Bestiary of all piggy types. Reachable from HomeScreen via the ⓘ button.
class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Skip the legacy `breaker` alias — it shares its sprite with `filter`
    // and we don't want it appearing twice.
    final types = PiggyType.values
        .where((t) => t != PiggyType.breaker)
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFF224F73),
      body: SafeArea(
        child: Column(
          children: [
            _header(context),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: types.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _PiggyCard(type: types[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Row(
        children: [
          _iconButton(
            icon: Icons.arrow_back,
            onTap: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Свинки',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: const Color(0xFF3B7CB3),
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _PiggyCard extends StatelessWidget {
  const _PiggyCard({required this.type});
  final PiggyType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF3B7CB3),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.3), width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _avatar(),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      type.displayName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (!type.isSpecial)
                      _tag('база', const Color(0xFF6ECF3A))
                    else
                      _tag('спец', const Color(0xFFFF9438)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  type.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.9),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar() {
    final asset = type.spriteAsset;
    if (asset == null) {
      // Normal piggy — show a coloured circle with a piggy silhouette hint.
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: const Color(0xFFFF6BAA),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black.withValues(alpha: 0.4), width: 2),
        ),
        alignment: Alignment.center,
        child: const Text('🐷', style: TextStyle(fontSize: 30)),
      );
    }
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(4),
      child: Image.asset(
        'assets/images/$asset',
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Icon(Icons.help_outline, color: Colors.white),
      ),
    );
  }

  Widget _tag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}
