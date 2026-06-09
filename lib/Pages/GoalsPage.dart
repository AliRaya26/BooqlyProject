import 'dart:math' as math;

import 'package:booqly/models/reading_goal_model.dart';
import 'package:booqly/services/goals_service.dart';
import 'package:booqly/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class GoalsPage extends StatefulWidget {
  const GoalsPage({super.key});

  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> {
  final GoalsService _service = GoalsService();

  late Future<GoalProgress> _progressFuture;

  // Editing state
  int _yearlyBookGoal = 0;
  int _dailyPageGoal = 0;
  bool _editingYearly = false;
  bool _editingDaily = false;
  bool _saving = false;

  final TextEditingController _yearlyController = TextEditingController();
  final TextEditingController _dailyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _progressFuture = _service.getProgress();
    });
  }

  @override
  void dispose() {
    _yearlyController.dispose();
    _dailyController.dispose();
    super.dispose();
  }

  void _initFromProgress(GoalProgress progress) {
    _yearlyBookGoal = progress.goal.yearlyBookGoal;
    _dailyPageGoal = progress.goal.dailyPageGoal;
    _yearlyController.text =
        _yearlyBookGoal > 0 ? '$_yearlyBookGoal' : '';
    _dailyController.text =
        _dailyPageGoal > 0 ? '$_dailyPageGoal' : '';
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final goal = ReadingGoalModel(
        yearlyBookGoal: _yearlyBookGoal,
        dailyPageGoal: _dailyPageGoal,
      );
      await _service.saveGoal(goal);
      setState(() {
        _editingYearly = false;
        _editingDaily = false;
      });
      _reload();
      if (mounted) {
        final c = AppColors.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: c.brand,
            content: Text(
              'Goals saved!',
              style: GoogleFonts.outfit(color: c.onPrimary),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.close, color: c.text),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Reading Goals',
          style: GoogleFonts.figtree(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: c.text,
          ),
        ),
      ),
      body: FutureBuilder<GoalProgress>(
        future: _progressFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: c.brand),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: GestureDetector(
                onTap: _reload,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh_rounded, color: c.textMuted, size: 36),
                    const SizedBox(height: 12),
                    Text(
                      'Something went wrong.\nTap to retry.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(color: c.textMuted),
                    ),
                  ],
                ),
              ),
            );
          }

          final progress = snapshot.data!;

          // Initialise editing values once (only when not actively editing)
          if (!_editingYearly && !_editingDaily) {
            _initFromProgress(progress);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Yearly Goal ────────────────────────────────────────────
                _GoalCard(
                  emoji: '📚',
                  title: 'Yearly Goal',
                  child: _editingYearly || !progress.goal.hasYearlyGoal
                      ? _NumberInputSection(
                          value: _yearlyBookGoal,
                          label: 'books in ${DateTime.now().year}',
                          controller: _yearlyController,
                          onChanged: (v) => setState(() {
                            _yearlyBookGoal = v;
                            _editingYearly = true;
                          }),
                        )
                      : _YearlyProgressSection(
                          progress: progress,
                          onEdit: () => setState(() => _editingYearly = true),
                        ),
                ),

                const SizedBox(height: 16),

                // ── Daily Goal ─────────────────────────────────────────────
                _GoalCard(
                  emoji: '📄',
                  title: 'Daily Goal',
                  child: _editingDaily || !progress.goal.hasDailyGoal
                      ? _NumberInputSection(
                          value: _dailyPageGoal,
                          label: 'pages per day',
                          controller: _dailyController,
                          onChanged: (v) => setState(() {
                            _dailyPageGoal = v;
                            _editingDaily = true;
                          }),
                        )
                      : _DailyProgressSection(
                          progress: progress,
                          onEdit: () => setState(() => _editingDaily = true),
                        ),
                ),

                const SizedBox(height: 28),

                // ── Save Button ────────────────────────────────────────────
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.brand,
                      foregroundColor: c.onPrimary,
                      disabledBackgroundColor: c.brandMid,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: _saving
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: c.onPrimary,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Save Goals',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 32),

                // ── Motivational Quote ─────────────────────────────────────
                _MotivationalQuote(),

                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Goal Card wrapper
// ─────────────────────────────────────────────────────────────────────────────

class _GoalCard extends StatelessWidget {
  final String emoji;
  final String title;
  final Widget child;

  const _GoalCard({
    required this.emoji,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
        boxShadow: cardShadow(context),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: c.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Number input: stepper row + text field
// ─────────────────────────────────────────────────────────────────────────────

class _NumberInputSection extends StatelessWidget {
  final int value;
  final String label;
  final TextEditingController controller;
  final ValueChanged<int> onChanged;

  const _NumberInputSection({
    required this.value,
    required this.label,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Set your goal',
          style: GoogleFonts.outfit(fontSize: 13, color: c.textMuted),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // Minus button
            _StepButton(
              icon: Icons.remove,
              onTap: value > 0
                  ? () {
                      final newVal = value - 1;
                      controller.text = newVal > 0 ? '$newVal' : '';
                      onChanged(newVal);
                    }
                  : null,
            ),
            const SizedBox(width: 12),
            // Text field
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: c.text,
                ),
                decoration: InputDecoration(
                  hintText: '0',
                  hintStyle: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: c.textMuted,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: c.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: c.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: c.brand, width: 2),
                  ),
                  filled: true,
                  fillColor: c.surfaceAlt,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (text) {
                  final parsed = int.tryParse(text) ?? 0;
                  onChanged(parsed);
                },
              ),
            ),
            const SizedBox(width: 12),
            // Plus button
            _StepButton(
              icon: Icons.add,
              onTap: () {
                final newVal = value + 1;
                controller.text = '$newVal';
                onChanged(newVal);
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.outfit(fontSize: 14, color: c.textMuted),
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _StepButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: onTap != null ? c.brandSoft : c.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: onTap != null ? c.brandMid : c.border,
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: onTap != null ? c.brand : c.textMuted,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Yearly progress section
// ─────────────────────────────────────────────────────────────────────────────

class _YearlyProgressSection extends StatelessWidget {
  final GoalProgress progress;
  final VoidCallback onEdit;

  const _YearlyProgressSection({
    required this.progress,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final done = progress.booksCompletedThisYear;
    final goal = progress.goal.yearlyBookGoal;
    final pct = (progress.yearlyProgress * 100).round();
    final onTrack = progress.yearlyComplete ||
        (done >= (goal * (DateTime.now().dayOfYear / 365)).floor());

    return Column(
      children: [
        Row(
          children: [
            _ProgressRing(
              progress: progress.yearlyProgress,
              color: c.brand,
              centerText: '$pct%',
              label: '',
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$done / $goal books',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: c.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    progress.yearlyComplete
                        ? '🎉 Goal complete!'
                        : onTrack
                            ? '✅ On track!'
                            : '💪 Keep going!',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: progress.yearlyComplete
                          ? c.green
                          : onTrack
                              ? c.green
                              : c.amber,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: onEdit,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: c.surfaceAlt,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: c.border),
                      ),
                      child: Text(
                        'Edit goal',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: c.brand,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Daily progress section
// ─────────────────────────────────────────────────────────────────────────────

class _DailyProgressSection extends StatelessWidget {
  final GoalProgress progress;
  final VoidCallback onEdit;

  const _DailyProgressSection({
    required this.progress,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final done = progress.pagesReadToday;
    final goal = progress.goal.dailyPageGoal;
    final pct = (progress.dailyProgress * 100).round();

    return Column(
      children: [
        Row(
          children: [
            _ProgressRing(
              progress: progress.dailyProgress,
              color: c.amber,
              centerText: '$pct%',
              label: '',
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$done / $goal pages',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: c.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    progress.dailyComplete
                        ? '🎉 Daily goal done!'
                        : done > 0
                            ? '📖 Keep reading!'
                            : '🌅 Start reading today!',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: progress.dailyComplete ? c.green : c.amber,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: onEdit,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: c.surfaceAlt,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: c.border),
                      ),
                      child: Text(
                        'Edit goal',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: c.brand,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Progress Ring
// ─────────────────────────────────────────────────────────────────────────────

class _ProgressRing extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final Color color;
  final String centerText;
  final String label;

  const _ProgressRing({
    required this.progress,
    required this.color,
    required this.centerText,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return SizedBox(
      width: 110,
      height: 110,
      child: CustomPaint(
        painter: _RingPainter(
          progress: progress,
          ringColor: color,
          trackColor: c.border,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                centerText,
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              if (label.isNotEmpty)
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: c.textMuted,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color ringColor;
  final Color trackColor;

  _RingPainter({
    required this.progress,
    required this.ringColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 10.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - strokeWidth / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = ringColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw track
    canvas.drawCircle(center, radius, trackPaint);

    // Draw progress arc
    if (progress > 0) {
      final sweepAngle = 2 * math.pi * progress;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2, // start from top
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.ringColor != ringColor ||
      oldDelegate.trackColor != trackColor;
}

// ─────────────────────────────────────────────────────────────────────────────
// Motivational Quote
// ─────────────────────────────────────────────────────────────────────────────

const _kQuotes = [
  '"A reader lives a thousand lives before he dies." — George R.R. Martin',
  '"Not all those who wander are lost." — J.R.R. Tolkien',
  '"So many books, so little time." — Frank Zappa',
  '"One must always be careful of books, and what is inside them." — Cassandra Clare',
  '"Reading is to the mind what exercise is to the body." — Joseph Addison',
  '"A book is a dream that you hold in your hand." — Neil Gaiman',
  '"The more that you read, the more things you will know." — Dr. Seuss',
  '"I find television very educating... I turn on the TV and read a book." — Groucho Marx',
];

class _MotivationalQuote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final quote = _kQuotes[DateTime.now().day % _kQuotes.length];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.brandSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.brandMid.withValues(alpha: 0.5)),
      ),
      child: Text(
        quote,
        textAlign: TextAlign.center,
        style: GoogleFonts.figtree(
          fontSize: 16,
          fontStyle: FontStyle.italic,
          color: c.brand,
          height: 1.5,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DateTime extension
// ─────────────────────────────────────────────────────────────────────────────

extension _DateTimeExt on DateTime {
  int get dayOfYear {
    final start = DateTime(year, 1, 1);
    return difference(start).inDays + 1;
  }
}
