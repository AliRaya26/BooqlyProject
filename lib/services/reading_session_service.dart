import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:booqly/theme/app_colors.dart';

// ── Active session model ──────────────────────────────────────────────────────

class ActiveSession {
  final String bookId;
  final String bookTitle;
  final String bookCoverUrl;
  final int startPage;
  final int totalPages;
  final DateTime startTime;

  const ActiveSession({
    required this.bookId,
    required this.bookTitle,
    required this.bookCoverUrl,
    required this.startPage,
    required this.totalPages,
    required this.startTime,
  });

  Duration get elapsed => DateTime.now().difference(startTime);

  String get elapsedLabel {
    final e = elapsed;
    final h = e.inHours;
    final m = e.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = e.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}

// ── Service ───────────────────────────────────────────────────────────────────

class ReadingSessionService {
  ReadingSessionService._();
  static final ReadingSessionService instance = ReadingSessionService._();

  final ValueNotifier<ActiveSession?> active = ValueNotifier(null);
  Timer? _ticker;

  bool get isActive => active.value != null;
  String? get activeBookId => active.value?.bookId;

  /// Start a reading session for a book.
  void start({
    required String bookId,
    required String bookTitle,
    required String coverUrl,
    required int currentPage,
    required int totalPages,
  }) {
    _stopTicker();
    active.value = ActiveSession(
      bookId: bookId,
      bookTitle: bookTitle,
      bookCoverUrl: coverUrl,
      startPage: currentPage,
      totalPages: totalPages,
      startTime: DateTime.now(),
    );
    // Tick every second so elapsed label refreshes in UI
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (active.value != null) active.notifyListeners();
    });
  }

  /// Save session to Firestore and update library book progress.
  Future<void> saveAndStop({required int endPage}) async {
    final session = active.value;
    if (session == null) return;
    _stopTicker();
    active.value = null;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final pagesRead =
        (endPage - session.startPage).clamp(0, session.totalPages);
    final durationMinutes = session.elapsed.inMinutes;
    final progress = session.totalPages > 0
        ? (endPage / session.totalPages * 100).round().clamp(0, 100)
        : 0;
    final isCompleted =
        endPage >= session.totalPages && session.totalPages > 0;

    final db = FirebaseFirestore.instance;
    final batch = db.batch();

    // Update library doc
    batch.set(
      db
          .collection('users')
          .doc(uid)
          .collection('library')
          .doc(session.bookId),
      {
        'currentPage': endPage,
        'progress': progress,
        'lastReadAt': FieldValue.serverTimestamp(),
        'status': isCompleted ? 'completed' : 'reading',
        if (isCompleted) 'completedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    // Add reading session doc
    batch.set(
      db
          .collection('users')
          .doc(uid)
          .collection('readingSessions')
          .doc(),
      {
        'bookId': session.bookId,
        'pagesRead': pagesRead,
        'startPage': session.startPage,
        'endPage': endPage,
        'date': Timestamp.fromDate(session.startTime),
        'durationMinutes': durationMinutes,
        'createdAt': FieldValue.serverTimestamp(),
      },
    );

    await batch.commit();
  }

  /// Cancel without saving.
  void discard() {
    _stopTicker();
    active.value = null;
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }
}

// ── Stop session bottom sheet ─────────────────────────────────────────────────

Future<void> showStopSessionSheet(BuildContext context) async {
  final session = ReadingSessionService.instance.active.value;
  if (session == null) return;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _StopSessionSheet(session: session),
  );
}

class _StopSessionSheet extends StatefulWidget {
  const _StopSessionSheet({required this.session});
  final ActiveSession session;

  @override
  State<_StopSessionSheet> createState() => _StopSessionSheetState();
}

class _StopSessionSheetState extends State<_StopSessionSheet> {
  late final TextEditingController _pageCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _pageCtrl = TextEditingController(
      text: widget.session.startPage > 0
          ? widget.session.startPage.toString()
          : '',
    );
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  int get _enteredPage => int.tryParse(_pageCtrl.text.trim()) ?? 0;
  bool get _valid =>
      _enteredPage > 0 && _enteredPage <= widget.session.totalPages;

  Future<void> _save() async {
    if (!_valid) return;
    setState(() => _saving = true);
    await ReadingSessionService.instance.saveAndStop(endPage: _enteredPage);
    if (mounted) Navigator.pop(context);
  }

  void _discard() {
    ReadingSessionService.instance.discard();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final elapsed = widget.session.elapsed;
    final minutes = elapsed.inMinutes;
    final seconds = elapsed.inSeconds.remainder(60);
    final timeLabel = minutes > 0
        ? '$minutes min ${seconds}s'
        : '${elapsed.inSeconds}s';

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Header
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: c.brandSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.menu_book_rounded,
                      color: c.brand, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Session complete 📖',
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: c.text,
                        ),
                      ),
                      Text(
                        '${widget.session.bookTitle} · $timeLabel',
                        style: GoogleFonts.outfit(
                            fontSize: 13, color: c.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Page input
            Text(
              'What page did you reach?',
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: c.text,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _pageCtrl,
                    keyboardType: TextInputType.number,
                    style:
                        GoogleFonts.outfit(fontSize: 16, color: c.text),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText:
                          'e.g. ${widget.session.startPage + 10}',
                      hintStyle: GoogleFonts.outfit(color: c.textMuted),
                      suffixText:
                          '/ ${widget.session.totalPages}',
                      suffixStyle:
                          GoogleFonts.outfit(color: c.textMuted),
                      filled: true,
                      fillColor: c.surfaceAlt,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
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
                        borderSide:
                            BorderSide(color: c.brand, width: 1.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_pageCtrl.text.isNotEmpty && !_valid) ...[
              const SizedBox(height: 6),
              Text(
                'Enter a page between 1 and ${widget.session.totalPages}',
                style: GoogleFonts.outfit(
                    fontSize: 12, color: c.red),
              ),
            ],
            const SizedBox(height: 24),

            // Save button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: (_valid && !_saving) ? _save : null,
                style: FilledButton.styleFrom(
                  backgroundColor: c.brand,
                  disabledBackgroundColor: c.border,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(
                        'Save session',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),

            // Discard
            Center(
              child: TextButton(
                onPressed: _discard,
                child: Text(
                  'Discard session',
                  style: GoogleFonts.outfit(
                      fontSize: 13, color: c.textMuted),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Active session banner (embed in any page) ─────────────────────────────────

class ActiveSessionBanner extends StatelessWidget {
  const ActiveSessionBanner({super.key, this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ActiveSession?>(
      valueListenable: ReadingSessionService.instance.active,
      builder: (context, session, _) {
        if (session == null) return const SizedBox.shrink();
        final c = AppColors.of(context);
        return GestureDetector(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: c.brandSoft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.brandMid),
            ),
            child: Row(
              children: [
                // Pulsing dot
                _PulsingDot(color: c.brand),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reading now',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: c.brand,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        session.bookTitle,
                        style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: c.text),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Text(
                  session.elapsedLabel,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: c.brand,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => showStopSessionSheet(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: c.brand,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Stop',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color});
  final Color color;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
