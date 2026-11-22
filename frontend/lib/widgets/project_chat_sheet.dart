import 'dart:convert';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:web/web.dart' as web;

import '../main.dart';
import '../services/auth_service.dart';

class ChatSheet extends StatefulWidget {
  final int targetId;
  final String targetType; // 'Project' oder 'Task'
  final String targetName;
  final bool isEmbedded;

  const ChatSheet({
    super.key,
    required this.targetId,
    required this.targetType,
    required this.targetName,
    this.isEmbedded = false,
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

  PlatformFile? _selectedFile;
  Uint8List? _selectedFileBytes;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _fetchComments(showLoader: true);
  }

  Future<void> _loadCurrentUser() async {
    final id = await AuthService.getCurrentUserId();
    if (!mounted) return;
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
    if (showLoader && mounted) setState(() => _isLoading = true);

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
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Fehler beim Laden der Kommentare: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickChatFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      withData: true,
    );
    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _selectedFile = result.files.single;
        _selectedFileBytes = result.files.single.bytes;
      });
    }
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty && _selectedFileBytes == null) return;

    try {
      final headers = await AuthService.getHeaders();
      headers.remove('Content-Type'); // Wichtig für Multipart!

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$apiBaseUrl/comments'),
      );
      request.headers.addAll(headers);

      request.fields['commentable_type'] = widget.targetType;
      request.fields['commentable_id'] = widget.targetId.toString();

      if (text.isNotEmpty) {
        request.fields['content'] = text;
      }

      if (_selectedFileBytes != null && _selectedFile != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            _selectedFileBytes!,
            filename: _selectedFile!.name,
          ),
        );
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        _commentController.clear();
        setState(() {
          _selectedFile = null;
          _selectedFileBytes = null;
        });
        await _fetchComments();
      }
    } catch (e) {
      debugPrint('Fehler beim Senden: $e');
    }
  }

  Future<void> _editComment(Map<String, dynamic> comment) async {
    final TextEditingController editController = TextEditingController(
      text: comment['content'],
    );

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kommentar bearbeiten'),
        content: TextField(
          controller: editController,
          maxLines: 3,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Speichern'),
          ),
        ],
      ),
    );

    if (confirm == true && comment['id'] != null) {
      final url = Uri.parse('$apiBaseUrl/comments/${comment['id']}');
      try {
        final headers = await AuthService.getHeaders();
        final response = await http.put(
          url,
          headers: headers,
          body: jsonEncode({'content': editController.text.trim()}),
        );
        if (!mounted) return;
        if (response.statusCode == 200) {
          await _fetchComments();
        }
      } catch (e) {
        debugPrint('Fehler beim Bearbeiten: $e');
      }
    }
  }

  Future<void> _deleteComment(int commentId) async {
    final url = Uri.parse('$apiBaseUrl/comments/$commentId');
    try {
      final headers = await AuthService.getHeaders();
      if (!mounted) return;

      final response = await http.delete(url, headers: headers);
      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 204) {
        await _fetchComments();
      }
    } catch (e) {
      debugPrint('Fehler beim Löschen: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
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
    return Container(
      height: widget.isEmbedded
          ? null
          : MediaQuery.of(context).size.height * 0.7,
      padding: widget.isEmbedded ? EdgeInsets.zero : const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: widget.isEmbedded ? MainAxisSize.min : MainAxisSize.max,
        children: [
          if (!widget.isEmbedded) ...[
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
          widget.isEmbedded
              ? SizedBox(height: 250, child: _buildMessagesList())
              : Expanded(child: _buildMessagesList()),
          const SizedBox(height: 8),

          if (_selectedFile != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.attach_file, size: 16, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selectedFile!.name,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16, color: Colors.red),
                    onPressed: () => setState(() {
                      _selectedFile = null;
                      _selectedFileBytes = null;
                    }),
                  ),
                ],
              ),
            ),

          _buildInputRow(),
        ],
      ),
    );
  }

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

        final isMyComment = comment['user_id'] == _currentUserId;

        List attachmentsList = [];
        if (comment['attachments'] is List) {
          attachmentsList = comment['attachments'];
        } else if (comment['attachment'] != null) {
          attachmentsList = [comment['attachment']];
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.blueGrey.shade200,
                    child: const Icon(
                      Icons.person,
                      size: 16,
                      color: Colors.white,
                    ),
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
                  if (isMyComment) ...[
                    InkWell(
                      onTap: () => _editComment(comment),
                      child: const Icon(
                        Icons.edit_outlined,
                        size: 16,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 12),
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
                ],
              ),
              const SizedBox(height: 4),
              Container(
                margin: const EdgeInsets.only(left: 32),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (comment['content'] != null &&
                        comment['content'].toString().trim().isNotEmpty)
                      Text(
                        comment['content'].toString(),
                        style: const TextStyle(fontSize: 14),
                      ),

                    if (attachmentsList.isNotEmpty) ...[
                      if (comment['content'] != null &&
                          comment['content'].toString().trim().isNotEmpty)
                        const SizedBox(height: 6),

                      ...attachmentsList.map((att) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 2.0),
                          child: InkWell(
                            onTap: () {
                              final fileUrl =
                                  'http://127.0.0.1:8000/storage/${att['file_path']}';
                              web.window.open(fileUrl, '_blank');
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.insert_drive_file,
                                    size: 16,
                                    color: Colors.blue,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      att['file_name'] ?? 'Datei',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.blue,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInputRow() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.attach_file, color: Colors.grey),
          tooltip: 'Datei anfügen',
          onPressed: _pickChatFile,
        ),
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
                vertical: 10,
              ),
              isDense: true,
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
          elevation: 0,
          onPressed: () async {
            await _sendComment();
            _focusNode.requestFocus();
          },
          child: const Icon(Icons.send, size: 18),
        ),
      ],
    );
  }
}
