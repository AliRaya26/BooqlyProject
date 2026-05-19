import 'dart:typed_data';

enum ChatRole { user, assistant }

enum ChatMessageKind { text, image, voice }

class ChatMessage {
  final ChatRole role;
  final String text;
  final bool isError;
  final ChatMessageKind kind;
  final Uint8List? imageBytes;

  const ChatMessage({
    required this.role,
    required this.text,
    this.isError = false,
    this.kind = ChatMessageKind.text,
    this.imageBytes,
  });
}
