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
    return Scaffold(
      // Always dark for the Wrapped screen
      backgroundColor: const Color(0xFF0E0C0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFFF5F0E8)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Reading Wrapped',
          style: GoogleFonts.cormorantGaramond(
              fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFFD4A96A)),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4A96A)))
          : _WrappedCard(data: _data ?? {}, year: _year),
    );
  }
}

class _WrappedCard extends StatelessWidget {
  const _WrappedCard({required this.data, required this.year});
  final Map<String, dynamic> data;
  final int year;

  @override
  Widget build(BuildContext context) {
    final firstName = data['firstName'] as String? ?? 'Reader';
    final books = (data['booksCompleted'] as int?) ?? 0;
    final pages = (data['totalPages'] as int?) ?? 0;
    final hours = (data['totalHours'] as int?) ?? 0;
    final sessions = (data['totalSessions'] as int?) ?? 0;
    final topBook = data['topBookTitle'] as String?;
    final topCover = data['topBookCover'] as String?;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      child: Column(
        children: [
          // ── Hero card ──────────────────────────────────────────────────
          _GlowCard(
            child: Column(
              children: [
                Text(
                  '$year',
                  style: GoogleFonts.outfit(
                    fontSize: 13, letterSpacing: 4,
                    color: const Color(0xFFD4A96A), fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your Reading\nWrapped',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 42, fontWeight: FontWeight.w700,
                    color: const Color(0xFFF5F0E8), height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  firstName,
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 24, fontStyle: FontStyle.italic,
                    color: const Color(0xFFD4A96A),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Books completed ───────────────────────────────────────────
          _StatCard(
            emoji: '📚',
            label: 'Books completed',
            value: '$books',
            sublabel: books == 0
                ? 'Start your first book!'
                : books == 1
                    ? 'Every great library starts with one.'
                    : 'That\'s $books worlds explored.',
          ),
          const SizedBox(height: 12),

          // ── Pages + Hours grid ────────────────────────────────────────
          Row(children: [
            Expanded(child: _MiniStatCard(emoji: '📄', label: 'Pages read', value: _formatNumber(pages))),
            const SizedBox(width: 12),
            Expanded(child: _MiniStatCard(emoji: '⏱️', label: 'Hours reading', value: '$hours')),
          ]),
          const SizedBox(height: 12),

          // ── Sessions ──────────────────────────────────────────────────
          _StatCard(
            emoji: '🔥',
            label: 'Reading sessions',
            value: '$sessions',
            sublabel: sessions > 0
                ? 'You showed up $sessions times this year.'
                : 'Every session counts.',
          ),
          const SizedBox(height: 12),

          // ── Top book ─────────────────────────────────────────────────
          if (topBook != null) ...[
            _TopBookCard(title: topBook, coverUrl: topCover),
            const SizedBox(height: 12),
          ],

          // ── Motivational footer ───────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1713),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF2A2520)),
            ),
            child: Column(children: [
              const Text('📖', style: TextStyle(fontSize: 32)),
              const SizedBox(height: 12),
              Text(
                books > 20
                    ? '"Some people think that reading is just a hobby — you proved them wrong."'
                    : books > 10
                        ? '"Not all readers are leaders, but all leaders are readers." — Harry Truman'
                        : '"Today a reader, tomorrow a leader." — Margaret Fuller',
                textAlign: TextAlign.center,
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 17, fontStyle: FontStyle.italic,
                  color: const Color(0xFFC8BFB4), height: 1.6,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(color: Color(0xFF2A2520)),
              const SizedBox(height: 12),
              Text(
                'Keep going in ${year + 1}',
                style: GoogleFonts.outfit(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: const Color(0xFFD4A96A), letterSpacing: 1,
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _GlowCard extends StatelessWidget {
  const _GlowCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2C200F), Color(0xFF1A1713)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD4A96A).withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4A96A).withValues(alpha: 0.12),
            blurRadius: 32, spreadRadius: 4,
          ),
        ],
      ),
      child: child,
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.emoji, required this.label, required this.value, required this.sublabel});
  final String emoji, label, value, sublabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1713),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2A2520)),
      ),
      child: Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 36)),
        const SizedBox(width: 20),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF888580),
              letterSpacing: 0.5)),
          Text(value, style: GoogleFonts.cormorantGaramond(
              fontSize: 40, fontWeight: FontWeight.w700, color: const Color(0xFFD4A96A), height: 1.0)),
          Text(sublabel, style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFFC8BFB4), height: 1.4)),
        ])),
      ]),
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  const _MiniStatCard({required this.emoji, required this.label, required this.value});
  final String emoji, label, value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1713),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2A2520)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(emoji, style: const TextStyle(fontSize: 26)),
        const SizedBox(height: 8),
        Text(value, style: GoogleFonts.cormorantGaramond(
            fontSize: 32, fontWeight: FontWeight.w700, color: const Color(0xFFD4A96A), height: 1.0)),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF888580))),
      ]),
    );
  }
}

class _TopBookCard extends StatelessWidget {
  const _TopBookCard({required this.title, this.coverUrl});
  final String title;
  final String? coverUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1713),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD4A96A).withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        if (coverUrl != null && coverUrl!.startsWith('https://'))
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(coverUrl!, width: 56, height: 80, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholder()),
          )
        else
          _placeholder(),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Most read book', style: GoogleFonts.outfit(
              fontSize: 11, color: const Color(0xFFD4A96A), fontWeight: FontWeight.w600, letterSpacing: 1.5)),
          const SizedBox(height: 6),
          Text(title, style: GoogleFonts.cormorantGaramond(
              fontSize: 20, fontWeight: FontWeight.w700, color: const Color(0xFFF5F0E8), height: 1.2)),
          const SizedBox(height: 4),
          Text('You kept coming back to this one ✨',
              style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF888580))),
        ])),
      ]),
    );
  }

  Widget _placeholder() => Container(
    width: 56, height: 80,
    decoration: BoxDecoration(
      color: const Color(0xFF2A2520),
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Icon(Icons.book_rounded, color: Color(0xFF888580), size: 28),
  );
}
