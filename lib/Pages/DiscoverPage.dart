import 'dart:io';

import 'package:booqly/Pages/BookDetailPage.dart';
import 'package:flutter/foundation.dart';
import 'package:booqly/models/book_model.dart';
import 'package:booqly/services/book_service.dart';
import 'package:booqly/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  final BookService _bookService = BookService();
  final TextEditingController _searchController = TextEditingController();

  String _query = '';
  String _selectedCategory = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<BookModel> _filtered(List<BookModel> all) {
    var list = all;

    if (_selectedCategory != 'All') {
      list = list
          .where((b) =>
              b.category.toLowerCase() == _selectedCategory.toLowerCase())
          .toList();
    }

    if (_query.isNotEmpty) {
      list = list
          .where((b) =>
              b.title.toLowerCase().contains(_query) ||
              b.author.toLowerCase().contains(_query))
          .toList();
    }

    return list;
  }

  List<String> _categories(List<BookModel> all) {
    final cats = all.map((b) => b.category).toSet().toList()..sort();
    return ['All', ...cats];
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final top = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: c.bg,
      body: StreamBuilder<List<BookModel>>(
        stream: _bookService.booksStream(),
        builder: (context, snapshot) {
          final allBooks = snapshot.data ?? [];
          final categories = _categories(allBooks);
          final filtered = _filtered(allBooks);
          final loading =
              snapshot.connectionState == ConnectionState.waiting &&
                  allBooks.isEmpty;

          return CustomScrollView(
            slivers: [
              // ── Header ─────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Container(
                  color: c.surface,
                  padding: EdgeInsets.fromLTRB(20, top + 16, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Discover',
                        style: GoogleFonts.figtree(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: c.text,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        loading
                            ? 'Loading books…'
                            : '${allBooks.length} books in the catalog',
                        style: GoogleFonts.outfit(
                            fontSize: 13, color: c.textMuted),
                      ),
                      const SizedBox(height: 16),

                      // ── Search bar ─────────────────────────────────────
                      TextField(
                        controller: _searchController,
                        onChanged: (v) =>
                            setState(() => _query = v.trim().toLowerCase()),
                        style: GoogleFonts.outfit(
                            fontSize: 14, color: c.text),
                        decoration: InputDecoration(
                          hintText: 'Search by title or author…',
                          hintStyle: GoogleFonts.outfit(
                              fontSize: 14, color: c.textMuted),
                          prefixIcon: Icon(Icons.search_rounded,
                              color: c.textMuted, size: 20),
                          suffixIcon: _query.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear_rounded,
                                      size: 18, color: c.textMuted),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _query = '');
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: c.surfaceAlt,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: c.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: c.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                BorderSide(color: c.brand, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                  ),
                ),
              ),

              // ── Category chips ─────────────────────────────────────────
              SliverToBoxAdapter(
                child: Container(
                  color: c.surface,
                  child: Column(
                    children: [
                      SizedBox(
                        height: 44,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: categories.length,
                          separatorBuilder: (ctx, i) =>
                              const SizedBox(width: 8),
                          itemBuilder: (_, i) {
                            final cat = categories[i];
                            final active = cat == _selectedCategory;
                            return GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedCategory = cat),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: active ? c.brand : c.surfaceAlt,
                                  borderRadius: BorderRadius.circular(100),
                                  border: Border.all(
                                    color:
                                        active ? c.brand : c.border,
                                  ),
                                ),
                                child: Text(
                                  cat,
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: active
                                        ? c.onPrimary
                                        : c.textSub,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 14),
                      Divider(
                          height: 1,
                          color: c.border.withValues(alpha: 0.6)),
                    ],
                  ),
                ),
              ),

              // ── Loading ────────────────────────────────────────────────
              if (loading)
                SliverFillRemaining(
                  child: Center(
                    child:
                        CircularProgressIndicator(color: c.brand),
                  ),
                )

              // ── Empty state ────────────────────────────────────────────
              else if (filtered.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off_rounded,
                            size: 48, color: c.textMuted),
                        const SizedBox(height: 12),
                        Text(
                          _query.isNotEmpty
                              ? 'No books match "$_query"'
                              : 'No books in this category',
                          style: GoogleFonts.outfit(
                              fontSize: 15, color: c.textSub),
                        ),
                        if (_query.isNotEmpty ||
                            _selectedCategory != 'All') ...[
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _query = '';
                                _selectedCategory = 'All';
                              });
                            },
                            child: Text('Clear filters',
                                style: GoogleFonts.outfit(
                                    color: c.brand)),
                          ),
                        ],
                      ],
                    ),
                  ),
                )

              // ── Book grid ──────────────────────────────────────────────
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _BookCard(book: filtered[i]),
                      childCount: filtered.length,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 200,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.52,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ── Book card ─────────────────────────────────────────────────────────────────

class _BookCard extends StatelessWidget {
  const _BookCard({required this.book});
  final BookModel book;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => BookDetailPage(book: book)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: cardShadow(context),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: _cover(c),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Category chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: c.brandSoft,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              book.category,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: c.brand,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const SizedBox(height: 5),

          Text(
            book.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: c.text,
                height: 1.3),
          ),
          const SizedBox(height: 2),

          Text(
            book.author,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                GoogleFonts.outfit(fontSize: 11, color: c.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _cover(AppPalette c) {
    if (book.coverUrl.trim().isEmpty) return _placeholder(c);
    if (book.coverUrl.startsWith('http')) {
      return Image.network(
        book.coverUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (ctx, err, stack) => _placeholder(c),
      );
    }
    if (kIsWeb) return _placeholder(c);
    return Image.file(
      File(book.coverUrl),
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (ctx, err, stack) => _placeholder(c),
    );
  }

  Widget _placeholder(AppPalette c) {
    return Container(
      color: c.surfaceAlt,
      child: Center(
        child: Icon(Icons.menu_book_rounded, size: 32, color: c.textMuted),
      ),
    );
  }
}
