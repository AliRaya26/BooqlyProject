import 'dart:typed_data';

import 'package:booqly/Pages/HomePage.dart';
import 'package:booqly/models/chat_message.dart';
import 'package:booqly/services/gemini_chat_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

/// Bottom nav height in [HomePage] — keeps input bar visible above it.
const double _kBottomNavClearance = 88;

class BookChatPage extends StatefulWidget {
  const BookChatPage({super.key});

  @override
  State<BookChatPage> createState() => _BookChatPageState();
}

class _BookChatPageState extends State<BookChatPage> {
  final GeminiChatService _chatService = GeminiChatService();
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<ChatMessage> _messages = [];
  final List<String> _suggestions = const [
    'What should I read next?',
    'Tell me about Atomic Habits',
    'I want something motivating and short',
  ];

  Uint8List? _pendingImageBytes;
  String? _pendingImageMime;
  bool _loadingContext = true;
  bool _sending = false;
  String? _initError;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeChat() async {
    if (!_chatService.isConfigured) {
      setState(() {
        _loadingContext = false;
        _initError = 'missing_api_key';
      });
      return;
    }

    try {
      final context = await _chatService.loadContext();
      await _chatService.startSession(context);

      if (!mounted) return;
      setState(() {
        _loadingContext = false;
        _messages.add(
          ChatMessage(
            role: ChatRole.assistant,
            text: _welcomeMessage(context),
          ),
        );
      });
    } on GeminiApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingContext = false;
        _initError = e.isInvalidKey ? 'invalid_api_key' : e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingContext = false;
        _initError = e.toString();
      });
    }
  }

  String _welcomeMessage(BookChatContext context) {
    final catalogCount = context.catalogBooks.length;

    return 'Hi! I\'m here to help you choose what to read and share feedback on books.\n\n'
        '• Ask what to read next\n'
        '• Ask for thoughts on any book by name\n'
        '• Tap the photo icon to send a picture of a physical book\n\n'
        '${catalogCount > 0 ? "I can suggest from $catalogCount books in Booqly." : "Add books to Booqly to get tailored picks."}';
  }

  Future<void> _pickImage() async {
    try {
      final file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        imageQuality: 85,
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();
      final mime = _mimeFromPath(file.mimeType, file.name);

      setState(() {
        _pendingImageBytes = bytes;
        _pendingImageMime = mime;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load image: $e')),
      );
    }
  }

  String _mimeFromPath(String? mime, String name) {
    if (mime != null && mime.isNotEmpty) return mime;
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<void> _sendMessage([String? preset]) async {
    final text = (preset ?? _inputController.text).trim();
    final hasImage = _pendingImageBytes != null;
    if ((text.isEmpty && !hasImage) ||
        _sending ||
        _loadingContext ||
        _initError != null) {
      return;
    }

    final imageBytes = _pendingImageBytes;
    final imageMime = _pendingImageMime ?? 'image/jpeg';
    final displayText = hasImage
        ? (text.isEmpty ? '📷 Photo of a book' : '📷 $text')
        : text;

    _inputController.clear();
    setState(() {
      _messages.add(
        ChatMessage(
          role: ChatRole.user,
          text: displayText,
          kind: hasImage ? ChatMessageKind.image : ChatMessageKind.text,
          imageBytes: imageBytes,
        ),
      );
      _pendingImageBytes = null;
      _pendingImageMime = null;
      _sending = true;
    });
    _scrollToBottom();

    try {
      final String reply;
      if (hasImage && imageBytes != null) {
        reply = await _chatService.sendMessageWithImage(
          imageBytes: imageBytes,
          mimeType: imageMime,
          userText: text.isEmpty ? null : text,
        );
      } else {
        reply = await _chatService.sendMessage(text);
      }

      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(role: ChatRole.assistant, text: reply));
        _sending = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          ChatMessage(
            role: ChatRole.assistant,
            text: _friendlyError(e),
            isError: true,
          ),
        );
        _sending = false;
      });
    }
    _scrollToBottom();
  }

  String _friendlyError(Object e) {
    if (e is GeminiApiException) return e.message;
    return 'Sorry, I couldn\'t reply. Please try again.\n\n$e';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  double get _bottomInset =>
      _kBottomNavClearance + MediaQuery.of(context).padding.bottom;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: _bottomInset),
      child: Column(
        children: [
          _ChatHeader(
            topPadding: MediaQuery.of(context).padding.top,
            onRefresh: _loadingContext || _sending ? null : _refreshContext,
          ),
          Expanded(child: _buildBody()),
          if (_initError == null && !_loadingContext) _buildInputBar(),
        ],
      ),
    );
  }

  Future<void> _refreshContext() async {
    setState(() {
      _loadingContext = true;
      _messages.clear();
      _initError = null;
      _pendingImageBytes = null;
    });
    _chatService.resetSession();
    await _initializeChat();
  }

  Widget _buildBody() {
    if (_loadingContext) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.gold),
      );
    }

    if (_initError == 'missing_api_key') {
      return const _MissingApiKeyState();
    }

    if (_initError == 'invalid_api_key') {
      return const _InvalidApiKeyState();
    }

    if (_initError != null) {
      return _ErrorState(message: _initError!, onRetry: _refreshContext);
    }

    return Column(
      children: [
        if (_messages.length <= 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _suggestions.map((s) {
                return ActionChip(
                  label: Text(
                    s,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  backgroundColor: AppColors.surface,
                  side: const BorderSide(color: AppColors.border),
                  onPressed: _sending ? null : () => _sendMessage(s),
                );
              }).toList(),
            ),
          ),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            itemCount: _messages.length + (_sending ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _messages.length) {
                return const _TypingIndicator();
              }
              return _MessageBubble(message: _messages[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: const BoxDecoration(
        color: AppColors.navBar,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_pendingImageBytes != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(
                      _pendingImageBytes!,
                      width: 56,
                      height: 72,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Book photo — add a question or tap send',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() {
                      _pendingImageBytes = null;
                      _pendingImageMime = null;
                    }),
                    icon: const Icon(Icons.close, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                onPressed: _sending ? null : _pickImage,
                icon: const Icon(Icons.photo_camera_outlined, color: AppColors.gold),
                tooltip: 'Photo of a book',
              ),
              Expanded(
                child: TextField(
                  controller: _inputController,
                  enabled: !_sending,
                  maxLines: 4,
                  minLines: 1,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Ask what to read or about a book…',
                    hintStyle: GoogleFonts.outfit(
                      fontSize: 14,
                      color: AppColors.textMuted,
                    ),
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.goldDim),
                    ),
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 6),
              Material(
                color: AppColors.gold,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: _sending ? null : () => _sendMessage(),
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: _sending
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.bg,
                            ),
                          )
                        : const Icon(Icons.send_rounded, color: AppColors.bg),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({required this.topPadding, this.onRefresh});

  final double topPadding;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(22, topPadding + 12, 22, 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.goldMuted,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.auto_stories_rounded,
              color: AppColors.gold,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reading assistant',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'What to read · book feedback · photo',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (onRefresh != null)
            IconButton(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded, color: AppColors.gold),
              tooltip: 'Refresh',
            ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? AppColors.gold
              : message.isError
                  ? const Color(0xFF2A1515)
                  : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: isUser
              ? null
              : Border.all(
                  color: message.isError
                      ? Colors.red.withValues(alpha: 0.3)
                      : AppColors.border,
                ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.imageBytes != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.memory(
                    message.imageBytes!,
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            Text(
              message.text,
              style: GoogleFonts.outfit(
                fontSize: 14,
                height: 1.45,
                color: isUser ? AppColors.bg : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.gold.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Thinking…',
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MissingApiKeyState extends StatelessWidget {
  const _MissingApiKeyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.key_rounded, size: 48, color: AppColors.gold.withValues(alpha: 0.8)),
          const SizedBox(height: 16),
          Text(
            'Gemini API key required',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Add GEMINI_API_KEY in assets/config.env, then restart the app.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 13,
              height: 1.5,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _InvalidApiKeyState extends StatelessWidget {
  const _InvalidApiKeyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.key_off_rounded, size: 48, color: Colors.redAccent),
          const SizedBox(height: 16),
          Text(
            'API key not valid',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Create a new key at aistudio.google.com/apikey, '
            'update assets/config.env, and restart the app.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 13,
              height: 1.5,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 40),
          const SizedBox(height: 12),
          Text(
            'Could not start the assistant',
            style: GoogleFonts.outfit(
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: onRetry,
            child: Text(
              'Try again',
              style: GoogleFonts.outfit(color: AppColors.gold),
            ),
          ),
        ],
      ),
    );
  }
}
