import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:todo/services/notification_service.dart';
import 'package:todo/todo.dart';
import 'package:todo/widgets/responsive_frame.dart';

class TodoDetailScreen extends StatefulWidget {
  const TodoDetailScreen({
    super.key,
    required this.todoId,
  });

  final String todoId;

  @override
  State<TodoDetailScreen> createState() => _TodoDetailScreenState();
}

class _TodoDetailScreenState extends State<TodoDetailScreen> {
  final _controller = TextEditingController();
  late final DocumentReference<Todo> _todoRef;

  bool _hasLoadedText = false;
  bool _isDeleting = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _todoRef = FirebaseFirestore.instance
        .collection('todos')
        .doc(widget.todoId)
        .withConverter<Todo>(
          fromFirestore: (snapshot, _) => Todo.fromSnapshot(snapshot),
          toFirestore: (todo, _) => todo.toSnapshot(),
        );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveTodo() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSaving || _isDeleting) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _todoRef.update({'text': text});

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Todo saved.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save todo: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _pickDueAt(Todo todo) async {
    if (_isSaving || _isDeleting) {
      return;
    }

    final now = DateTime.now();
    final currentDueAt = todo.dueAt?.toLocal();
    final initialDateTime = currentDueAt != null && currentDueAt.isAfter(now)
        ? currentDueAt
        : now.add(const Duration(minutes: 5));

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateUtils.dateOnly(initialDateTime),
      firstDate: DateUtils.dateOnly(now),
      lastDate: DateTime(now.year + 10, now.month, now.day),
    );
    if (pickedDate == null || !mounted) {
      return;
    }

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDateTime),
    );
    if (pickedTime == null || !mounted) {
      return;
    }

    final dueAt = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    if (!dueAt.isAfter(DateTime.now())) {
      _showSnackBar('Choose a due date in the future.');
      return;
    }

    await _setDueAt(dueAt);
  }

  Future<void> _setDueAt(DateTime? dueAt) async {
    if (_isSaving || _isDeleting) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    var didUpdateDueAt = false;
    try {
      await _todoRef.update({
        'dueAt': dueAt == null ? null : Timestamp.fromDate(dueAt),
      });
      didUpdateDueAt = true;

      if (dueAt == null) {
        await NotificationService.instance.cancelTodoDueNotification(
          widget.todoId,
        );
        _showSnackBar('Due date removed.');
        return;
      }

      final scheduleResult = await NotificationService.instance
          .scheduleTodoDueNotification(
            todoId: widget.todoId,
            todoText: _controller.text.trim(),
            dueAt: dueAt,
          );
      _showSnackBar(_scheduleResultMessage(scheduleResult));
    } catch (error) {
      if (!mounted) {
        return;
      }

      final message = didUpdateDueAt
          ? 'Due date saved, but the notification could not be updated: $error'
          : 'Could not update due date: $error';
      _showSnackBar(message);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _deleteTodo() async {
    if (_isDeleting || _isSaving) {
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete todo?'),
          content: const Text('This will permanently remove this todo.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true || !mounted) {
      return;
    }

    setState(() {
      _isDeleting = true;
    });

    try {
      await NotificationService.instance.cancelTodoDueNotification(
        widget.todoId,
      );
      await _todoRef.delete();

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isDeleting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete todo: $error')),
      );
    }
  }

  Widget _buildDueAtControls(Todo todo) {
    final dueAt = todo.dueAt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Due date', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isSaving || _isDeleting
                    ? null
                    : () => _pickDueAt(todo),
                icon: const Icon(Icons.event),
                label: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    dueAt == null
                        ? 'Choose date and time'
                        : _formatDateTime(dueAt),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
            if (dueAt != null) ...[
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Remove due date',
                onPressed: _isSaving || _isDeleting
                    ? null
                    : () => _setDueAt(null),
                icon: const Icon(Icons.clear),
              ),
            ],
          ],
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final localDateTime = dateTime.toLocal();
    final localizations = MaterialLocalizations.of(context);
    final date = localizations.formatMediumDate(localDateTime);
    final time = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(localDateTime),
    );
    return '$date at $time';
  }

  String _scheduleResultMessage(TodoNotificationScheduleResult result) {
    return switch (result) {
      TodoNotificationScheduleResult.scheduled => 'Due date saved.',
      TodoNotificationScheduleResult.scheduledInexact =>
        'Due date saved. Reminder timing may be approximate.',
      TodoNotificationScheduleResult.permissionDenied =>
        'Due date saved, but notification permission was not granted.',
      TodoNotificationScheduleResult.unsupported =>
        'Due date saved, but notifications are not supported here.',
      TodoNotificationScheduleResult.pastDue =>
        'Due date saved, but no reminder was scheduled for a past time.',
    };
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _buildTimeline(Todo todo) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _buildTimestamp(
          icon: Icons.add_circle_outline,
          label: 'Created',
          value: _formatDateTime(todo.createdAt),
        ),
        if (todo.completedAt != null)
          _buildTimestamp(
            icon: Icons.check_circle_outline,
            label: 'Completed',
            value: _formatDateTime(todo.completedAt!),
          ),
      ],
    );
  }

  Widget _buildTimestamp({
    required IconData icon,
    required String label,
    required String value,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: colorScheme.secondary),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Text(value),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Todo details'),
        actions: [
          IconButton(
            tooltip: 'Delete todo',
            icon: _isDeleting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete),
            onPressed: _isDeleting || _isSaving ? null : _deleteTodo,
          ),
        ],
      ),
      body: SafeArea(
        child: ResponsiveFrame(
          maxWidth: 720,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: StreamBuilder<DocumentSnapshot<Todo>>(
            stream: _todoRef.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text('Could not load todo: ${snapshot.error}'),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final todo = snapshot.data?.data();
              if (todo == null) {
                return const Center(child: Text('Todo not found.'));
              }

              if (!_hasLoadedText) {
                _controller.text = todo.text;
                _hasLoadedText = true;
              }

              return ListView(
                children: [
                  TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      labelText: 'Todo text',
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: 18),
                  _buildDueAtControls(todo),
                  const SizedBox(height: 18),
                  _buildTimeline(todo),
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _isSaving || _isDeleting ? null : _saveTodo,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: const Text('Save'),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
