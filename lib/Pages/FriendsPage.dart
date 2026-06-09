import 'package:booqly/Pages/BookDetailPage.dart';
import 'package:booqly/services/dummy_data_service.dart';
import 'package:booqly/services/social_service.dart';
import 'package:booqly/theme/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FriendsPage — 2 tabs: Feed | Find People
// ─────────────────────────────────────────────────────────────────────────────

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

  // ── Feed ─────────────────────────────────────────────────────────────────
  List<FriendActivity> _feed = [];
  bool _loadingFeed = true;

  // ── Likes (optimistic) ───────────────────────────────────────────────────
  Set<String> _likedIds = {};

  // ── Following UIDs (optimistic — updated immediately on follow/unfollow) ─
  Set<String> _followingUids = {};

  // ── Pending follow actions (for spinner) ─────────────────────────────────
  final Set<String> _pendingUids = {};

  // ── Search ───────────────────────────────────────────────────────────────
  List<PublicUserProfile> _searchResults = [];
  bool _searching = false;
  String _lastQuery = '';

  bool _seeding = false;

  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _init();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Initialise ─────────────────────────────────────────────────────────

  Future<void> _init() async {
    setState(() { _loadingFeed = true; _seeding = false; });

    // Load following UIDs first so follow buttons render correctly
    final profiles = await _service.getFollowingProfiles();
    if (!mounted) return;

    if (profiles.isEmpty) {
      setState(() => _seeding = true);
      await DummyDataService().seed();
      final seeded = await _service.getFollowingProfiles();
      if (mounted) {
        setState(() {
          _followingUids = seeded.map((p) => p.uid).toSet();
          _seeding = false;
        });
      }
    } else {
      setState(() {
        _followingUids = profiles.map((p) => p.uid).toSet();
      });
    }

    // Feed + likes in parallel
    final results = await Future.wait([
      _service.getActivityFeed(),
      _service.getLikedPostIds(),
    ]);
    if (!mounted) return;
    setState(() {
      _feed = results[0] as List<FriendActivity>;
      _likedIds = results[1] as Set<String>;
      _loadingFeed = false;
    });
  }

  Future<void> _refreshFeed() async {
    final results = await Future.wait([
      _service.getActivityFeed(),
      _service.getLikedPostIds(),
    ]);
    if (!mounted) return;
    setState(() {
      _feed = results[0] as List<FriendActivity>;
      _likedIds = results[1] as Set<String>;
    });
  }

  // ── Follow / Unfollow ─────────────────────────────────────────────────

  /// Optimistic follow toggle: updates UI instantly, then writes to Firestore.
  Future<void> _toggleFollow(String uid) async {
    if (_pendingUids.contains(uid)) return;
    final wasFollowing = _followingUids.contains(uid);

    // Instant UI update
    setState(() {
      _pendingUids.add(uid);
      if (wasFollowing) {
        _followingUids.remove(uid);
      } else {
        _followingUids.add(uid);
      }
    });

    try {
      if (wasFollowing) {
        await _service.unfollow(uid);
      } else {
        await _service.follow(uid);
      }
      // Refresh feed in background after follow state changes
      _refreshFeed();
    } catch (e) {
      // Revert on error
      debugPrint('_toggleFollow error: $e');
      if (mounted) {
        setState(() {
          if (wasFollowing) {
            _followingUids.add(uid);
          } else {
            _followingUids.remove(uid);
          }
        });
      }
    } finally {
      if (mounted) setState(() => _pendingUids.remove(uid));
    }
  }

  // ── Like / Unlike ──────────────────────────────────────────────────────

  Future<void> _toggleLike(String postId) async {
    final wasLiked = _likedIds.contains(postId);
    setState(() {
      if (wasLiked) {
        _likedIds.remove(postId);
      } else {
        _likedIds.add(postId);
      }
    });
    try {
      if (wasLiked) {
        await _service.unlikePost(postId);
      } else {
        await _service.likePost(postId);
      }
    } catch (e) {
      // Revert
      if (mounted) {
        setState(() {
          if (wasLiked) {
            _likedIds.add(postId);
          } else {
            _likedIds.remove(postId);
          }
        });
      }
    }
  }

  // ── Search ────────────────────────────────────────────────────────────

  Future<void> _search(String q) async {
    final trimmed = q.trim();
    if (trimmed == _lastQuery) return;
    _lastQuery = trimmed;
    if (trimmed.length < 2) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _searching = true);
    final results = await _service.searchUsers(trimmed);
    if (mounted) setState(() { _searchResults = results; _searching = false; });
  }

  // ── Navigate to book ──────────────────────────────────────────────────

  Future<void> _openBook(BuildContext ctx, FriendActivity activity) async {
    final book = await _service.getBookModelForActivity(activity);
    if (!ctx.mounted) return;
    if (book != null) {
      Navigator.push(ctx,
          MaterialPageRoute(builder: (_) => BookDetailPage(book: book)));
    } else {
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Text('"${activity.bookTitle}" could not be opened.',
            style: GoogleFonts.outfit()),
        backgroundColor: AppColors.of(ctx).brand,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  // ── Profile sheet ─────────────────────────────────────────────────────

  void _showProfile(BuildContext ctx, String uid, String name) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProfileSheet(
        uid: uid,
        name: name,
        service: _service,
        isFollowing: _followingUids.contains(uid),
        isPending: _pendingUids.contains(uid),
        onToggleFollow: () => _toggleFollow(uid),
        c: AppColors.of(ctx),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('Friends',
            style: GoogleFonts.figtree(
                fontSize: 26, fontWeight: FontWeight.w700, color: c.text)),
        actions: [
          _seeding
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: c.brand)))
              : IconButton(
                  icon: Icon(Icons.refresh_rounded, color: c.textMuted),
                  tooltip: 'Refresh feed',
                  onPressed: _init,
                ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: c.brand,
          unselectedLabelColor: c.textMuted,
          indicatorColor: c.brand,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle:
              GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 13),
          unselectedLabelStyle: GoogleFonts.outfit(fontSize: 13),
          tabs: const [
            Tab(text: 'Feed'),
            Tab(text: 'Find People'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildFeedTab(c),
          _buildFindTab(c),
        ],
      ),
    );
  }

  // ── Feed tab ───────────────────────────────────────────────────────────────

  Widget _buildFeedTab(AppPalette c) {
    if (_loadingFeed) {
      return Center(child: CircularProgressIndicator(color: c.brand));
    }
    if (_feed.isEmpty) {
      return _EmptyFeed(
          c: c,
          onFind: () => _tabs.animateTo(1),
          onRefresh: _init);
    }
    return RefreshIndicator(
      onRefresh: _refreshFeed,
      color: c.brand,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: _feed.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (ctx, i) {
          final a = _feed[i];
          return _PostCard(
            activity: a,
            c: c,
            isLiked: _likedIds.contains(a.postId),
            onLike: () => _toggleLike(a.postId),
            onAvatarTap: () => _showProfile(ctx, a.ownerUid, a.userName),
            onBookTap: () => _openBook(ctx, a),
          );
        },
      ),
    );
  }

  // ── Find People tab ────────────────────────────────────────────────────────

  Widget _buildFindTab(AppPalette c) {
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
                      child: SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: c.brand)))
                  : null,
              filled: true,
              fillColor: c.surfaceAlt,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: c.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: c.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: c.brand, width: 1.5)),
            ),
          ),
        ),
        Expanded(
          child: _searchResults.isEmpty
              ? Center(
                  child: Text(
                    _searchCtrl.text.length < 2
                        ? 'Type a name or email to search'
                        : 'No users found',
                    style: GoogleFonts.outfit(
                        color: c.textMuted, fontSize: 14),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: _searchResults.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final p = _searchResults[i];
                    return _SearchProfileCard(
                      profile: p,
                      c: c,
                      isFollowing: _followingUids.contains(p.uid),
                      isPending: _pendingUids.contains(p.uid),
                      onToggleFollow: () => _toggleFollow(p.uid),
                      onAvatarTap: () =>
                          _showProfile(ctx, p.uid, p.displayName),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PostCard — one social post in the feed
// ─────────────────────────────────────────────────────────────────────────────

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.activity,
    required this.c,
    required this.isLiked,
    required this.onLike,
    required this.onAvatarTap,
    required this.onBookTap,
  });

  final FriendActivity activity;
  final AppPalette c;
  final bool isLiked;
  final VoidCallback onLike;
  final VoidCallback onAvatarTap;
  final VoidCallback onBookTap;

  @override
  Widget build(BuildContext context) {
    final a = activity;
    final type = a.activityType;
    final isNote = type == 'note';
    final isQuote = type == 'quote';
    final isReview = type == 'review';
    final isCompleted = type == 'completed';

    final now = DateTime.now();
    final diff = now.difference(a.timestamp);
    final timeAgo = diff.inDays > 0
        ? '${diff.inDays}d ago'
        : diff.inHours > 0
            ? '${diff.inHours}h ago'
            : diff.inMinutes > 0
                ? '${diff.inMinutes}m ago'
                : 'just now';

    String actionText;
    IconData typeIcon;
    Color typeColor;
    if (isQuote) {
      actionText = 'saved a quote from';
      typeIcon = Icons.format_quote_rounded;
      typeColor = c.brand;
    } else if (isNote) {
      actionText = 'took a note on';
      typeIcon = Icons.sticky_note_2_outlined;
      typeColor = c.brand;
    } else if (isReview) {
      actionText = 'reviewed';
      typeIcon = Icons.star_rounded;
      typeColor = c.warning;
    } else if (isCompleted) {
      actionText = 'finished reading';
      typeIcon = Icons.check_circle_rounded;
      typeColor = c.success;
    } else {
      actionText = 'is reading';
      typeIcon = Icons.menu_book_rounded;
      typeColor = c.brand;
    }

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Header ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                // Avatar — tap to open profile sheet
                GestureDetector(
                  onTap: onAvatarTap,
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                        color: c.brandSoft, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text(
                      a.userName.isNotEmpty
                          ? a.userName[0].toUpperCase()
                          : '?',
                      style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: c.brand),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: onAvatarTap,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.userName,
                            style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: c.text)),
                        RichText(
                          text: TextSpan(
                            style: GoogleFonts.outfit(
                                fontSize: 12, color: c.textMuted),
                            children: [
                              TextSpan(text: '$actionText '),
                              TextSpan(
                                  text: a.bookTitle,
                                  style: TextStyle(
                                      color: c.brand,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(typeIcon, color: typeColor, size: 20),
              ],
            ),
          ),

          // ── Body ────────────────────────────────────────────────────────
          if ((isNote || isQuote) && a.noteText != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isQuote ? c.brandSoft : c.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: isQuote
                          ? c.brand.withValues(alpha: 0.25)
                          : c.border),
                ),
                child: Text(
                  a.noteText!,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: c.text,
                    height: 1.55,
                    fontStyle:
                        isQuote ? FontStyle.italic : FontStyle.normal,
                  ),
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],

          if (isReview) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: List.generate(5, (i) => Icon(
                      i < (a.rating ?? 0)
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      size: 18,
                      color: c.warning,
                    )),
                  ),
                  if (a.reviewText != null) ...[
                    const SizedBox(height: 6),
                    Text(a.reviewText!,
                        style: GoogleFonts.outfit(
                            fontSize: 14, color: c.text, height: 1.55),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
          ],

          if (isCompleted) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                    color: c.successSoft,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: c.success.withValues(alpha: 0.2))),
                child: Row(children: [
                  Icon(Icons.auto_stories_rounded,
                      color: c.success, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                        '${a.userName.split(' ').first} finished "${a.bookTitle}"  🎉',
                        style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: c.success,
                            fontWeight: FontWeight.w500)),
                  ),
                ]),
              ),
            ),
          ],

          // ── Footer ──────────────────────────────────────────────────────
          Divider(height: 1, color: c.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Row(
              children: [
                // Like button
                GestureDetector(
                  onTap: onLike,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isLiked
                          ? c.brand.withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: Icon(
                            isLiked
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            key: ValueKey(isLiked),
                            size: 18,
                            color:
                                isLiked ? c.brand : c.textMuted,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text('Like',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: isLiked
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color:
                                  isLiked ? c.brand : c.textMuted,
                            )),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 6),

                // Timestamp
                Text(timeAgo,
                    style: GoogleFonts.outfit(
                        fontSize: 11, color: c.textMuted)),

                const Spacer(),

                // View book
                GestureDetector(
                  onTap: onBookTap,
                  child: Row(children: [
                    Text('View book',
                        style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: c.brand)),
                    const SizedBox(width: 3),
                    Icon(Icons.arrow_forward_rounded,
                        size: 13, color: c.brand),
                  ]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SearchProfileCard — one result row in Find People
// ─────────────────────────────────────────────────────────────────────────────

class _SearchProfileCard extends StatelessWidget {
  const _SearchProfileCard({
    required this.profile,
    required this.c,
    required this.isFollowing,
    required this.isPending,
    required this.onToggleFollow,
    required this.onAvatarTap,
  });

  final PublicUserProfile profile;
  final AppPalette c;
  final bool isFollowing;
  final bool isPending;
  final VoidCallback onToggleFollow;
  final VoidCallback onAvatarTap;

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
          // Avatar
          GestureDetector(
            onTap: onAvatarTap,
            child: Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                  color: c.brandSoft, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(profile.initials,
                  style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: c.brand)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: onAvatarTap,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.displayName,
                        style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: c.text)),
                    if (profile.currentBookTitle != null) ...[
                      const SizedBox(height: 2),
                      Row(children: [
                        Icon(Icons.menu_book_rounded,
                            size: 12, color: c.brand),
                        const SizedBox(width: 4),
                        Expanded(
                            child: Text(
                                'Reading: ${profile.currentBookTitle}',
                                style: GoogleFonts.outfit(
                                    fontSize: 12, color: c.textMuted),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis)),
                      ]),
                    ] else ...[
                      const SizedBox(height: 2),
                      Text('${profile.booksCompleted} books completed',
                          style: GoogleFonts.outfit(
                              fontSize: 12, color: c.textMuted)),
                    ],
                  ]),
            ),
          ),
          const SizedBox(width: 10),
          _FollowBtn(
            isFollowing: isFollowing,
            isPending: isPending,
            c: c,
            onTap: onToggleFollow,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _FollowBtn — reliable follow/unfollow button
// ─────────────────────────────────────────────────────────────────────────────

class _FollowBtn extends StatelessWidget {
  const _FollowBtn({
    required this.isFollowing,
    required this.isPending,
    required this.c,
    required this.onTap,
  });
  final bool isFollowing;
  final bool isPending;
  final AppPalette c;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isPending ? null : onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: isFollowing ? c.surfaceAlt : c.brand,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: isFollowing ? c.border : c.brand, width: 1),
          ),
          child: isPending
              ? SizedBox(
                  width: 52, height: 16,
                  child: Center(
                    child: SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: isFollowing ? c.brand : c.onPrimary,
                      ),
                    ),
                  ),
                )
              : Text(
                  isFollowing ? 'Following' : 'Follow',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isFollowing ? c.textMuted : c.onPrimary,
                  ),
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ProfileSheet — bottom sheet shown when tapping an avatar
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileSheet extends StatefulWidget {
  const _ProfileSheet({
    required this.uid,
    required this.name,
    required this.service,
    required this.isFollowing,
    required this.isPending,
    required this.onToggleFollow,
    required this.c,
  });
  final String uid;
  final String name;
  final SocialService service;
  final bool isFollowing;
  final bool isPending;
  final VoidCallback onToggleFollow;
  final AppPalette c;

  @override
  State<_ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<_ProfileSheet> {
  // Profile details loaded async
  String? _currentBook;
  int _booksCompleted = 0;
  bool _loading = true;

  // Local follow state (synced from parent, updates immediately on tap)
  late bool _isFollowing;
  late bool _isPending;

  @override
  void initState() {
    super.initState();
    _isFollowing = widget.isFollowing;
    _isPending = widget.isPending;
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final db = FirebaseFirestore.instance;

      // Currently reading
      final readingSnap = await db
          .collection('users')
          .doc(widget.uid)
          .collection('library')
          .where('status', isEqualTo: 'reading')
          .orderBy('lastReadAt', descending: true)
          .limit(1)
          .get();
      if (readingSnap.docs.isNotEmpty) {
        _currentBook =
            readingSnap.docs.first.data()['title'] as String?;
      }

      // Completed count
      final completedSnap = await db
          .collection('users')
          .doc(widget.uid)
          .collection('library')
          .where('status', isEqualTo: 'completed')
          .count()
          .get();
      _booksCompleted = completedSnap.count ?? 0;
    } catch (_) {}

    if (mounted) setState(() => _loading = false);
  }

  @override
  void didUpdateWidget(_ProfileSheet old) {
    super.didUpdateWidget(old);
    // Reflect parent's pending state if it changes while sheet is open
    if (old.isPending != widget.isPending) {
      setState(() => _isPending = widget.isPending);
    }
  }

  void _handleFollow() {
    setState(() {
      _isPending = true;
      _isFollowing = !_isFollowing;
    });
    widget.onToggleFollow();
    // Clear spinner after a short delay (parent's state drives real outcome)
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _isPending = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final initials = widget.name.isNotEmpty
        ? widget.name
            .split(' ')
            .where((w) => w.isNotEmpty)
            .take(2)
            .map((w) => w[0].toUpperCase())
            .join()
        : '?';

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 20),
            decoration: BoxDecoration(
                color: c.border, borderRadius: BorderRadius.circular(2)),
          ),

          // Avatar
          Container(
            width: 72, height: 72,
            decoration:
                BoxDecoration(color: c.brandSoft, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(initials,
                style: GoogleFonts.outfit(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: c.brand)),
          ),

          const SizedBox(height: 12),

          // Name
          Text(widget.name,
              style: GoogleFonts.figtree(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: c.text)),

          const SizedBox(height: 16),

          // Stats row
          if (_loading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: c.brand)),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _statChip(c, Icons.check_circle_rounded,
                    '$_booksCompleted', 'completed'),
                const SizedBox(width: 16),
                if (_currentBook != null)
                  _statChip(c, Icons.menu_book_rounded,
                      'Reading', _currentBook!),
              ],
            ),

          const SizedBox(height: 20),

          // Follow button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: SizedBox(
              width: double.infinity,
              child: _FollowBtn(
                isFollowing: _isFollowing,
                isPending: _isPending,
                c: c,
                onTap: _handleFollow,
              ),
            ),
          ),

          const SizedBox(height: 28),
        ],
      ),
    );
  }

  Widget _statChip(
      AppPalette c, IconData icon, String label, String sub) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: c.brand),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: c.text)),
              Text(sub,
                  style: GoogleFonts.outfit(
                      fontSize: 10, color: c.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _EmptyFeed
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed(
      {required this.c, required this.onFind, required this.onRefresh});
  final AppPalette c;
  final VoidCallback onFind;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
                color: c.brandSoft,
                borderRadius: BorderRadius.circular(20)),
            child: Icon(Icons.dynamic_feed_rounded,
                color: c.brand, size: 40),
          ),
          const SizedBox(height: 24),
          Text('Your feed is empty',
              style: GoogleFonts.figtree(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: c.text)),
          const SizedBox(height: 12),
          Text(
            'Follow readers to see their notes, quotes, and reviews here.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
                fontSize: 14, color: c.textMuted, height: 1.6),
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: onFind,
                icon: const Icon(Icons.search_rounded, size: 18),
                label: Text('Find people',
                    style:
                        GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.brand,
                  foregroundColor: c.onPrimary,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text('Refresh',
                    style:
                        GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: c.brand,
                  side: BorderSide(color: c.brand),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        ]),
      ),
    );
  }
}
