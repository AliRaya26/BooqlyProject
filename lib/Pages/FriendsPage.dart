import 'package:booqly/Pages/BookDetailPage.dart';
import 'package:booqly/Pages/FriendNotesPage.dart';
import 'package:booqly/models/book_model.dart';
import 'package:booqly/services/dummy_data_service.dart';
import 'package:booqly/services/social_service.dart';
import 'package:booqly/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _searchCtrl = TextEditingController();
  final _service = SocialService();

  List<PublicUserProfile> _searchResults = [];
  bool _searching = false;
  String _lastQuery = '';

  List<PublicUserProfile> _following = [];
  bool _loadingFollowing = true;

  List<FriendActivity> _feed = [];
  bool _loadingFeed = true;

  bool _seeding = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _loadFollowingAndAutoSeed();
    _loadFeed();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFollowingAndAutoSeed() async {
    setState(() => _loadingFollowing = true);
    final profiles = await _service.getFollowingProfiles();
    if (!mounted) return;

    if (profiles.isEmpty) {
      setState(() => _seeding = true);
      await DummyDataService().seed();
      final seeded = await _service.getFollowingProfiles();
      if (mounted) {
        setState(() {
          _following = seeded;
          _loadingFollowing = false;
          _seeding = false;
        });
      }
      await _loadFeed();
    } else {
      if (mounted) setState(() { _following = profiles; _loadingFollowing = false; });
    }
  }

  Future<void> _loadFollowing() async {
    setState(() => _loadingFollowing = true);
    final profiles = await _service.getFollowingProfiles();
    if (mounted) setState(() { _following = profiles; _loadingFollowing = false; });
  }

  Future<void> _loadFeed() async {
    setState(() => _loadingFeed = true);
    final feed = await _service.getActivityFeed();
    if (mounted) setState(() { _feed = feed; _loadingFeed = false; });
  }

  Future<void> _search(String q) async {
    if (q.trim() == _lastQuery) return;
    _lastQuery = q.trim();
    if (q.trim().length < 2) { setState(() => _searchResults = []); return; }
    setState(() => _searching = true);
    final results = await _service.searchUsers(q.trim());
    if (mounted) setState(() { _searchResults = results; _searching = false; });
  }

  Future<void> _toggleFollow(PublicUserProfile profile) async {
    if (profile.isFollowing) {
      await _service.unfollow(profile.uid);
    } else {
      await _service.follow(profile.uid);
    }
    await _loadFollowing();
    if (_lastQuery.isNotEmpty) await _search(_lastQuery + ' ');
  }

  /// Navigate to book detail page (fetches from catalog; shows snackbar if not found).
  Future<void> _openBook(BuildContext ctx, FriendActivity activity) async {
    final c = AppColors.of(ctx);
    final data = await _service.getBookData(activity.bookId);
    if (!ctx.mounted) return;
    if (data != null) {
      final book = BookModel.fromMap(data, data['id'] as String);
      Navigator.push(ctx, MaterialPageRoute(builder: (_) => BookDetailPage(book: book)));
    } else {
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Text(
          '"${activity.bookTitle}" is not in the Booqly catalog yet.',
          style: GoogleFonts.outfit(),
        ),
        backgroundColor: c.brand,
        behavior: SnackBarBehavior.floating,
      ));
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
        title: Text(
          'Friends',
          style: GoogleFonts.cormorantGaramond(
              fontSize: 26, fontWeight: FontWeight.w700, color: c.text),
        ),
        actions: [
          _seeding
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: c.brand),
                  ),
                )
              : IconButton(
                  icon: Icon(Icons.science_outlined, color: c.textMuted),
                  tooltip: 'Reload dummy data',
                  onPressed: () async {
                    setState(() => _seeding = true);
                    await DummyDataService().seed();
                    await _loadFollowing();
                    await _loadFeed();
                    if (mounted) setState(() => _seeding = false);
                  },
                ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: c.brand,
          unselectedLabelColor: c.textMuted,
          indicatorColor: c.brand,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 13),
          unselectedLabelStyle: GoogleFonts.outfit(fontSize: 13),
          tabs: const [
            Tab(text: 'Following'),
            Tab(text: 'Activity'),
            Tab(text: 'Find People'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildFollowingTab(c),
          _buildActivityTab(c),
          _buildSearchTab(c),
        ],
      ),
    );
  }

  // ── Following tab ────────────────────────────────────────────────────────

  Widget _buildFollowingTab(AppPalette c) {
    if (_loadingFollowing) {
      return Center(child: CircularProgressIndicator(color: c.brand));
    }
    if (_following.isEmpty) {
      return _EmptyFollowing(c: c, onFind: () => _tabs.animateTo(2));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: _following.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _ProfileCard(
        profile: _following[i],
        c: c,
        onToggleFollow: () => _toggleFollow(_following[i]),
      ),
    );
  }

  // ── Activity tab ─────────────────────────────────────────────────────────

  Widget _buildActivityTab(AppPalette c) {
    if (_loadingFeed) {
      return Center(child: CircularProgressIndicator(color: c.brand));
    }
    if (_feed.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.local_fire_department_rounded, color: c.textMuted, size: 48),
            const SizedBox(height: 16),
            Text('No recent activity',
                style: GoogleFonts.outfit(
                    fontSize: 18, fontWeight: FontWeight.w600, color: c.text)),
            const SizedBox(height: 8),
            Text('Follow readers to see what they\'re up to.',
                style: GoogleFonts.outfit(fontSize: 14, color: c.textMuted),
                textAlign: TextAlign.center),
          ]),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadFeed,
      color: c.brand,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: _feed.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (ctx, i) => _ActivityCard(
          activity: _feed[i],
          c: c,
          onTap: () => _onActivityTap(ctx, _feed[i]),
        ),
      ),
    );
  }

  void _onActivityTap(BuildContext ctx, FriendActivity activity) {
    final type = activity.activityType;
    if (type == 'note' || type == 'quote') {
      // Open all of this friend's notes for the book
      Navigator.push(ctx, MaterialPageRoute(
        builder: (_) => FriendNotesPage(
          friendUid: activity.ownerUid,
          friendName: activity.userName,
          bookId: activity.bookId,
          bookTitle: activity.bookTitle,
        ),
      ));
    } else {
      // reading / completed / review → navigate to book
      _openBook(ctx, activity);
    }
  }

  // ── Search tab ───────────────────────────────────────────────────────────

  Widget _buildSearchTab(AppPalette c) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            style: GoogleFonts.outfit(fontSize: 15, color: c.text),
            onChanged: _search,
            decoration: InputDecoration(
              hintText: 'Search by name or email…',
              hintStyle: GoogleFonts.outfit(color: c.textMuted),
              prefixIcon: Icon(Icons.search_rounded, color: c.textMuted),
              suffixIcon: _searching
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: c.brand)))
                  : null,
              filled: true,
              fillColor: c.surfaceAlt,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: c.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: c.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: c.brand, width: 1.5)),
            ),
          ),
        ),
        Expanded(
          child: _searchResults.isEmpty
              ? Center(child: Text(
                  _searchCtrl.text.length < 2
                      ? 'Type a name or email to search'
                      : 'No users found',
                  style: GoogleFonts.outfit(color: c.textMuted, fontSize: 14)))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: _searchResults.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _ProfileCard(
                    profile: _searchResults[i],
                    c: c,
                    onToggleFollow: () => _toggleFollow(_searchResults[i]),
                  ),
                ),
        ),
      ],
    );
  }
}

