import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class LoadingRevealScreen extends StatefulWidget {
  const LoadingRevealScreen({super.key});

  @override
  State<LoadingRevealScreen> createState() => _LoadingRevealScreenState();
}

class _LoadingRevealScreenState extends State<LoadingRevealScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/reveal');
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = _controller.value;
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100 + 8 * t,
                  height: 100 + 8 * t,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withOpacity(0.08),
                  ),
                  child: Icon(
                    CupertinoIcons.sparkles,
                    color: AppColors.primary,
                    size: 44 + 6 * t,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Charging up your SuperThinking',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
