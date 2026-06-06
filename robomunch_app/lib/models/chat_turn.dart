enum ChatRole { user, assistant }

class ChatTurn {
  ChatTurn({required this.role, required this.content});

  final ChatRole role;
  final String content;

  Map<String, dynamic> toJson() => {
        "role": role == ChatRole.user ? "user" : "assistant",
        "content": content,
      };
}
