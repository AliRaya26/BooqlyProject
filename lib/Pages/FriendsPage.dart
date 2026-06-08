import 'package:booqly/Pages/ReadingWrappedPage.dart';
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

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _loadFollowing();
    _loadFeed();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
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
    // Refresh search results too
    if (_lastQuery.isNotEmpty) await _search(_lastQuery + ' ');
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
          IconButton(
            icon: Icon(Icons.auto_awesome_rounded, color: c.brand),
            tooltip: 'Reading Wrapped',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ReadingWrappedPage())),
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
            Tab(text: 'Find people'),
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
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: c.text)),
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
        itemBuilder: (_, i) => _ActivityCard(activity: _feed[i], c: c),
      ),
    );
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
          // Avatar
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: c.brandSoft,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(profile.initials,
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: c.brand)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(profile.displayName,
                  style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: c.text)),
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

// ── Activity card ─────────────────────────────────────────────────────────────

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.activity, required this.c});
  final FriendActivity activity;
  final AppPalette c;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final diff = now.difference(activity.timestamp);
    final timeAgo = diff.inDays > 0 ? '${diff.inDays}d ago'
        : diff.inHours > 0 ? '${diff.inHours}h ago'
        : '${diff.inMinutes}m ago';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: c.brandSoft, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(
              activity.userName.isNotEmpty ? activity.userName[0].toUpperCase() : '?',
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: c.brand),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              RichText(text: TextSpan(
                style: GoogleFonts.outfit(fontSize: 14, color: c.text),
                children: [
                  TextSpan(text: activity.userName,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(
                    text: activity.activityType == 'completed'
                        ? ' finished reading '
                        : ' is reading ',
                    style: TextStyle(color: c.textMuted),
                  ),
                  TextSpan(text: activity.bookTitle,
                      style: TextStyle(fontWeight: FontWeight.w600, color: c.brand)),
                ],
              )),
              const SizedBox(height: 4),
              Text(timeAgo, style: GoogleFonts.outfit(fontSize: 11, color: c.textMuted)),
            ]),
          ),
          Icon(
            activity.activityType == 'completed'
                ? Icons.check_circle_rounded
                : Icons.menu_book_rounded,
            color: activity.activityType == 'completed' ? Colors.green : c.brand,
            size: 18,
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
            decoration: BoxDecoration(color: c.brandSoft, borderRadius: BorderRadius.circular(20)),
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
            label: Text('Find people', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: c.brand, foregroundColor: Colors.white,
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
