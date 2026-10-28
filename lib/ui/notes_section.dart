import 'package:flutter/material.dart';

import '../domain/notes.dart';
import '../l10n/app_localizations.dart';
import '../state/app_controller.dart';
import 'reminders_screen.dart' show formatReminderTime;

/// Text editor dialog; returns the trimmed text or null when cancelled.
Future<String?> showNoteEditor(BuildContext context, {String initial = ''}) {
  final l = AppLocalizations.of(context);
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(initial.isEmpty ? l.addNote : l.editNote),
      content: TextField(
        key: const ValueKey('note-field'),
        controller: controller,
        autofocus: true,
        maxLines: 5,
        minLines: 2,
        maxLength: CallNote.maxLength,
        decoration: InputDecoration(
          hintText: l.noteHint,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
        FilledButton(
          key: const ValueKey('note-save'),
          onPressed: () => Navigator.pop(ctx, controller.text.trim()),
          child: Text(l.save),
        ),
      ],
    ),
  );
}

/// Notes for a contact / number, with add, edit and delete. Rebuilds from the controller.
class NotesSection extends StatelessWidget {
  const NotesSection({super.key, required this.numbers});

  /// All numbers of the contact; new notes attach to the first one.
  final List<String> numbers;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = AppScope.of(context);
    final notes = c.notes.forNumbers(numbers);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(l.notes, style: theme.textTheme.titleSmall),
                ),
              ),
              TextButton.icon(
                key: const ValueKey('add-note'),
                icon: const Icon(Icons.note_add_outlined),
                label: Text(l.addNote),
                onPressed: numbers.isEmpty
                    ? null
                    : () async {
                        final text = await showNoteEditor(context);
                        if (text != null && text.isNotEmpty) {
                          await c.addNote(numbers.first, text);
                        }
                      },
              ),
            ],
          ),
        ),
        for (final n in notes)
          ListTile(
            key: ValueKey('note-${n.id}'),
            dense: true,
            leading: const Icon(Icons.sticky_note_2_outlined),
            title: Text(n.text, maxLines: 4, overflow: TextOverflow.ellipsis),
            subtitle: Text(formatReminderTime(context, n.updatedAt)),
            onTap: () async {
              final text = await showNoteEditor(context, initial: n.text);
              if (text == null) return;
              if (text.isEmpty) {
                await c.deleteNote(n);
              } else {
                await c.editNote(n, text);
              }
            },
            trailing: IconButton(
              key: ValueKey('note-delete-${n.id}'),
              tooltip: l.delete,
              icon: const Icon(Icons.delete_outline),
              onPressed: () => c.deleteNote(n),
            ),
          ),
        if (notes.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(l.noNotes, style: theme.textTheme.bodySmall),
          ),
      ],
    );
  }
}
