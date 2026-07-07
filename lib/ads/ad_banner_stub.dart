import 'package:flutter/widgets.dart';

// Web ve masaüstü: banner yok, yer kaplamaz.
class AdBanner extends StatelessWidget {
  const AdBanner({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
