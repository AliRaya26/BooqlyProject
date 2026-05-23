import 'package:booqly/Pages/HomePage.dart';
import 'package:booqly/services/auth_service.dart';
import 'package:booqly/services/calendar_service.dart';
import 'package:booqly/services/google_oauth_config.dart';
import 'package:booqly/services/preferences_service.dart';
import 'package:booqly/services/reading_motivation_service.dart';
import 'package:booqly/widgets/auth_gate.dart';
import 'package:booqly/widgets/calendar_link_web_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
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
  final AuthService _authService = AuthService();
  final CalendarService _calendarService = CalendarService();
  final ReadingMotivationService _motivationService =
      ReadingMotivationService();

  bool _loading = true;
  bool _linking = false;
  bool _loggingOut = false;
  bool _switchingAccount = false;
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
      _hasOAuthConfig = GoogleOAuthConfig.hasWebClientId &&
          GoogleOAuthConfig.isBooqlyWebClient;
      _loading = false;
    });
  }

  Future<void> _linkCalendar() async {
    setState(() => _linking = true);
    var result = await _calendarService.linkAccount();
    if (!mounted) return;

    if (!result.success &&
        result.needsWebSignInButton &&
        kIsWeb &&
        mounted) {
      setState(() => _linking = false);
      final linked = await CalendarLinkWebDialog.show(
        context,
        calendarService: _calendarService,
      );
      if (!linked || !mounted) return;
      setState(() => _linking = true);
      result = await _calendarService.finalizeWebLink();
    }

    if (!mounted) return;

    if (result.success) {
      await _applyLinkedCalendar(result.email);
    } else {
      setState(() => _linking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.errorMessage ?? 'Link failed.')),
      );
    }
  }

  Future<void> _applyLinkedCalendar(String? email) async {
    await _motivationService.requestNotificationPermission();
    await _motivationService.refreshSchedule();
    if (!mounted) return;
    setState(() {
      _calendarLinked = true;
      _calendarEmail = email;
      _remindersEnabled = true;
      _linking = false;
    });
    final resolvedEmail = email ?? await _calendarService.linkedEmail();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Google Calendar linked${resolvedEmail != null ? ' as $resolvedEmail' : ''}. '
          'Free-time nudges are on.',
        ),
      ),
    );
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
    if (!_calendarLinked) {
      await _linkCalendar();
      return;
    }

    if (value) {
      final allowed = await _motivationService.requestNotificationPermission();
      if (!allowed && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Allow notifications in your browser to get reading nudges.',
            ),
          ),
        );
      }
    }

    await _motivationService.setRemindersEnabled(value);
    if (!mounted) return;
    setState(() => _remindersEnabled = value);

    if (value && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Free-time nudges enabled. Push and email reminders run every 15 minutes during free blocks, even when Booqly is closed.',
          ),
        ),
      );
    }
  }

  Future<void> _prepareForAuthChange() async {
    await _calendarService.unlinkAccount();
    await _motivationService.cancelAll();
    await _motivationService.disableServerNudgesOnSignOut();
    AuthNavigationController.instance.clearSignedInCache();
  }

  Future<void> _switchAccount() async {
    if (_switchingAccount || _loggingOut) return;

    final choice = await showModalBottomSheet<_SwitchAccountChoice>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Switch account',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 26,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sign in with a different Booqly account. Your current session will end.',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  height: 1.45,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.mail_outline_rounded, color: AppColors.gold),
                title: Text(
                  'Sign in with email',
                  style: GoogleFonts.outfit(color: AppColors.textPrimary),
                ),
                onTap: () => Navigator.pop(ctx, _SwitchAccountChoice.email),
              ),
              ListTile(
                leading: const Icon(Icons.g_mobiledata, color: AppColors.gold, size: 28),
                title: Text(
                  'Continue with Google',
                  style: GoogleFonts.outfit(color: AppColors.textPrimary),
                ),
                onTap: () => Navigator.pop(ctx, _SwitchAccountChoice.google),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice == null || !mounted) return;

    setState(() => _switchingAccount = true);
    await _prepareForAuthChange();

    if (choice == _SwitchAccountChoice.google) {
      final configError = GoogleOAuthConfig.mismatchMessage;
      if (configError != null) {
        if (mounted) {
          setState(() => _switchingAccount = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(configError)),
          );
        }
        return;
      }

      await _authService.signOut();
      final result = await _authService.signInWithGoogle(forceAccountPicker: true);
      if (!mounted) return;

      if (!result.isSuccess) {
        setState(() => _switchingAccount = false);
        AuthNavigationController.instance.requestLoginScreen();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.errorMessage ?? 'Google sign-in failed.')),
        );
        return;
      }

      if (result.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.errorMessage!)),
        );
      }

      final prefs = PreferencesService();
      final completed = await prefs
          .hasCompletedPreferences(result.user!.uid)
          .catchError((_) => false);
      AuthNavigationController.instance.cachePreferencesCompleted(completed);
      setState(() => _switchingAccount = false);
      return;
    }

    await _authService.signOut();
    if (!mounted) return;
    AuthNavigationController.instance.requestLoginScreen();
    setState(() => _switchingAccount = false);
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Log out?',
          style: GoogleFonts.outfit(color: AppColors.textPrimary),
        ),
        content: Text(
          'You will need to sign in again to access your library.',
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
              'Log out',
              style: GoogleFonts.outfit(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _loggingOut = true);
    await _prepareForAuthChange();
    AuthNavigationController.instance.clearLoginScreenRequest();
    await _authService.signOut();
    if (!mounted) return;
    setState(() => _loggingOut = false);
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
                if (!_hasOAuthConfig ||
                    (!_calendarLinked && _calendarService.webOrigin != null)) ...[
                  const SizedBox(height: 10),
                  _hintCard(
                    GoogleOAuthConfig.mismatchMessage ??
                        'Calendar Link uses google_sign_in. Add this origin to your '
                            '87414724762-… Web client in Google Cloud:\n'
                            '${_calendarService.webOrigin}\n'
                            '(see firebase/GOOGLE_CALENDAR_SETUP.md)',
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
                      : 'Tap to link Google Calendar first',
                  trailing: Switch.adaptive(
                    value: _remindersEnabled && _calendarLinked,
                    onChanged: _linking
                        ? null
                        : (v) => _toggleReminders(v),
                    activeThumbColor: AppColors.gold,
                    activeTrackColor: AppColors.goldDim,
                  ),
                  onTap: _linking || _calendarLinked ? null : _linkCalendar,
                ),
                const SizedBox(height: 12),
                _hintCard(
                  'Nudges fire during free gaps between calendar events (8am–midnight, 25+ minutes) — not at event times. Example: with a 9pm event, you\'ll get reminders during the open time before it. Local alerts repeat every 15 minutes in each gap. Push/email when the app is closed need Cloud Functions deployed (scripts/deploy-email.ps1).',
                ),
                const SizedBox(height: 28),
                _sectionLabel('Account'),
                const SizedBox(height: 10),
                _SettingsTile(
                  icon: Icons.switch_account_outlined,
                  title: 'Switch account',
                  subtitle: 'Sign in with a different Booqly account',
                  trailing: _switchingAccount
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.gold,
                          ),
                        )
                      : Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.gold.withValues(alpha: 0.9),
                        ),
                  onTap: _switchingAccount ? null : _switchAccount,
                ),
                const SizedBox(height: 10),
                _SettingsTile(
                  icon: Icons.logout_rounded,
                  title: 'Log out',
                  subtitle: 'Sign out of your Booqly account',
                  trailing: _loggingOut
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.redAccent,
                          ),
                        )
                      : Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.redAccent.withValues(alpha: 0.9),
                        ),
                  onTap: _loggingOut ? null : _logout,
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

enum _SwitchAccountChoice { email, google }

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
