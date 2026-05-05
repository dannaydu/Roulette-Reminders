import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:todo/services/casino_service.dart';

class RouletteSpinDialog extends StatefulWidget {
  const RouletteSpinDialog({
    required this.userId,
    this.highlightUnlocked = false,
    this.minimumPendingSpins = 0,
    super.key,
  });

  final String userId;
  final bool highlightUnlocked;
  final int minimumPendingSpins;

  @override
  State<RouletteSpinDialog> createState() => _RouletteSpinDialogState();
}

class _RouletteSpinDialogState extends State<RouletteSpinDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spinController =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 3600),
      )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() {
            _isAnimating = false;
          });
        }
      });

  late int _minimumPendingSpins = widget.minimumPendingSpins;
  Animation<double>? _turnsAnimation;
  CasinoProfile? _localProfile;
  RouletteSpinResult? _lastResult;
  double _currentTurns = 0;
  bool _isSubmitting = false;
  bool _isAnimating = false;
  String? _errorText;

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final wheel = CasinoService.instance.wheel;

    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.surfaceContainerHighest,
                colorScheme.surface,
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: colorScheme.secondary.withValues(alpha: 0.55),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.24),
                blurRadius: 26,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: StreamBuilder<CasinoProfile>(
            stream: CasinoService.instance.profileStream(widget.userId),
            builder: (context, snapshot) {
              final profile =
                  _localProfile ?? snapshot.data ?? CasinoProfile.empty;
              final pendingSpins = math.max(
                profile.pendingSpins,
                _minimumPendingSpins,
              );
              final effectiveProfile = profile.copyWith(
                pendingSpins: pendingSpins,
              );
              final canSpin =
                  pendingSpins > 0 && !_isSubmitting && !_isAnimating;

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Roulette Vault',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.highlightUnlocked && _lastResult == null
                                  ? 'Task cleared. Your next spin is waiting.'
                                  : 'Turn completed tasks into fake-money payouts.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: _isAnimating
                            ? null
                            : () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _buildVaultChip(
                        context,
                        icon: Icons.stacked_line_chart,
                        label: 'House Chips',
                        value: _formatCash(effectiveProfile.balance),
                      ),
                      _buildVaultChip(
                        context,
                        icon: Icons.casino_outlined,
                        label: 'Spins Ready',
                        value: '$pendingSpins',
                        emphasized: pendingSpins > 0,
                      ),
                      _buildVaultChip(
                        context,
                        icon: Icons.bolt,
                        label: 'Lifetime',
                        value: _formatCash(effectiveProfile.lifetimeWinnings),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: SizedBox(
                      width: 280,
                      height: 316,
                      child: Stack(
                        alignment: Alignment.topCenter,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 28),
                            child: AnimatedBuilder(
                              animation:
                                  _turnsAnimation ?? kAlwaysDismissedAnimation,
                              builder: (context, child) {
                                final turns =
                                    _turnsAnimation?.value ?? _currentTurns;
                                return Transform.rotate(
                                  angle: turns * math.pi * 2,
                                  child: child,
                                );
                              },
                              child: CustomPaint(
                                size: const Size.square(280),
                                painter: _RouletteWheelPainter(
                                  rewards: wheel,
                                  colorScheme: colorScheme,
                                ),
                              ),
                            ),
                          ),
                          Container(
                            width: 38,
                            height: 54,
                            decoration: BoxDecoration(
                              color: colorScheme.secondary,
                              borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(24),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  blurRadius: 12,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            alignment: Alignment.topCenter,
                            child: Icon(
                              Icons.arrow_drop_down,
                              size: 36,
                              color: colorScheme.onSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_lastResult != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: colorScheme.primary.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Text(
                        'Hit +${_formatCash(_lastResult!.reward.payout)} House Chips.',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  else
                    Text(
                      pendingSpins > 0
                          ? 'Cash in a spin and let the wheel decide the payout.'
                          : 'Complete another task to unlock a spin.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  if (_errorText != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _errorText!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: canSpin ? _spin : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: colorScheme.secondary,
                            foregroundColor: colorScheme.onSecondary,
                          ),
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.casino),
                          label: Text(
                            _isAnimating
                                ? 'Spinning...'
                                : pendingSpins > 0
                                ? 'Spin for Cash'
                                : 'No Spins Ready',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildVaultChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    bool emphasized = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: emphasized
            ? colorScheme.secondary.withValues(alpha: 0.2)
            : colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: emphasized
              ? colorScheme.secondary.withValues(alpha: 0.5)
              : colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: emphasized ? colorScheme.secondary : colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            '$label $value',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _spin() async {
    if (_isSubmitting || _isAnimating) {
      return;
    }

    setState(() {
      _errorText = null;
      _isSubmitting = true;
      _minimumPendingSpins = 0;
    });

    try {
      final result = await CasinoService.instance.spin(userId: widget.userId);
      if (!mounted) {
        return;
      }

      final segmentCount = CasinoService.instance.wheel.length;
      final targetOffset = (segmentCount - result.segmentIndex) / segmentCount;
      final nextTurns = _currentTurns + 4 + targetOffset;

      _localProfile = result.profile;
      _lastResult = result;
      _turnsAnimation =
          Tween<double>(
            begin: _currentTurns,
            end: nextTurns,
          ).animate(
            CurvedAnimation(
              parent: _spinController,
              curve: Curves.easeOutQuart,
            ),
          );
      _currentTurns = nextTurns;

      setState(() {
        _isSubmitting = false;
        _isAnimating = true;
      });
      await _spinController.forward(from: 0);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSubmitting = false;
        _errorText = '$error';
      });
    }
  }

  String _formatCash(int amount) {
    return amount.toString();
  }
}

class _RouletteWheelPainter extends CustomPainter {
  const _RouletteWheelPainter({
    required this.rewards,
    required this.colorScheme,
  });

  final List<RouletteReward> rewards;
  final ColorScheme colorScheme;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2;
    final wheelRect = Rect.fromCircle(
      center: center,
      radius: radius - 8,
    );
    final ringPaint = Paint()
      ..color = colorScheme.secondary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
    final slicePaint = Paint()..style = PaintingStyle.fill;
    final sweep = (math.pi * 2) / rewards.length;
    final startAngle = (-math.pi / 2) - (sweep / 2);

    for (var index = 0; index < rewards.length; index++) {
      final reward = rewards[index];
      final isJackpot = index == rewards.length - 1;
      slicePaint.color = isJackpot
          ? colorScheme.primary
          : index.isEven
          ? colorScheme.error
          : const Color(0xFF171516);
      final angle = startAngle + (index * sweep);

      canvas.drawArc(wheelRect, angle, sweep, true, slicePaint);

      final textPainter = TextPainter(
        text: TextSpan(
          text: reward.label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final labelAngle = angle + (sweep / 2);
      final labelRadius = radius * 0.62;

      canvas.save();
      canvas.translate(
        center.dx + math.cos(labelAngle) * labelRadius,
        center.dy + math.sin(labelAngle) * labelRadius,
      );
      canvas.rotate(labelAngle + (math.pi / 2));
      textPainter.paint(
        canvas,
        Offset(-textPainter.width / 2, -textPainter.height / 2),
      );
      canvas.restore();
    }

    canvas.drawCircle(center, radius - 8, ringPaint);

    final centerFill = Paint()..color = colorScheme.surface;
    final centerRing = Paint()
      ..color = colorScheme.secondary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(center, radius * 0.24, centerFill);
    canvas.drawCircle(center, radius * 0.24, centerRing);

    final centerPainter = TextPainter(
      text: TextSpan(
        text: 'SPIN',
        style: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    centerPainter.paint(
      canvas,
      Offset(
        center.dx - (centerPainter.width / 2),
        center.dy - (centerPainter.height / 2),
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _RouletteWheelPainter oldDelegate) {
    return oldDelegate.rewards != rewards ||
        oldDelegate.colorScheme != colorScheme;
  }
}
