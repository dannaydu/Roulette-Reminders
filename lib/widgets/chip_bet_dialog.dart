import 'package:flutter/material.dart';
import 'package:todo/services/casino_service.dart';

class ChipBetDialog extends StatefulWidget {
  const ChipBetDialog({
    required this.userId,
    super.key,
  });

  final String userId;

  @override
  State<ChipBetDialog> createState() => _ChipBetDialogState();
}

class _ChipBetDialogState extends State<ChipBetDialog>
    with SingleTickerProviderStateMixin {
  int _selectedAmount = CasinoService.tableBetOptions.first;
  CasinoTableBetColor _selectedChoice = CasinoTableBetColor.red;
  CasinoProfile? _localProfile;
  ChipBetResult? _lastResult;
  bool _isSubmitting = false;
  String? _errorText;

  late final AnimationController _animationController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  late final Animation<Offset> _chipSlide =
      Tween<Offset>(
        begin: const Offset(0, 0.3),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Curves.easeOutBack,
        ),
      );
  late final Animation<double> _chipScale =
      Tween<double>(
        begin: 0.8,
        end: 1.05,
      ).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
        ),
      );
  late final Animation<double> _glowOpacity =
      Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: const Interval(0.35, 1.0, curve: Curves.easeIn),
        ),
      );

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
              final amountOptions = _amountOptions(profile.balance);
              final selectedAmount = amountOptions.contains(_selectedAmount)
                  ? _selectedAmount
                  : amountOptions.isEmpty
                  ? 0
                  : amountOptions.first;
              final canSubmit =
                  !_isSubmitting &&
                  selectedAmount > 0 &&
                  profile.balance >= selectedAmount;

              return SingleChildScrollView(
                child: Column(
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
                                'High Roller Table',
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Bet chips already in your vault. Red and black pay 2x. Green pays 14x.',
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
                          onPressed: _isSubmitting
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
                        _buildInfoChip(
                          context,
                          icon: Icons.paid_outlined,
                          label: 'House Chips',
                          value: '${profile.balance}',
                        ),
                        _buildInfoChip(
                          context,
                          icon: Icons.bolt,
                          label: 'Last Hit',
                          value: '${profile.lastPayout}',
                          emphasized: profile.lastPayout > 0,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Choose your stake',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (amountOptions.isEmpty)
                      Text(
                        'You need chips before you can sit at the table.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: amountOptions
                            .map(
                              (amount) => ChoiceChip(
                                label: Text('$amount chips'),
                                selected: selectedAmount == amount,
                                onSelected: _isSubmitting
                                    ? null
                                    : (_) {
                                        setState(() {
                                          _selectedAmount = amount;
                                        });
                                      },
                              ),
                            )
                            .toList(growable: false),
                      ),
                    const SizedBox(height: 18),
                    Text(
                      'Pick your side',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _buildChoiceCard(
                          label: 'Red',
                          odds: '2x payout',
                          backgroundColor: const Color(0xFFB71C1C),
                          foregroundColor: Colors.white,
                          choice: CasinoTableBetColor.red,
                        ),
                        _buildChoiceCard(
                          label: 'Black',
                          odds: '2x payout',
                          backgroundColor: const Color(0xFF111111),
                          foregroundColor: Colors.white,
                          choice: CasinoTableBetColor.black,
                        ),
                        _buildChoiceCard(
                          label: 'Green',
                          odds: '14x payout',
                          backgroundColor: const Color(0xFF0B6B3A),
                          foregroundColor: Colors.white,
                          choice: CasinoTableBetColor.green,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colorScheme.outlineVariant,
                        ),
                      ),
                      child: Text(
                        selectedAmount == 0
                            ? 'No chips available to bet right now.'
                            : _selectionSummary(selectedAmount),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (_lastResult != null) ...[
                      _buildBetAnimation(context),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _lastResult!.didWin
                              ? colorScheme.primary.withValues(alpha: 0.14)
                              : colorScheme.error.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _lastResult!.didWin
                                ? colorScheme.primary.withValues(alpha: 0.35)
                                : colorScheme.error.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          _resultMessage(_lastResult!),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ],
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
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: canSubmit
                            ? () => _placeBet(selectedAmount)
                            : null,
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.local_atm),
                        label: Text(
                          _isSubmitting
                              ? 'Betting...'
                              : selectedAmount == 0
                              ? 'Need Chips'
                              : 'Bet $selectedAmount Chips',
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(
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
            ? colorScheme.primary.withValues(alpha: 0.14)
            : colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: emphasized
              ? colorScheme.primary.withValues(alpha: 0.3)
              : colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
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

  Widget _buildChoiceCard({
    required String label,
    required String odds,
    required Color backgroundColor,
    required Color foregroundColor,
    required CasinoTableBetColor choice,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = _selectedChoice == choice;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: _isSubmitting
          ? null
          : () {
              setState(() {
                _selectedChoice = choice;
              });
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 138,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? colorScheme.secondary : Colors.transparent,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: colorScheme.secondary.withValues(alpha: 0.22),
                    blurRadius: 14,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: foregroundColor,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              odds,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: foregroundColor.withValues(alpha: 0.88),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<int> _amountOptions(int balance) {
    if (balance <= 0) {
      return const [];
    }

    final options = <int>{
      ...CasinoService.tableBetOptions.where((amount) => amount < balance),
      balance,
    }.toList(growable: false)..sort();
    return options;
  }

  Widget _buildBetAnimation(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final didWin = _lastResult?.didWin ?? false;
    final chipColor = didWin ? colorScheme.primary : colorScheme.error;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SlideTransition(
        position: _chipSlide,
        child: ScaleTransition(
          scale: _chipScale,
          child: Stack(
            alignment: Alignment.center,
            children: [
              FadeTransition(
                opacity: _glowOpacity,
                child: Container(
                  width: 94,
                  height: 94,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        chipColor.withValues(alpha: 0.22),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 1.0],
                    ),
                  ),
                ),
              ),
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: chipColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: chipColor.withValues(alpha: 0.26),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    _lastResult!.choice == CasinoTableBetColor.green
                        ? 'G'
                        : _lastResult!.choice == CasinoTableBetColor.red
                        ? 'R'
                        : 'B',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
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

  String _selectionSummary(int amount) {
    return switch (_selectedChoice) {
      CasinoTableBetColor.red =>
        'Bet $amount on red. If red lands, the table pays $amount * 2 = ${amount * 2} chips.',
      CasinoTableBetColor.black =>
        'Bet $amount on black. If black lands, the table pays $amount * 2 = ${amount * 2} chips.',
      CasinoTableBetColor.green =>
        'Bet $amount on green. If green lands, the table pays $amount * 14 = ${amount * 14} chips.',
    };
  }

  String _resultMessage(ChipBetResult result) {
    final rollLabel = _rollLabel(result.roll);
    if (result.didWin) {
      return '${_choiceLabel(result.choice)} hit on $rollLabel. Payout +${result.payout} House Chips.';
    }

    return 'The ball landed on $rollLabel. You lost ${result.amount} chips.';
  }

  String _choiceLabel(CasinoTableBetColor choice) {
    return switch (choice) {
      CasinoTableBetColor.red => 'Red',
      CasinoTableBetColor.black => 'Black',
      CasinoTableBetColor.green => 'Green',
    };
  }

  String _rollLabel(int roll) {
    if (roll == 0) {
      return 'green 0';
    }

    return _isRedRoll(roll) ? 'red $roll' : 'black $roll';
  }

  bool _isRedRoll(int roll) {
    return const {1, 3, 5, 7, 9, 12, 14}.contains(roll);
  }

  Future<void> _placeBet(int amount) async {
    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      final result = await CasinoService.instance.placeTableBet(
        userId: widget.userId,
        amount: amount,
        choice: _selectedChoice,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _localProfile = result.profile;
        _lastResult = result;
      });
      _animationController.forward(from: 0);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorText = '$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}
