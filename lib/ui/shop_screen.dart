import 'package:flutter/material.dart';

import '../game/buffs.dart';
import '../game/models.dart';
import '../game/progress.dart';

/// Магазин супер-пигов. Каждая покупка добавляет **1 заряд** — заряды
/// копятся, tap на HUD-иконку в игре запускает супер-пигу на belt.
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  int _totalScore = 0;
  int _available = 0;
  Map<PiggyType, int> _charges = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final total = await Progress.totalScore();
    final available = await BuffManager.availableScore(total);
    final charges = await BuffManager.loadCharges();
    if (!mounted) return;
    setState(() {
      _totalScore = total;
      _available = available;
      _charges = charges;
      _loading = false;
    });
  }

  Future<void> _buy(PiggyBuff buff) async {
    final ok = await BuffManager.buy(buff, currentScore: _available);
    if (!ok) return;
    await _reload();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('+1 заряд · ${buff.displayName}'),
        backgroundColor: const Color(0xFF6ECF3A),
        duration: const Duration(milliseconds: 1200),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF224F73),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFF224F73),
      body: SafeArea(
        child: Column(
          children: [
            _header(context),
            _wallet(),
            const SizedBox(height: 4),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(14),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.72,
                ),
                itemCount: allBuffs.length,
                itemBuilder: (_, i) {
                  final b = allBuffs[i];
                  return _BuffCard(
                    buff: b,
                    charges: _charges[b.type] ?? 0,
                    canAfford: _available >= b.price,
                    onBuy: () => _buy(b),
                  );
                },
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Свинки-помощники',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.6,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Заряды копятся, запускай в игре с нижней панели',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ],
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

class _BuffCard extends StatelessWidget {
  const _BuffCard({
    required this.buff,
    required this.charges,
    required this.canAfford,
    required this.onBuy,
  });

  final PiggyBuff buff;
  final int charges;
  final bool canAfford;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final owned = charges > 0;
    final accent = owned
        ? const Color(0xFF6ECF3A)
        : const Color(0xFF3B7CB3);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF3B7CB3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent, width: 2),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Center(
                      child: Image.asset(
                        'assets/images/${buff.spriteAsset}',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                if (owned)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6ECF3A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.black.withValues(alpha: 0.35),
                            width: 1.4),
                      ),
                      child: Text(
                        '×$charges',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            buff.displayName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            buff.description,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 10.5,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          _buyButton(),
        ],
      ),
    );
  }

  Widget _buyButton() {
    final color =
        canAfford ? const Color(0xFFFF9438) : const Color(0xFF5A6A7A);
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: canAfford ? onBuy : null,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '${buff.price} ★',
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
