import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import '../../supabase/user_profile_api.dart';
import '../../theme/app_colors.dart';

class OverthinkingImpactScreen extends StatefulWidget {
  const OverthinkingImpactScreen({super.key});

  @override
  State<OverthinkingImpactScreen> createState() =>
      _OverthinkingImpactScreenState();
}

class _OverthinkingImpactScreenState extends State<OverthinkingImpactScreen> {
  double _sliderValue = 0.5; // Start at neutral (middle)
  bool _saving = false;

  String get _impactLabel {
    if (_sliderValue < 0.2) return 'Very Negatively';
    if (_sliderValue < 0.4) return 'Negatively';
    if (_sliderValue < 0.6) return 'Neutral';
    if (_sliderValue < 0.8) return 'Positively';
    return 'Very Positively';
  }

  Color get _sliderColor {
    if (_sliderValue < 0.3) return Colors.red;
    if (_sliderValue < 0.5) return Colors.orange;
    if (_sliderValue < 0.7) return Colors.yellow.shade700;
    return Colors.green;
  }

  Future<void> _onContinue() async {
    setState(() => _saving = true);
    try {
      final impact = _impactLabel;
      context.read<AppState>().addQuickAnswer('Overthinking impact: $impact');
      await UserProfileApi.setOnboardingResponse('overthinking_impact', impact);
      if (!mounted) return;
      Navigator.of(context).pushNamed('/onboarding-age');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const PreferredSize(
        preferredSize: Size.fromHeight(56),
        child: _OnboardingHeader(current: 9, total: 13),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFE7D1), Colors.transparent],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          const SizedBox(height: 40),
                          Text(
                            'Do you think overthinking affects you positively or negatively?',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Move the slider to reflect how overthinking typically impacts your life.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 60),

                          // Impact indicator
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  _getImpactIcon(),
                                  size: 48,
                                  color: _sliderColor,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _impactLabel,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: _sliderColor,
                                      ),
                                ),
                                const SizedBox(height: 24),

                                // Slider
                                Column(
                                  children: [
                                    SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        activeTrackColor: _sliderColor,
                                        inactiveTrackColor:
                                            Colors.grey.shade300,
                                        thumbColor: _sliderColor,
                                        overlayColor: _sliderColor.withOpacity(
                                          0.2,
                                        ),
                                        thumbShape: const RoundSliderThumbShape(
                                          enabledThumbRadius: 12,
                                        ),
                                        trackHeight: 8,
                                      ),
                                      child: Slider(
                                        value: _sliderValue,
                                        onChanged: (value) {
                                          setState(() => _sliderValue = value);
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Very Negative',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: Colors.grey.shade600,
                                                fontWeight: FontWeight.w500,
                                              ),
                                        ),
                                        Text(
                                          'Very Positive',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: Colors.grey.shade600,
                                                fontWeight: FontWeight.w500,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 40),

                          // Description based on selection
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: _sliderColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _sliderColor.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              _getImpactDescription(),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: FilledButton(
            onPressed: !_saving ? _onContinue : null,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Continue'),
          ),
        ),
      ),
    );
  }

  IconData _getImpactIcon() {
    if (_sliderValue < 0.2) return Icons.sentiment_very_dissatisfied;
    if (_sliderValue < 0.4) return Icons.sentiment_dissatisfied;
    if (_sliderValue < 0.6) return Icons.sentiment_neutral;
    if (_sliderValue < 0.8) return Icons.sentiment_satisfied;
    return Icons.sentiment_very_satisfied;
  }

  String _getImpactDescription() {
    if (_sliderValue < 0.2) {
      return 'Overthinking significantly disrupts your daily life and wellbeing.';
    } else if (_sliderValue < 0.4) {
      return 'Overthinking generally causes you stress and anxiety.';
    } else if (_sliderValue < 0.6) {
      return 'Overthinking has both positive and negative effects for you.';
    } else if (_sliderValue < 0.8) {
      return 'Overthinking often helps you solve problems and prepare for situations.';
    } else {
      return 'Overthinking is a valuable tool that significantly benefits your life.';
    }
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
            Text(
              '$current/$total',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.black),
            ),
          ],
        ),
      ),
    );
  }
}
