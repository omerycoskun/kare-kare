import 'package:flutter/material.dart';

import 'game_screen.dart';
import 'home_screen.dart';
import 'levels.dart';

/// Çini Macerası bölüm seçimi: yıldızlar ve kilitler.
class LevelsScreen extends StatefulWidget {
  const LevelsScreen({super.key});

  @override
  State<LevelsScreen> createState() => _LevelsScreenState();
}

class _LevelsScreenState extends State<LevelsScreen> {
  Future<void> _play(int level) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => GameScreen(level: levelSpec(level))));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final progress = LevelProgress.instance;
    return Scaffold(
      body: CiniBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 16, 4),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 28),
                    ),
                    const Expanded(
                      child: Text('Çini Macerası',
                          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                    ),
                    const Icon(Icons.star_rounded, color: Color(0xFFFFC83D)),
                    Text(' ${progress.totalStars}',
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Satır ve sütunları patlatarak tüm çinileri temizle. Taşlar iki patlamada kırılır!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(20),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 96,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.82,
                  ),
                  itemCount: kLevelCount,
                  itemBuilder: (context, i) {
                    final level = i + 1;
                    final unlocked = progress.isUnlocked(level);
                    final stars = progress.stars(level);
                    return _LevelTile(
                      level: level,
                      unlocked: unlocked,
                      stars: stars,
                      onTap: unlocked ? () => _play(level) : null,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  const _LevelTile({required this.level, required this.unlocked, required this.stars, required this.onTap});

  final int level;
  final bool unlocked;
  final int stars;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: unlocked ? const Color(0xFFF3F8FF) : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: unlocked ? const Color(0xFF1F6FB2) : Colors.white24, width: 2.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            unlocked
                ? Text('$level',
                    style: const TextStyle(color: Color(0xFF12254A), fontSize: 22, fontWeight: FontWeight.w900))
                : const Icon(Icons.lock_rounded, color: Colors.white38),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var s = 1; s <= 3; s++)
                  Icon(
                    Icons.star_rounded,
                    size: 13,
                    color: s <= stars ? const Color(0xFFFFB400) : (unlocked ? Colors.black12 : Colors.white12),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