// ── Activity card ─────────────────────────────────────────────────────────────

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.activity, required this.c, required this.onTap});
  final FriendActivity activity;
  final AppPalette c;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final diff = now.difference(activity.timestamp);
    final timeAgo = diff.inDays > 0 ? '${diff.inDays}d ago'
        : diff.inHours > 0 ? '${diff.inHours}h ago'
        : diff.inMinutes > 0 ? '${diff.inMinutes}m ago'
        : 'just now';

    final type = activity.activityType;
    final isNote = type == 'note';
    final isQuote = type == 'quote';
    final isReview = type == 'review';
    final isCompleted = type == 'completed';

    IconData typeIcon;
    Color typeColor;
    String actionText;

    if (isQuote) {
      typeIcon = Icons.format_quote_rounded;
      typeColor = c.brand;
      actionText = 'saved a quote from';
    } else if (isNote) {
      typeIcon = Icons.sticky_note_2_outlined;
      typeColor = c.brand;
      actionText = 'took a note on';
    } else if (isReview) {
      typeIcon = Icons.star_rounded;
      typeColor = Colors.amber;
      actionText = 'reviewed';
    } else if (isCompleted) {
      typeIcon = Icons.check_circle_rounded;
      typeColor = Colors.green;
      actionText = 'finished reading';
    } else {
      typeIcon = Icons.menu_book_rounded;
      typeColor = c.brand;
      actionText = 'is reading';
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Header row ──────────────────────────────────────────────────
          Row(children: [
            // Avatar
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: c.brandSoft, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(
                activity.userName.isNotEmpty ? activity.userName[0].toUpperCase() : '?',
                style: GoogleFonts.outfit(
                    fontSize: 14, fontWeight: FontWeight.w700, color: c.brand),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: RichText(text: TextSpan(
                style: GoogleFonts.outfit(fontSize: 14, color: c.text),
                children: [
                  TextSpan(text: activity.userName,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(text: ' $actionText ',
                      style: TextStyle(color: c.textMuted, fontWeight: FontWeight.w400)),
                  TextSpan(text: activity.bookTitle,
                      style: TextStyle(fontWeight: FontWeight.w600, color: c.brand)),
                ],
              )),
            ),
            const SizedBox(width: 8),
            Icon(typeIcon, color: typeColor, size: 18),
          ]),

          // ── Note / Quote body ────────────────────────────────────────────
          if ((isNote || isQuote) && activity.noteText != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isQuote ? c.brandSoft : c.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isQuote ? c.brand.withOpacity(0.25) : c.border,
                ),
              ),
              child: Text(
                activity.noteText!,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: c.text,
                  height: 1.5,
                  fontStyle: isQuote ? FontStyle.italic : FontStyle.normal,
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],

          // ── Review body ──────────────────────────────────────────────────
          if (isReview) ...[
            const SizedBox(height: 10),
            Row(children: [
              ...List.generate(5, (i) => Icon(
                i < (activity.rating ?? 0) ? Icons.star_rounded : Icons.star_border_rounded,
                size: 16,
                color: Colors.amber,
              )),
              const SizedBox(width: 8),
              Text('${activity.rating}/5',
                  style: GoogleFonts.outfit(
                      fontSize: 12, fontWeight: FontWeight.w600, color: c.textMuted)),
            ]),
            if (activity.reviewText != null) ...[
              const SizedBox(height: 6),
              Text(
                activity.reviewText!,
                style: GoogleFonts.outfit(fontSize: 13, color: c.text, height: 1.5),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],

          // ── Footer ──────────────────────────────────────────────────────
          const SizedBox(height: 10),
          Row(children: [
            Text(timeAgo,
                style: GoogleFonts.outfit(fontSize: 11, color: c.textMuted)),
            const Spacer(),
            if (isNote || isQuote)
              Row(children: [
                Text('All notes',
                    style: GoogleFonts.outfit(
                        fontSize: 11, fontWeight: FontWeight.w600, color: c.brand)),
                const SizedBox(width: 2),
                Icon(Icons.arrow_forward_rounded, size: 12, color: c.brand),
              ])
            else
              Row(children: [
                Text('View book',
                    style: GoogleFonts.outfit(
                        fontSize: 11, fontWeight: FontWeight.w600, color: c.brand)),
                const SizedBox(width: 2),
                Icon(Icons.arrow_forward_rounded, size: 12, color: c.brand),
              ]),
          ]),
        ]),
      ),
    );
  }
}

