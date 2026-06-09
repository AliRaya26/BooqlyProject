import 'dart:math' as math;

import 'package:booqly/services/social_service.dart';
import 'package:booqly/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ReadingWrappedPage extends StatefulWidget {
  const ReadingWrappedPage({super.key});

  @override
  State<ReadingWrappedPage> createState() => _ReadingWrappedPageState();
}

class _ReadingWrappedPageState extends State<ReadingWrappedPage> {
  final _service = SocialService();
  Map<String, dynamic>? _data;
  bool _loading = true;

  final int _year = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await _service.getWrappedData(_year);
    if (mounted) setState(() { _data = data; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: c.text),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Reading Wrapped',
          style: GoogleFonts.figtree(
              fontSize: 22, fontWeight: FontWeight.w700, color: c.text),
        ),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: c.brand))
          : _WrappedBody(data: _data ?? {}, year: _year),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main body
// ─────────────────────────────────────────────────────────────────────────────

class _WrappedBody extends StatelessWidget {
  const _WrappedBody({required this.data, required this.year});
  final Map<String, dynamic> data;
  final int year;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final firstName = data['firstName'] as String? ?? 'Reader';
    final books    = (data['booksCompleted'] as int?) ?? 0;
    final pages    = (data['totalPages']     as int?) ?? 0;
    final hours    = (data['totalHours']     as int?) ?? 0;
    final sessions = (data['totalSessions']  as int?) ?? 0;
    final topBook  = data['topBookTitle']  as String?;
    final topCover = data['topBookCover']  as String?;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [

          // ── Hero banner ────────────────────────────────────────────────────
          _HeroBanner(c: c, year: year, firstName: firstName),
          const SizedBox(height: 20),

          // ── Books completed ────────────────────────────────────────────────
          _BigStatCard(
            c: c,
            icon: Icons.auto_stories_rounded,
            label: 'Books completed',
            value: '$books',
            sublabel: books == 0
                ? 'Start your first book this year!'
                : books == 1
                    ? 'Every great journey starts with one.'
                    : 'That\'s $books worlds explored.',
          ),
          const SizedBox(height: 12),

          // ── Pages + Hours ──────────────────────────────────────────────────
          Row(children: [
            Expanded(
              child: _MiniStatCard(
                c: c,
                icon: Icons.article_outlined,
                label: 'Pages read',
                value: _fmt(pages),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MiniStatCard(
                c: c,
                icon: Icons.schedule_rounded,
                label: 'Hours reading',
                value: '$hours',
              ),
            ),
          ]),
          const SizedBox(height: 12),

          // ── Sessions ───────────────────────────────────────────────────────
          _BigStatCard(
            c: c,
            icon: Icons.local_fire_department_rounded,
            label: 'Reading sessions',
            value: '$sessions',
            sublabel: sessions > 0
                ? 'You showed up $sessions times this year.'
                : 'Every session counts.',
          ),
          const SizedBox(height: 12),

          // ── Top book ───────────────────────────────────────────────────────
          if (topBook != null) ...[
            _TopBookCard(c: c, title: topBook, coverUrl: topCover),
            const SizedBox(height: 12),
          ],

          // ── Quote footer ───────────────────────────────────────────────────
          _QuoteFooter(c: c, books: books, year: year),
        ],
      ),
    );
  }

  String _fmt(int n) => n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : '$n';
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero banner — uses brand gradient that respects theme
// ─────────────────────────────────────────────────────────────────────────────

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.c, required this.year, required this.firstName});
  final AppPalette c;
  final int year;
  final String firstName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 28),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: c.brand.withValues(alpha: 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: c.brand.withValues(alpha: 0.08),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          // Decorative arc
          SizedBox(
            height: 56,
            child: CustomPaint(painter: _ArcPainter(color: c.brand.withValues(alpha: 0.15))),
          ),
          Text(
            '$year',
            style: GoogleFonts.outfit(
              fontSize: 13, letterSpacing: 4,
              color: c.brand, fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Your Reading\nWrapped',
            textAlign: TextAlign.center,
            style: GoogleFonts.figtree(
              fontSize: 40, fontWeight: FontWeight.w700,
              color: c.text, height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            decoration: BoxDecoration(
              color: c.brandSoft,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: c.brandMid),
            ),
            child: Text(
              firstName,
              style: GoogleFonts.figtree(
                fontSize: 20, fontStyle: FontStyle.italic,
                color: c.brand, fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final Color color;
  _ArcPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final rect = Rect.fromLTWH(size.width * 0.1, -size.height * 0.5,
        size.width * 0.8, size.height * 1.8);
    canvas.drawArc(rect, math.pi, math.pi, false, paint);
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// Big stat card
// ─────────────────────────────────────────────────────────────────────────────

class _BigStatCard extends StatelessWidget {
  const _BigStatCard({
    required this.c,
    required this.icon,
    required this.label,
    required this.value,
    required this.sublabel,
  });
  final AppPalette c;
  final IconData icon;
  final String label, value, sublabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border),
        boxShadow: cardShadow(context),
      ),
      child: Row(children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            color: c.brandSoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: c.brand, size: 26),
        ),
        const SizedBox(width: 18),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: GoogleFonts.outfit(fontSize: 12, color: c.textMuted, letterSpacing: 0.4)),
          Text(value,
              style: GoogleFonts.figtree(
                  fontSize: 42, fontWeight: FontWeight.w700, color: c.brand, height: 1.0)),
          const SizedBox(height: 2),
          Text(sublabel,
              style: GoogleFonts.outfit(fontSize: 13, color: c.textSub, height: 1.4)),
        ])),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mini stat card (2-column grid)
