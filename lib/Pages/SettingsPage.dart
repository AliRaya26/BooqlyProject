import 'package:booqly/Pages/GoalsPage.dart';
import 'package:booqly/Pages/ReadingWrappedPage.dart';
import 'package:booqly/theme/app_colors.dart';
import 'package:booqly/theme/theme_service.dart';
import 'package:booqly/widgets/auth_gate.dart';
import 'package:booqly/services/auth_service.dart';
import 'package:booqly/services/calendar_service.dart';
import 'package:booqly/services/google_oauth_config.dart';
import 'package:booqly/services/preferences_service.dart';
import 'package:booqly/services/reading_motivation_service.dart';
import 'package:booqly/widgets/calendar_link_web_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// App settings: Gemini AI key, Google Calendar linking, account management.
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

  // General loading
  bool _loading = true;

  // Calendar
  bool _linking = false;
  bool _calendarLinked = false;
  String? _calendarEmail;
  bool _remindersEnabled = true;
  bool _hasOAuthConfig = false;

  // Account
  bool _loggingOut = false;
  bool _switchingAccount = false;


  @override
  void initState() {
    super.initState();
    _loadState();
  }

  @override
  void dispose() {
    super.dispose();
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

  // ── Calendar ────────────────────────────────────────────────────────────────

  Future<void> _linkCalendar() async {
    setState(() => _linking = true);
    var result = await _calendarService.linkAccount();
    if (!mounted) return;

    if (!result.success && result.needsWebSignInButton && kIsWeb && mounted) {
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
          'Google Calendar linked'
          '${resolvedEmail != null ? ' as $resolvedEmail' : ''}. '
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
        title: Text('Unlink Google Calendar?',
            style: GoogleFonts.outfit(color: AppColors.text)),
        content: Text(
          'Free-time reading reminders will stop until you link again.',
          style: GoogleFonts.outfit(color: AppColors.textSub),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: GoogleFonts.outfit())),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Unlink',
                  style: GoogleFonts.outfit(color: Colors.redAccent))),
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
      final allowed =
          await _motivationService.requestNotificationPermission();
      if (!allowed && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Allow notifications in your browser to get reading nudges.'),
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
              'Free-time nudges enabled — you\'ll be reminded to read during open calendar gaps.'),
        ),
      );
    }
  }

  // ── Account ─────────────────────────────────────────────────────────────────

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
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
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
              Text('Switch account',
                  style: GoogleFonts.cormorantGaramond(
                      fontSize: 26, color: AppColors.text)),
              const SizedBox(height: 8),
              Text(
                'Sign in with a different Booqly account. Your current session will end.',
                style: GoogleFonts.outfit(
                    fontSize: 13, height: 1.45, color: AppColors.textMuted),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.mail_outline_rounded,
                    color: AppColors.brand),
                title: Text('Sign in with email',
                    style: GoogleFonts.outfit(color: AppColors.text)),
                onTap: () => Navigator.pop(ctx, _SwitchAccountChoice.email),
              ),
              ListTile(
                leading: const Icon(Icons.g_mobiledata,
                    color: AppColors.brand, size: 28),
                title: Text('Continue with Google',
                    style: GoogleFonts.outfit(color: AppColors.text)),
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
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(configError)));
        }
        return;
      }

      await _authService.signOut();
      final result =
          await _authService.signInWithGoogle(forceAccountPicker: true);
      if (!mounted) return;

      if (!result.isSuccess) {
        setState(() => _switchingAccount = false);
        AuthNavigationController.instance.requestLoginScreen();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(result.errorMessage ?? 'Google sign-in failed.')),
        );
        return;
      }

      if (result.errorMessage != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(result.errorMessage!)));
      }

      final prefs = PreferencesService();
      final completed = await prefs
          .hasCompletedPreferences(result.user!.uid)
          .catchError((_) => false);
      AuthNavigationController.instance
          .cachePreferencesCompleted(completed);
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
        title: Text('Log out?',
            style: GoogleFonts.outfit(color: AppColors.text)),
        content: Text(
          'You will need to sign in again to access your library.',
          style: GoogleFonts.outfit(color: AppColors.textSub),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: GoogleFonts.outfit())),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Log out',
                  style: GoogleFonts.outfit(color: Colors.redAccent))),
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

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName?.trim();
    final email = user?.email;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        elevation: 0,
        leading: widget.embeddedInTab
            ? null
            : IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: c.brand),
                onPressed: () => Navigator.maybePop(context),
              ),
        automaticallyImplyLeading: !widget.embeddedInTab,
        title: Text(
          'Profile & Settings',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            color: c.text,
          ),
        ),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: c.brand))
          : ListView(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 40),
              children: [
                // ── User header ──────────────────────────────────────────
                if (displayName != null || email != null) ...[
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: c.brandSoft,
                        child: Text(
                          (displayName?.isNotEmpty == true
                                  ? displayName![0]
                                  : (email?.isNotEmpty == true
                                      ? email![0]
                                      : '?'))
                              .toUpperCase(),
                          style: GoogleFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: c.brand,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (displayName != null)
                              Text(
                                displayName,
                                style: GoogleFonts.outfit(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: c.text,
                                ),
                              ),
                            if (email != null)
                              Text(
                                email,
                                style: GoogleFonts.outfit(
                                    fontSize: 13, color: c.textMuted),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                ],

                // ── My Reading Year ──────────────────────────────────────
                _sectionLabel('My Reading Year', c),
                const SizedBox(height: 10),
                _SettingsTileC(
                  icon: Icons.flag_rounded,
                  title: 'Reading Goals',
                  subtitle: 'Set your yearly and daily reading targets',
                  palette: c,
                  trailing: Icon(Icons.chevron_right_rounded,
                      color: c.brand.withValues(alpha: 0.9)),
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const GoalsPage())),
                ),
                const SizedBox(height: 10),
                _SettingsTileC(
                  icon: Icons.auto_awesome_rounded,
                  title: 'Reading Wrapped ${DateTime.now().year}',
                  subtitle: 'Your year in books — stats, highlights & more',
                  palette: c,
                  trailing: Icon(Icons.chevron_right_rounded,
                      color: c.brand.withValues(alpha: 0.9)),
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ReadingWrappedPage())),
                ),
                const SizedBox(height: 28),

                // ── Appearance (dark mode — first thing users look for) ──
                _sectionLabel('Appearance', c),
                const SizedBox(height: 10),
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: ThemeService.instance.notifier,
                  builder: (ctx, mode, child) {
                    final isDark = mode == ThemeMode.dark;
                    return _SettingsTileC(
                      icon: isDark
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                      title: 'Dark mode',
                      subtitle: isDark ? 'Dark theme active' : 'Light theme active',
                      trailing: Switch.adaptive(
                        value: isDark,
                        onChanged: (v) => ThemeService.instance
                            .setMode(v ? ThemeMode.dark : ThemeMode.light),
                        activeThumbColor: c.brand,
                        activeTrackColor: c.brandMid,
                      ),
                      palette: c,
                    );
                  },
                ),
                const SizedBox(height: 28),

                // ── Calendar ─────────────────────────────────────────────
                _sectionLabel('Integrations', c),
                const SizedBox(height: 10),
                _CalendarTile(
                  linked: _calendarLinked,
                  email: _calendarEmail,
                  linking: _linking,
                  onLink: _linking ? null : _linkCalendar,
                  onUnlink: _linking ? null : _unlinkCalendar,
                  palette: c,
                ),
                const SizedBox(height: 20),
                _SettingsTileC(
                  icon: Icons.notifications_active_outlined,
                  title: 'Free-time nudges',
                  subtitle: _calendarLinked
                      ? 'Reminds you to read during open calendar gaps'
                      : 'Link Google Calendar first',
                  trailing: Switch.adaptive(
                    value: _remindersEnabled && _calendarLinked,
                    onChanged:
                        _linking ? null : (v) => _toggleReminders(v),
                    activeThumbColor: c.brand,
                    activeTrackColor: c.brandMid,
                  ),
                  palette: c,
                  onTap: _linking || _calendarLinked ? null : _linkCalendar,
                ),
                const SizedBox(height: 28),

                // ── Account ──────────────────────────────────────────────
                _sectionLabel('Account', c),
                const SizedBox(height: 10),
                _SettingsTileC(
                  icon: Icons.switch_account_outlined,
                  title: 'Switch account',
                  subtitle: 'Sign in with a different Booqly account',
                  palette: c,
                  trailing: _switchingAccount
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: c.brand))
                      : Icon(Icons.chevron_right_rounded,
                          color: c.brand.withValues(alpha: 0.9)),
                  onTap: _switchingAccount ? null : _switchAccount,
                ),
                const SizedBox(height: 10),
                _SettingsTileC(
                  icon: Icons.logout_rounded,
                  title: 'Log out',
                  subtitle: 'Sign out of your Booqly account',
                  palette: c,
                  trailing: _loggingOut
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.redAccent))
                      : Icon(Icons.chevron_right_rounded,
                          color: Colors.redAccent.withValues(alpha: 0.9)),
                  onTap: _loggingOut ? null : _logout,
                ),
              ],
            ),
    );
  }

  Widget _sectionLabel(String text, AppPalette c) => Text(
        text.toUpperCase(),
        style: GoogleFonts.outfit(
          fontSize: 11,
          letterSpacing: 0.14,
          color: c.brand,
          fontWeight: FontWeight.w600,
        ),
      );
}

