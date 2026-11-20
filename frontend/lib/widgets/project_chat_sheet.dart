import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:http/http.dart' as http;

import '../main.dart';
import '../services/auth_service.dart';

class ChatSheet extends StatefulWidget {
  final int targetId;
  final String targetType; // 'Project' oder 'Task'
  final String targetName;
  final bool isEmbedded; // NEU: Steuert, ob es eingebettet ist

  const ChatSheet({
    super.key,
    required this.targetId,
    required this.targetType,
    required this.targetName,
    this.isEmbedded = false, // Standardmäßig false (als BottomSheet)
  });

  @override
  State<ChatSheet> createState() => _ChatSheetState();
}

class _ChatSheetState extends State<ChatSheet> {
  List<dynamic> _comments = [];
  bool _isLoading = true;
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _fetchComments(showLoader: true);
  }

  Future<void> _loadCurrentUser() async {
    final id = await AuthService.getCurrentUserId();
    setState(() => _currentUserId = id);
  }

  @override
  void dispose() {
    _commentController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchComments({bool showLoader = false}) async {
    if (showLoader) setState(() => _isLoading = true);

    final url = Uri.parse(
      '$apiBaseUrl/comments?commentable_type=${widget.targetType}&commentable_id=${widget.targetId}',
    );

    try {
      final headers = await AuthService.getHeaders();
      if (!mounted) return;
      final response = await http.get(url, headers: headers);
      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() {
          _comments = jsonDecode(response.body);
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Fehler beim Laden der Kommentare: $e');
      if (showLoader) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    _commentController.clear();
    final url = Uri.parse('$apiBaseUrl/comments');
    final headers = await AuthService.getHeaders(); // <-- NEU: Token holen

    try {
      final response = await http.post(
        url,
        headers: headers, // <-- Geändert: headers statt dem alten {'Content-Type': ...}
        body: jsonEncode({
          'commentable_type': widget.targetType,
          'commentable_id': widget.targetId,
          'content': text,
        }),
      );

      if (response.statusCode == 201) {
        await _fetchComments();
      }
    } catch (e) {
      debugPrint('Fehler beim Senden: $e');
    }
  }

  Future<void> _deleteComment(int commentId) async {
    final url = Uri.parse('$apiBaseUrl/comments/$commentId');
    try {
      final headers = await AuthService.getHeaders();
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        await _fetchComments();
      }
    } catch (e) {
      debugPrint('Fehler beim Löschen: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Wenn es eingebettet ist, nehmen wir kein Padding für die Tastatur und keine feste Höhe
    return Container(
      height: widget.isEmbedded
          ? null
          : MediaQuery.of(context).size.height * 0.7,
      padding: widget.isEmbedded ? EdgeInsets.zero : const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: widget.isEmbedded ? MainAxisSize.min : MainAxisSize.max,
        children: [
          if (!widget.isEmbedded) ...[
            // Der Griff und der Titel (nur im BottomSheet-Modus)
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Chat: ${widget.targetName}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
          ],

          // Die Nachrichtenliste
          widget.isEmbedded
              ? SizedBox(
                  height: 300, // Feste Höhe für die Liste in der Detailansicht
                  child: _buildMessagesList(),
                )
              : Expanded(child: _buildMessagesList()),

          // Das Eingabefeld
          const SizedBox(height: 16),
          _buildInputRow(),
        ],
      ),
    );
  }

  // Hilfsmethode für die Nachrichtenliste
  Widget _buildMessagesList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_comments.isEmpty) {
      return const Center(
        child: Text(
          'Noch keine Nachrichten. Schreib die erste!',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: _comments.length,
      itemBuilder: (context, index) {
        final comment = _comments[index];
        final userName = comment['user'] != null
            ? comment['user']['name']
            : 'Gast';
        final date = DateTime.tryParse(comment['created_at'] ?? '');
        final timeString = date != null
            ? "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} Uhr"
            : '';

        // NEU: Prüfen, ob der Kommentar vom aktuell eingeloggten User stammt
        final isMyComment = comment['user_id'] == _currentUserId;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    radius: 12,
                    backgroundColor: Colors.blueGrey,
                    child: Icon(Icons.person, size: 16, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    userName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    timeString,
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                  const Spacer(),

                  // NEU: Den Mülleimer nur anzeigen, wenn es mein Kommentar ist
                  if (isMyComment)
                    InkWell(
                      onTap: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Kommentar löschen?'),
                            content: const Text(
                              'Möchtest du diesen Kommentar wirklich löschen?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Abbrechen'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text(
                                  'Löschen',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true && comment['id'] != null) {
                          await _deleteComment(comment['id']);
                        }
                      },
                      child: const Icon(
                        Icons.delete_outline,
                        size: 16,
                        color: Colors.red,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Container(
                margin: const EdgeInsets.only(left: 32),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  comment['content'] ?? '',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Hilfsmethode für das Eingabefeld
  Widget _buildInputRow() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _commentController,
            focusNode: _focusNode,
            decoration: InputDecoration(
              hintText: 'Nachricht schreiben...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            textInputAction: TextInputAction.send,
            onSubmitted: (_) async {
              await _sendComment();
              _focusNode.requestFocus();
            },
          ),
        ),
        const SizedBox(width: 8),
        FloatingActionButton(
          mini: true,
          onPressed: () async {
            await _sendComment();
            _focusNode.requestFocus();
          },
          child: const Icon(Icons.send, size: 20),
        ),
      ],
    );
  }
}