// ─────────────────────────────────────────────────────────────────────────────

class _MiniStatCard extends StatelessWidget {
  const _MiniStatCard({required this.c, required this.icon, required this.label, required this.value});
  final AppPalette c;
  final IconData icon;
  final String label, value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border),
        boxShadow: cardShadow(context),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: c.brandSoft,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: c.brand, size: 20),
        ),
        const SizedBox(height: 10),
        Text(value,
            style: GoogleFonts.figtree(
                fontSize: 34, fontWeight: FontWeight.w700, color: c.brand, height: 1.0)),
        const SizedBox(height: 4),
        Text(label,
            style: GoogleFonts.outfit(fontSize: 12, color: c.textMuted)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top book card
// ─────────────────────────────────────────────────────────────────────────────

class _TopBookCard extends StatelessWidget {
  const _TopBookCard({required this.c, required this.title, this.coverUrl});
  final AppPalette c;
  final String title;
  final String? coverUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.brand.withValues(alpha: 0.3)),
        boxShadow: cardShadow(context),
      ),
      child: Row(children: [
        // Cover
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: (coverUrl != null && coverUrl!.startsWith('https://'))
              ? Image.network(coverUrl!, width: 58, height: 84, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _placeholder(c))
              : _placeholder(c),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: c.brandSoft,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('MOST READ',
                style: GoogleFonts.outfit(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: c.brand, letterSpacing: 1.2)),
          ),
          const SizedBox(height: 8),
          Text(title,
              style: GoogleFonts.figtree(
                  fontSize: 20, fontWeight: FontWeight.w700,
                  color: c.text, height: 1.2)),
          const SizedBox(height: 6),
          Text('You kept coming back to this one ✨',
              style: GoogleFonts.outfit(fontSize: 12, color: c.textMuted)),
        ])),
      ]),
    );
  }

  Widget _placeholder(AppPalette c) => Container(
    width: 58, height: 84,
    decoration: BoxDecoration(
      color: c.brandSoft,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Icon(Icons.book_rounded, color: c.brand, size: 28),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Quote footer
// ─────────────────────────────────────────────────────────────────────────────

class _QuoteFooter extends StatelessWidget {
  const _QuoteFooter({required this.c, required this.books, required this.year});
  final AppPalette c;
  final int books, year;

  @override
  Widget build(BuildContext context) {
    final quote = books > 20
        ? '"Some people think that reading is just a hobby — you proved them wrong."'
        : books > 10
            ? '"Not all readers are leaders, but all leaders are readers." — Harry Truman'
            : '"Today a reader, tomorrow a leader." — Margaret Fuller';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: c.brandSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.brandMid.withValues(alpha: 0.6)),
      ),
      child: Column(children: [
        Icon(Icons.format_quote_rounded, color: c.brand, size: 32),
        const SizedBox(height: 12),
        Text(
          quote,
          textAlign: TextAlign.center,
          style: GoogleFonts.figtree(
            fontSize: 17, fontStyle: FontStyle.italic,
            color: c.text, height: 1.6,
          ),
        ),
        const SizedBox(height: 16),
        Divider(color: c.brandMid),
        const SizedBox(height: 12),
        Text(
          'Keep going in ${year + 1} 🚀',
          style: GoogleFonts.outfit(
            fontSize: 13, fontWeight: FontWeight.w700,
            color: c.brand, letterSpacing: 0.5,
          ),
        ),
      ]),
    );
  }
}