// ── Profile card ─────────────────────────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile, required this.c, required this.onToggleFollow});
  final PublicUserProfile profile;
  final AppPalette c;
  final VoidCallback onToggleFollow;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: c.brandSoft, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(profile.initials,
                style: GoogleFonts.outfit(
                    fontSize: 16, fontWeight: FontWeight.w700, color: c.brand)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(profile.displayName,
                  style: GoogleFonts.outfit(
                      fontSize: 15, fontWeight: FontWeight.w600, color: c.text)),
              if (profile.currentBookTitle != null) ...[
                const SizedBox(height: 2),
                Row(children: [
                  Icon(Icons.menu_book_rounded, size: 12, color: c.brand),
                  const SizedBox(width: 4),
                  Expanded(child: Text('Reading: ${profile.currentBookTitle}',
                      style: GoogleFonts.outfit(fontSize: 12, color: c.textMuted),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                ]),
              ] else ...[
                const SizedBox(height: 2),
                Text('${profile.booksCompleted} books completed',
                    style: GoogleFonts.outfit(fontSize: 12, color: c.textMuted)),
              ],
            ]),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onToggleFollow,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: profile.isFollowing ? c.surfaceAlt : c.brand,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: profile.isFollowing ? c.border : c.brand),
              ),
              child: Text(
                profile.isFollowing ? 'Following' : 'Follow',
                style: GoogleFonts.outfit(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: profile.isFollowing ? c.textMuted : Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty following ───────────────────────────────────────────────────────────

class _EmptyFollowing extends StatelessWidget {
  const _EmptyFollowing({required this.c, required this.onFind});
  final AppPalette c;
  final VoidCallback onFind;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
                color: c.brandSoft, borderRadius: BorderRadius.circular(20)),
            child: Icon(Icons.people_alt_rounded, color: c.brand, size: 40),
          ),
          const SizedBox(height: 24),
          Text('Follow readers',
              style: GoogleFonts.cormorantGaramond(
                  fontSize: 28, fontWeight: FontWeight.w600, color: c.text)),
          const SizedBox(height: 12),
          Text(
            'See what friends are reading, compare progress, and discover books through people you trust.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontSize: 14, color: c.textMuted, height: 1.6),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: onFind,
            icon: const Icon(Icons.search_rounded, size: 18),
            label: Text('Find people',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: c.brand,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),
        ]),
      ),
    );
  }
}
