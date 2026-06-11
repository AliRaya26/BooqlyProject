import 'dart:io' show File;

import 'package:booqly/theme/app_colors.dart';
import 'package:booqly/utils/book_cover_url.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart' show WebHtmlElementStrategy;

/// Displays a book cover from a network URL, local file path, or placeholder.
class BookCoverImage extends StatelessWidget {
  const BookCoverImage({
    super.key,
    required this.url,
    this.title,
    this.isbn,
    this.width,
    this.height,
    this.borderRadius = 12,
    this.iconSize = 28,
    this.fillParent = false,
  });

  final String url;
  final String? title;
  final String? isbn;
  final double? width;
  final double? height;
  final double borderRadius;
  final double iconSize;

  /// When true, expands to fill the parent (use inside [Expanded] / grid cells).
  final bool fillParent;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final resolved = effectiveCoverUrl(
      coverUrl: url,
      title: title ?? '',
      isbn: isbn,
    );

    final fallback = isbn != null && isbn!.trim().isNotEmpty
        ? openLibraryCoverForIsbn(isbn!)
        : openLibraryCoverForTitle(title ?? '');

    Widget child;
    if (resolved.isEmpty && fallback.isEmpty) {
      child = _placeholderBody(c, iconSize: iconSize);
    } else if (resolved.startsWith('http') ||
        (resolved.isEmpty && fallback.startsWith('http'))) {
      child = _NetworkCover(
        primaryUrl: resolved.isNotEmpty ? resolved : fallback,
        fallbackUrl: fallback != resolved ? fallback : null,
        placeholder: _placeholderBody(c, iconSize: iconSize, loading: true),
        errorWidget: _placeholderBody(c, iconSize: iconSize, broken: true),
      );
    } else if (kIsWeb) {
      child = _placeholderBody(c, iconSize: iconSize);
    } else {
      child = Image.file(
        File(resolved),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            _placeholderBody(c, iconSize: iconSize, broken: true),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: fillParent
          ? ColoredBox(
              color: c.surfaceAlt,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth <= 0 || constraints.maxHeight <= 0) {
                    return _placeholderBody(c, iconSize: iconSize);
                  }
                  return SizedBox(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    child: child,
                  );
                },
              ),
            )
          : SizedBox(
              width: width ?? 100,
              height: height ?? 150,
              child: ColoredBox(
                color: c.surfaceAlt,
                child: child,
              ),
            ),
    );
  }

  static Widget _placeholderBody(
    AppPalette c, {
    required double iconSize,
    bool loading = false,
    bool broken = false,
  }) {
    return Center(
      child: loading
          ? SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: c.brand.withValues(alpha: 0.7),
              ),
            )
          : Icon(
              broken ? Icons.broken_image_outlined : Icons.menu_book_rounded,
              color: c.textMuted,
              size: iconSize,
            ),
    );
  }
}

/// Network cover with optional fallback URL (e.g. Open Library).
class _NetworkCover extends StatefulWidget {
  const _NetworkCover({
    required this.primaryUrl,
    this.fallbackUrl,
    required this.placeholder,
    required this.errorWidget,
  });

  final String primaryUrl;
  final String? fallbackUrl;
  final Widget placeholder;
  final Widget errorWidget;

  @override
  State<_NetworkCover> createState() => _NetworkCoverState();
}

class _NetworkCoverState extends State<_NetworkCover> {
  late String _currentUrl;
  int _attempt = 0;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.primaryUrl;
  }

  void _tryFallback() {
    final next = widget.fallbackUrl;
    if (next == null || next.isEmpty || next == _currentUrl) return;
    setState(() {
      _attempt++;
      _currentUrl = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final hasSize = w.isFinite && h.isFinite && w > 0 && h > 0;

        if (!hasSize) {
          return widget.placeholder;
        }

        // On web, use HTML <img> fallback so Open Library covers load without CORS.
        final webStrategy =
            kIsWeb ? WebHtmlElementStrategy.fallback : WebHtmlElementStrategy.never;

        return Image.network(
          _currentUrl,
          width: w,
          height: h,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          webHtmlElementStrategy: webStrategy,
          loadingBuilder: (ctx, image, progress) {
            if (progress == null) return image;
            return widget.placeholder;
          },
          errorBuilder: (_, __, ___) {
            if (_attempt == 0 && widget.fallbackUrl != null) {
              _tryFallback();
              return widget.placeholder;
            }
            return widget.errorWidget;
          },
        );
      },
    );
  }
}
