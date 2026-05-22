import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Shared auth screen shell: tablet-friendly width, keyboard insets, tap-to-dismiss.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.child,
    this.showBackButton = false,
  });

  final Widget child;
  final bool showBackButton;

  static const bg = Color(0xFF0E0C0A);

  // Reserve enough vertical space for the inner header padding (24 top + 24
  // bottom). Any value above 0 is fine; this just lets the scroll view fill
  // the viewport when content is short.
  static const _verticalChrome = 48.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          behavior: HitTestBehavior.opaque,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Scaffold(resizeToAvoidBottomInset: true) already removes the
              // keyboard height from constraints.maxHeight. Earlier versions
              // subtracted viewInsets.bottom again, which produced a negative
              // minHeight (-2.0) when the IME opened in landscape and crashed
              // every frame with "BoxConstraints has a negative minimum
              // height". Use math.max + isFinite to guarantee a valid value
              // regardless of the parent's constraints.
              final maxH = constraints.maxHeight;
              final double minHeight = (maxH.isFinite)
                  ? math.max(0.0, maxH - _verticalChrome)
                  : 0.0;
              final maxWidth = constraints.maxWidth > 600 ? 440.0 : 520.0;
              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  24,
                  showBackButton ? 8 : 16,
                  24,
                  24,
                ),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: maxWidth,
                      minHeight: minHeight,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (showBackButton)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: IconButton(
                              icon: const Icon(Icons.arrow_back_rounded),
                              color: const Color(0xFFD4A96A),
                              onPressed: () => Navigator.maybePop(context),
                            ),
                          ),
                        child,
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Primary auth action button with loading state and minimum touch target.
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  static const _gold = Color(0xFFD4A96A);
  static const _bg = Color(0xFF0E0C0A);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _gold,
          disabledBackgroundColor: _gold.withValues(alpha: 0.45),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: isLoading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: _bg),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _bg,
                ),
              ),
      ),
    );
  }
}
