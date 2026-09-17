import 'package:flutter/material.dart';

import 'game_screen.dart';
import 'game_state.dart';
import 'levels.dart';
import 'levels_screen.dart';
import 'piece_widget.dart';
import 'sound_service.dart';

/// Ortak koyu lacivert + soluk çini desenli arka plan.
class CiniBackground extends StatelessWidget {
  const CiniBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF12254A), Color(0xFF081226)],
        ),
      ),
      child: CustomPaint(painter: const CiniPatternPainter(), child: child),
    );
  }
}

/// Ana menü: Çini Macerası (bölümler) ve Serbest oyun.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    LevelProgress.instance.load().then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) setState(() {}); // dönüşte yıldızları tazele
  }

  @override
  Widget build(BuildContext context) {
    final progress = LevelProgress.instance;
    return Scaffold(
      body: CiniBackground(
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: 4,
                right: 4,
                child: IconButton(
                  onPressed: () async {
                    await SoundService.instance.toggle();
                    setState(() {});
                  },
                  icon: Icon(
                    SoundService.instance.soundOn
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded,
                    color: Colors.white70,
                    size: 28,
                  ),
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const _TitleTiles(),
                        const SizedBox(height: 18),
                        const Text(
                          'KARE KARE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 44,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3,
                          ),
                        ),
                        const Text(
                          'Çini Bulmacası',
                          style: TextStyle(
                            color: Color(0xFF7FD8D0),
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 40),
                        _MenuCard(
                          title: 'Çini Macerası',
                          subtitle:
                              '$kLevelCount bölüm • ★ ${progress.totalStars}/${kLevelCount * 3}',
                          icon: Icons.map_rounded,
                          color: const Color(0xFF1F6FB2),
                          onTap: () => _open(const LevelsScreen()),
                        ),
                        const SizedBox(height: 14),
                        _MenuCard(
                          title: 'Serbest Oyun',
                          subtitle: 'Sonsuz mod • rekorunu kır',
                          icon: Icons.all_inclusive_rounded,
                          color: const Color(0xFF2EC4B6),
                          onTap: () => _open(const GameScreen()),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Başlığın üstündeki üç çini karo.
class _TitleTiles extends StatelessWidget {
  const _TitleTiles();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Transform.rotate(
              angle: (i - 1) * 0.12,
              child: const SpecialCell(kind: Special.cini, size: 64),
            ),
          ),
      ],
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 34),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white,
                size: 30,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
