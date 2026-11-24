import 'package:material_ui/material_ui.dart';

class InlineEditableText extends StatefulWidget {
  final String initialText;
  final TextStyle? textStyle;
  final Function(String) onSave;
  final int maxLines;

  const InlineEditableText({
    super.key,
    required this.initialText,
    this.textStyle,
    required this.onSave,
    this.maxLines = 1,
  });

  @override
  State<InlineEditableText> createState() => _InlineEditableTextState();
}

class _InlineEditableTextState extends State<InlineEditableText> {
  late TextEditingController _controller;
  bool _isEditing = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);

    // Wenn das Feld den Fokus verliert (z.B. Klick daneben), speichern wir
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _isEditing) {
        _save();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _save() {
    if (!_isEditing) return;

    final newText = _controller.text.trim();
    setState(() => _isEditing = false);

    // Nur speichern, wenn sich wirklich etwas geändert hat
    if (newText != widget.initialText && newText.isNotEmpty) {
      widget.onSave(newText);
    } else {
      // Bei Abbruch oder leerem Text den alten Wert wiederherstellen
      _controller.text = widget.initialText;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing) {
      return TextField(
        controller: _controller,
        focusNode: _focusNode,
        style: widget.textStyle,
        maxLines: widget.maxLines,
        autofocus: true,
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 8),
          border: OutlineInputBorder(),
        ),
        onSubmitted: (_) => _save(),
      );
    }

    return GestureDetector(
      onDoubleTap: () {
        setState(() => _isEditing = true);
      },
      child: Tooltip(
        message: 'Doppelklicken zum Bearbeiten',
        child: Text(
          widget.initialText,
          style: widget.textStyle,
          maxLines: widget.maxLines,
          overflow: TextOverflow
              .ellipsis, // Verhindert Layout-Fehler bei langen Texten
        ),
      ),
    );
  }
}
