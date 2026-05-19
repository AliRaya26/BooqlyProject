import 'package:booqly/Pages/HomePage.dart';
import 'package:booqly/services/calendar_service.dart';
import 'package:booqly/services/reading_motivation_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// App settings: Google Calendar linking and free-time reading reminders.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, this.embeddedInTab = false});

  /// When true (bottom nav Profile tab), hide the back button.
  final bool embeddedInTab;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final CalendarService _calendarService = CalendarService();
  final ReadingMotivationService _motivationService =
      ReadingMotivationService();

  bool _loading = true;
  bool _linking = false;
  bool _calendarLinked = false;
  String? _calendarEmail;
  bool _remindersEnabled = true;
  bool _hasOAuthConfig = false;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final linked = await _calendarService.isLinked();
    final email = await _calendarService.linkedEmail();
    final reminders = await _motivationService.areRemindersEnabled();

    if (!mounted) return;
    setState(() {
      _calendarLinked = linked;
      _calendarEmail = email;
      _remindersEnabled = reminders;
      _hasOAuthConfig = _calendarService.hasOAuthConfig;
      _loading = false;
    });
  }

  Future<void> _linkCalendar() async {
    setState(() => _linking = true);
    final result = await _calendarService.linkAccount();
    if (!mounted) return;

    if (result.success) {
      await _motivationService.requestNotificationPermission();
      await _motivationService.refreshSchedule();
      setState(() {
        _calendarLinked = true;
        _calendarEmail = result.email;
        _remindersEnabled = true;
        _linking = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Google Calendar linked as ${result.email ?? 'your account'}.',
          ),
        ),
      );
    } else {
      setState(() => _linking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.errorMessage ?? 'Link failed.')),
      );
    }
  }

  Future<void> _unlinkCalendar() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Unlink Google Calendar?',
          style: GoogleFonts.outfit(color: AppColors.textPrimary),
        ),
        content: Text(
          'Free-time reading reminders will stop until you link again.',
          style: GoogleFonts.outfit(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.outfit()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Unlink',
              style: GoogleFonts.outfit(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await _calendarService.unlinkAccount();
    await _motivationService.cancelAll();
    await _loadState();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Google Calendar unlinked.')),
    );
  }

  Future<void> _toggleReminders(bool value) async {
    await _motivationService.setRemindersEnabled(value);
    setState(() => _remindersEnabled = value);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName?.trim();
    final email = user?.email;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: widget.embeddedInTab
            ? null
            : IconButton(
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: AppColors.gold,
                ),
                onPressed: () => Navigator.maybePop(context),
              ),
        automaticallyImplyLeading: !widget.embeddedInTab,
        title: Text(
          'Settings',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.gold),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
              children: [
                if (displayName != null || email != null) ...[
                  Text(
                    displayName ?? 'Reader',
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 28,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (email != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                ],
                _sectionLabel('Integrations'),
                const SizedBox(height: 10),
                _SettingsTile(
                  icon: Icons.calendar_month_rounded,
                  title: 'Google Calendar',
                  subtitle: _calendarLinked
                      ? (_calendarEmail ?? 'Connected')
                      : 'Link to find free time between events',
                  trailing: _linking
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.gold,
                          ),
                        )
                      : Text(
                          _calendarLinked ? 'Linked' : 'Link',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _calendarLinked
                                ? AppColors.gold
                                : AppColors.textSecondary,
                          ),
                        ),
                  onTap: _linking
                      ? null
                      : (_calendarLinked ? _unlinkCalendar : _linkCalendar),
                ),
                if (!_hasOAuthConfig) ...[
                  const SizedBox(height: 10),
                  _hintCard(
                    'Add GOOGLE_WEB_CLIENT_ID in assets/config.env, then enable the Google Calendar API in Google Cloud Console.',
                  ),
                ],
                const SizedBox(height: 28),
                _sectionLabel('Reading reminders'),
                const SizedBox(height: 10),
                _SettingsTile(
                  icon: Icons.notifications_active_outlined,
                  title: 'Free-time nudges',
                  subtitle: _calendarLinked
                      ? 'Notify you to read instead of scroll when your calendar is open'
                      : 'Link Google Calendar first',
                  trailing: Switch.adaptive(
                    value: _remindersEnabled && _calendarLinked,
                    onChanged: _calendarLinked
                        ? (v) => _toggleReminders(v)
                        : null,
                    activeThumbColor: AppColors.gold,
                    activeTrackColor: AppColors.goldDim,
                  ),
                  onTap: null,
                ),
                const SizedBox(height: 12),
                _hintCard(
                  'Booqly checks today\'s calendar (8am–10pm) for gaps of 25+ minutes and sends a gentle reminder at the start of each block.',
                ),
              ],
            ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.outfit(
        fontSize: 11,
        letterSpacing: 0.14,
        color: AppColors.gold,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _hintCard(String text) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          fontSize: 12,
          height: 1.45,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.goldMuted,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.gold, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppColors.textMuted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}
