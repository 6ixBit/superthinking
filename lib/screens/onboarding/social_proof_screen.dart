import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import '../../theme/app_colors.dart';

class SocialProofScreen extends StatefulWidget {
  const SocialProofScreen({super.key});

  @override
  State<SocialProofScreen> createState() => _SocialProofScreenState();
}

class _SocialProofScreenState extends State<SocialProofScreen> {
  @override
  void initState() {
    super.initState();
    // Request review as soon as the page loads
    Future.delayed(const Duration(milliseconds: 500), () {
      _requestReview();
    });
  }

  Future<void> _requestReview() async {
    try {
      final InAppReview inAppReview = InAppReview.instance;
      if (await inAppReview.isAvailable()) {
        await inAppReview.requestReview();
      }
    } catch (_) {
      // If review fails, continue silently
    }
  }

  Future<void> _onContinue() async {
    if (!mounted) return;

    try {
      await RevenueCatUI.presentPaywall();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const PreferredSize(
        preferredSize: Size.fromHeight(56),
        child: _OnboardingHeader(current: 17, total: 17),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFE7D1), Color(0x00FFE7D1)],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          Text(
                            'Help us help more people',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 40),

                          // Stars
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              5,
                              (index) => const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4),
                                child: Icon(
                                  Icons.star_rounded,
                                  color: Color(0xFFFFD700),
                                  size: 32,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 40),
                          Text(
                            'SuperThinking is designed for people like you, who want to transform overthinking into clarity.',
                            textAlign: TextAlign.center,
                            style: Theme.of(
                              context,
                            ).textTheme.bodyLarge?.copyWith(height: 1.4),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Giving us a 5-star rating helps us to further build our vision and help more people in this world.',
                            textAlign: TextAlign.center,
                            style: Theme.of(
                              context,
                            ).textTheme.bodyLarge?.copyWith(height: 1.4),
                          ),

                          const SizedBox(height: 40),

                          // User avatars and count
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Overlapping avatars using real images
                              CircleAvatar(
                                radius: 20,
                                backgroundImage: const AssetImage(
                                  'assets/avatars/social_proof/sarah.jpg',
                                ),
                              ),
                              Transform.translate(
                                offset: const Offset(-8, 0),
                                child: const CircleAvatar(
                                  radius: 20,
                                  backgroundImage: AssetImage(
                                    'assets/avatars/social_proof/katie.jpg',
                                  ),
                                ),
                              ),
                              Transform.translate(
                                offset: const Offset(-16, 0),
                                child: const CircleAvatar(
                                  radius: 20,
                                  backgroundImage: AssetImage(
                                    'assets/avatars/social_proof/alex.jpg',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '10,000+ people',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(color: Colors.grey.shade700),
                              ),
                            ],
                          ),

                          const SizedBox(height: 40),

                          // Reviews
                          _ReviewCard(
                            name: 'Emily Chen',
                            handle: '@emilyc',
                            avatarPath: 'assets/avatars/social_proof/chen.jpg',
                            review:
                                'SuperThinking changed how I process my thoughts! The voice journaling feature helps me untangle my mind, and I\'m more productive and less anxious. Love the daily insights too!',
                          ),

                          const SizedBox(height: 16),

                          _ReviewCard(
                            name: 'Vanessa Park',
                            handle: '@vanessap',
                            avatarPath:
                                'assets/avatars/social_proof/vanilla.jpg',
                            review:
                                'Finally found an app that understands overthinking! Been using it for 2 months and my mind feels so much clearer. The progress tracking keeps me motivated. Absolutely worth it!',
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(context).pushNamed('/free-trial-info');
                      },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Try for free',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final String name;
  final String handle;
  final String review;
  final String avatarPath;

  const _ReviewCard({
    required this.name,
    required this.handle,
    required this.review,
    required this.avatarPath,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                backgroundImage: AssetImage(avatarPath),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      handle,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: List.generate(
                  5,
                  (index) => const Icon(
                    Icons.star_rounded,
                    color: Color(0xFFFFD700),
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            review,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _OnboardingHeader extends StatelessWidget {
  final int current;
  final int total;
  const _OnboardingHeader({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    final progress = current / total;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.black,
              ),
            ),
            Expanded(
              child: Center(
                child: SizedBox(
                  width: 180,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0, 1),
                      minHeight: 8,
                      backgroundColor: Colors.black.withOpacity(0.1),
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}
