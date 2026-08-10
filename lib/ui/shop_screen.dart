import 'package:flutter/material.dart';

import '../game/progress.dart';
import '../game/skins.dart';

/// Skin marketplace. Buys are one-shot (skin joins the owned list forever);
/// the active skin can be swapped freely between owned ones.
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  int _totalScore = 0;
  int _available = 0;
  Set<SkinId> _owned = {SkinId.none};
  SkinId _active = SkinId.none;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final total = await Progress.totalScore();
    final available = await SkinManager.availableScore(total);
    final owned = await SkinManager.loadOwned();
    final active = await SkinManager.loadActive();
    if (!mounted) return;
    setState(() {
      _totalScore = total;
      _available = available;
      _owned = owned;
      _active = active;
      _loading = false;
    });
  }

  Future<void> _buy(SkinId skin) async {
    final ok = await SkinManager.buy(skin, currentScore: _available);
    if (!ok) return;
    await _reload();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Куплено: ${skin.displayName}'),
        backgroundColor: const Color(0xFF6ECF3A),
        duration: const Duration(milliseconds: 1400),
      ),
    );
  }

  Future<void> _activate(SkinId skin) async {
    await SkinManager.setActive(skin);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF224F73),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    final skins = SkinId.values;
    return Scaffold(
      backgroundColor: const Color(0xFF224F73),
      body: SafeArea(
        child: Column(
          children: [
            _header(context),
            _wallet(),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(14),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.78,
                ),
                itemCount: skins.length,
                itemBuilder: (_, i) => _SkinCard(
                  skin: skins[i],
                  isOwned: _owned.contains(skins[i]),
                  isActive: _active == skins[i],
                  canAfford: _available >= skins[i].price,
                  onBuy: () => _buy(skins[i]),
                  onActivate: () => _activate(skins[i]),
                ),
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
              'Магазин',
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

  Widget _wallet() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.star_rounded, color: Color(0xFFFFD338), size: 22),
            const SizedBox(width: 8),
            Text(
              '$_available',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'доступно',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 13,
              ),
            ),
            const Spacer(),
            Text(
              'всего $_totalScore',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
          ],
        ),
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

class _SkinCard extends StatelessWidget {
  const _SkinCard({
    required this.skin,
    required this.isOwned,
    required this.isActive,
    required this.canAfford,
    required this.onBuy,
    required this.onActivate,
  });

  final SkinId skin;
  final bool isOwned;
  final bool isActive;
  final bool canAfford;
  final VoidCallback onBuy;
  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) {
    final accent = isActive
        ? const Color(0xFFFFD338)
        : isOwned
            ? const Color(0xFF6ECF3A)
            : const Color(0xFF3B7CB3);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF3B7CB3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent, width: isActive ? 3 : 2),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Center(
              child: _preview(),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            skin.displayName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            skin.description,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 11,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          _actionButton(),
        ],
      ),
    );
  }

  Widget _preview() {
    // Placeholder: coloured disc + emoji until dedicated skin art lands.
    return Container(
      width: 78,
      height: 78,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        skin.emoji,
        style: const TextStyle(fontSize: 42),
      ),
    );
  }

  Widget _actionButton() {
    if (isActive) {
      return _pill('АКТИВНО', const Color(0xFFFFD338), null);
    }
    if (isOwned) {
      return _pill('Выбрать', const Color(0xFF6ECF3A), onActivate);
    }
    return _pill(
      '${skin.price} ★',
      canAfford ? const Color(0xFFFF9438) : const Color(0xFF5A6A7A),
      canAfford ? onBuy : null,
    );
  }

  Widget _pill(String label, Color color, VoidCallback? onTap) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 13,
              letterSpacing: 0.6,
            ),
          ),
        ),
      ),
    );
  }
}