enum _SwitchAccountChoice { email, google }

// ── Calendar tile ────────────────────────────────────────────────────────────

class _CalendarTile extends StatelessWidget {
  const _CalendarTile({
    required this.linked,
    required this.email,
    required this.linking,
    required this.onLink,
    required this.onUnlink,
    required this.palette,
  });

  final bool linked;
  final String? email;
  final bool linking;
  final VoidCallback? onLink;
  final VoidCallback? onUnlink;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final c = palette;
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: linked ? onUnlink : onLink,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: linked ? c.greenSoft : c.brandSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.calendar_month_rounded,
                    color: linked ? c.green : c.brand, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Google Calendar',
                        style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: c.text)),
                    const SizedBox(height: 3),
                    Text(
                      linked
                          ? (email ?? 'Connected')
                          : 'Link to find free time between events',
                      style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: linked ? c.green : c.textMuted,
                          height: 1.35),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              linking
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: c.brand))
                  : Text(
                      linked ? 'Unlink' : 'Link',
                      style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: linked ? c.textSub : c.brand),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Calendar setup guide card ────────────────────────────────────────────────

class _CalendarSetupCard extends StatelessWidget {
  const _CalendarSetupCard(
      {this.origin, this.errorMessage, required this.palette});
  final String? origin;
  final String? errorMessage;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final c = palette;
    final steps = [
      'Go to console.cloud.google.com → APIs & Services → Credentials',
      'Open your OAuth 2.0 Web client (project 87414724762-…)',
      'Under "Authorized JavaScript origins" add your app origin:',
      'Save and wait ~1 minute for changes to propagate, then try again.',
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.amberSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.amber.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, color: c.amber, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  errorMessage ?? 'Google Calendar setup required',
                  style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: c.amber),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...steps.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      margin: const EdgeInsets.only(top: 1, right: 8),
                      decoration: BoxDecoration(
                        color: c.amber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Center(
                        child: Text(
                          '${e.key + 1}',
                          style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: c.amber),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        e.value,
                        style: GoogleFonts.outfit(
                            fontSize: 12,
                            height: 1.45,
                            color: c.amber.withValues(alpha: 0.8)),
                      ),
                    ),
                  ],
                ),
              )),
          if (origin != null) ...[
            const SizedBox(height: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: c.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      origin!,
                      style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: c.text),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.copy_rounded, size: 18, color: c.brand),
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: origin!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Origin copied to clipboard.')),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Generic settings tile (palette-aware) ────────────────────────────────────

class _SettingsTileC extends StatelessWidget {
  const _SettingsTileC({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.palette,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final AppPalette palette;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = palette;
    return Material(
      color: c.surface,
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
                  color: c.brandSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: c.brand, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: c.text)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: c.textMuted,
                            height: 1.35)),
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
