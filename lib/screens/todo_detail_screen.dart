import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:todo/services/notification_service.dart';
import 'package:todo/todo.dart';
import 'package:todo/widgets/responsive_frame.dart';
import 'package:url_launcher/url_launcher.dart';

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
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();
  final _subCategoryController = TextEditingController();
  final _subTodoController = TextEditingController();
  final _locationController = TextEditingController();
  late final DocumentReference<Todo> _todoRef;

  bool _hasLoadedFormState = false;
  bool _isDeleting = false;
  bool _isSaving = false;
  bool _isUploadingAttachment = false;
  TodoPriority _selectedPriority = TodoPriority.medium;
  TodoRepeatFrequency _repeatFrequency = TodoRepeatFrequency.none;

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
    _titleController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _subCategoryController.dispose();
    _subTodoController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _saveTodo() async {
    final title = _titleController.text.trim();
    if (title.isEmpty || _isSaving || _isDeleting || _isUploadingAttachment) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _todoRef.update({
        'text': title,
        'description': _descriptionController.text.trim(),
        'category': _categoryController.text.trim(),
        'location': _locationController.text.trim(),
        'priority': _selectedPriority.name,
        'repeatFrequency': _repeatFrequency.name,
      });

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
    if (_isSaving || _isDeleting || _isUploadingAttachment) {
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
    if (_isSaving || _isDeleting || _isUploadingAttachment) {
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
            todoText: _titleController.text.trim(),
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
    if (_isDeleting || _isSaving || _isUploadingAttachment) {
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
      final snapshot = await _todoRef.get();
      final todo = snapshot.data();
      if (todo != null) {
        for (final attachment in todo.attachments) {
          if (attachment.storagePath.isEmpty) {
            continue;
          }
          try {
            await FirebaseStorage.instance.ref(attachment.storagePath).delete();
          } catch (_) {}
        }
      }

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

  Future<void> _addSubCategory(Todo todo) async {
    final text = _subCategoryController.text.trim();
    if (text.isEmpty || _isSaving || _isDeleting || _isUploadingAttachment) {
      return;
    }

    final exists = todo.subCategories.any(
      (entry) => entry.toLowerCase() == text.toLowerCase(),
    );
    if (exists) {
      _showSnackBar('That sub-category already exists.');
      return;
    }

    final updatedSubCategories = [...todo.subCategories, text];
    await _todoRef.update({'subCategories': updatedSubCategories});
    _subCategoryController.clear();
  }

  Future<void> _removeSubCategory(Todo todo, String subCategory) {
    final updatedSubCategories = todo.subCategories
        .where((entry) => entry != subCategory)
        .toList(growable: false);
    return _todoRef.update({'subCategories': updatedSubCategories});
  }

  Future<void> _addSubTodo(Todo todo) async {
    final text = _subTodoController.text.trim();
    if (text.isEmpty || _isSaving || _isDeleting || _isUploadingAttachment) {
      return;
    }

    final updatedSubTodos = [
      ...todo.subTodos,
      TodoSubTask(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        text: text,
      ),
    ];
    await _todoRef.update({
      'subTodos': updatedSubTodos.map((subTodo) => subTodo.toMap()).toList(),
    });
    _subTodoController.clear();
  }

  Future<void> _toggleSubTodo(
    Todo todo,
    TodoSubTask subTodo,
    bool? value,
  ) async {
    final updatedSubTodos = todo.subTodos
        .map(
          (entry) => entry.id == subTodo.id
              ? entry.copyWith(isCompleted: value ?? false)
              : entry,
        )
        .toList(growable: false);
    await _todoRef.update({
      'subTodos': updatedSubTodos.map((entry) => entry.toMap()).toList(),
    });
  }

  Future<void> _removeSubTodo(Todo todo, TodoSubTask subTodo) {
    final updatedSubTodos = todo.subTodos
        .where((entry) => entry.id != subTodo.id)
        .toList(growable: false);
    return _todoRef.update({
      'subTodos': updatedSubTodos.map((entry) => entry.toMap()).toList(),
    });
  }

  Future<void> _pickAttachment({
    required Todo todo,
    required FileType type,
  }) async {
    if (_isSaving || _isDeleting || _isUploadingAttachment) {
      return;
    }

    final userId = FirebaseAuth.instance.currentUser?.uid ?? todo.userId;
    if (userId.isEmpty) {
      _showSnackBar('You must be signed in to upload attachments.');
      return;
    }

    final result = await FilePicker.pickFiles(
      type: type,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty || !mounted) {
      return;
    }

    final pickedFile = result.files.single;
    final fileBytes = pickedFile.bytes;
    if (fileBytes == null) {
      _showSnackBar('Could not read the selected file.');
      return;
    }

    setState(() {
      _isUploadingAttachment = true;
    });

    try {
      final safeName = _storageSafeFileName(
        pickedFile.name.isEmpty ? 'attachment' : pickedFile.name,
      );
      final contentType = _contentTypeForFileName(
        pickedFile.name.isEmpty ? 'attachment' : pickedFile.name,
      );
      final storagePath =
          'todo_attachments/$userId/${widget.todoId}/${DateTime.now().millisecondsSinceEpoch}_$safeName';
      final storageRef = FirebaseStorage.instance.ref(storagePath);
      final uploadTask = await storageRef.putData(
        fileBytes,
        SettableMetadata(contentType: contentType),
      );
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      final attachment = TodoAttachment(
        name: pickedFile.name.isEmpty ? 'attachment' : pickedFile.name,
        url: downloadUrl,
        storagePath: storagePath,
        createdAt: DateTime.now(),
        contentType: contentType,
        sizeBytes: pickedFile.size,
      );

      final updatedAttachments = [...todo.attachments, attachment];
      await _todoRef.update({
        'attachments': updatedAttachments
            .map((entry) => entry.toMap())
            .toList(growable: false),
      });
      _showSnackBar('Attachment uploaded.');
    } catch (error) {
      _showSnackBar('Could not upload attachment: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingAttachment = false;
        });
      }
    }
  }

  Future<void> _removeAttachment(
    Todo todo,
    TodoAttachment attachment,
  ) async {
    if (_isSaving || _isDeleting || _isUploadingAttachment) {
      return;
    }

    setState(() {
      _isUploadingAttachment = true;
    });

    try {
      if (attachment.storagePath.isNotEmpty) {
        await FirebaseStorage.instance.ref(attachment.storagePath).delete();
      }

      final updatedAttachments = todo.attachments
          .where((entry) => entry.storagePath != attachment.storagePath)
          .toList(growable: false);
      await _todoRef.update({
        'attachments': updatedAttachments
            .map((entry) => entry.toMap())
            .toList(growable: false),
      });
      _showSnackBar('Attachment removed.');
    } catch (error) {
      _showSnackBar('Could not remove attachment: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingAttachment = false;
        });
      }
    }
  }

  Future<void> _openAttachment(TodoAttachment attachment) async {
    final uri = Uri.tryParse(attachment.url);
    if (uri == null) {
      _showSnackBar('This attachment link is invalid.');
      return;
    }

    final didLaunch = await launchUrl(uri);
    if (!didLaunch) {
      _showSnackBar('Could not open the attachment.');
    }
  }

  Widget _buildPriorityControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Priority', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: TodoPriority.values
              .map(
                (priority) => ChoiceChip(
                  label: Text(_priorityLabel(priority)),
                  selected: _selectedPriority == priority,
                  onSelected: _isSaving || _isDeleting || _isUploadingAttachment
                      ? null
                      : (_) {
                          setState(() {
                            _selectedPriority = priority;
                          });
                        },
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildRepeatControls() {
    return DropdownButtonFormField<TodoRepeatFrequency>(
      initialValue: _repeatFrequency,
      decoration: const InputDecoration(
        labelText: 'Repeating task',
      ),
      items: TodoRepeatFrequency.values
          .map(
            (frequency) => DropdownMenuItem<TodoRepeatFrequency>(
              value: frequency,
              child: Text(_repeatLabel(frequency)),
            ),
          )
          .toList(),
      onChanged: _isSaving || _isDeleting || _isUploadingAttachment
          ? null
          : (value) {
              if (value == null) {
                return;
              }
              setState(() {
                _repeatFrequency = value;
              });
            },
    );
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
                onPressed: _isSaving || _isDeleting || _isUploadingAttachment
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
                onPressed: _isSaving || _isDeleting || _isUploadingAttachment
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

  Widget _buildSubCategoryControls(Todo todo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sub-categories', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _subCategoryController,
                enabled: !_isSaving && !_isDeleting && !_isUploadingAttachment,
                decoration: const InputDecoration(
                  hintText: 'Add a sub-category',
                ),
                onSubmitted: (_) => _addSubCategory(todo),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: _isSaving || _isDeleting || _isUploadingAttachment
                  ? null
                  : () => _addSubCategory(todo),
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
          ],
        ),
        if (todo.subCategories.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: todo.subCategories
                .map(
                  (subCategory) => InputChip(
                    label: Text(subCategory),
                    onDeleted:
                        _isSaving || _isDeleting || _isUploadingAttachment
                        ? null
                        : () => _removeSubCategory(todo, subCategory),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildSubTodoControls(Todo todo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Sub-todos', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            Text(
              '${todo.completedSubTodoCount}/${todo.subTodos.length}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _subTodoController,
                enabled: !_isSaving && !_isDeleting && !_isUploadingAttachment,
                decoration: const InputDecoration(
                  hintText: 'Add a sub-todo',
                ),
                onSubmitted: (_) => _addSubTodo(todo),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: _isSaving || _isDeleting || _isUploadingAttachment
                  ? null
                  : () => _addSubTodo(todo),
              icon: const Icon(Icons.add_task),
              label: const Text('Add'),
            ),
          ],
        ),
        if (todo.subTodos.isNotEmpty) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: todo.subTodoProgress,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 12),
          for (final subTodo in todo.subTodos) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: ListTile(
                leading: Checkbox(
                  value: subTodo.isCompleted,
                  onChanged: (value) => _toggleSubTodo(todo, subTodo, value),
                ),
                title: Text(
                  subTodo.text,
                  style: TextStyle(
                    decoration: subTodo.isCompleted
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                trailing: IconButton(
                  tooltip: 'Delete sub-todo',
                  onPressed: _isSaving || _isDeleting || _isUploadingAttachment
                      ? null
                      : () => _removeSubTodo(todo, subTodo),
                  icon: const Icon(Icons.delete_outline),
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildAttachmentControls(Todo todo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Attachments', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            if (_isUploadingAttachment)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _isSaving || _isDeleting || _isUploadingAttachment
                  ? null
                  : () => _pickAttachment(
                      todo: todo,
                      type: FileType.image,
                    ),
              icon: const Icon(Icons.image_outlined),
              label: const Text('Attach image'),
            ),
            OutlinedButton.icon(
              onPressed: _isSaving || _isDeleting || _isUploadingAttachment
                  ? null
                  : () => _pickAttachment(
                      todo: todo,
                      type: FileType.any,
                    ),
              icon: const Icon(Icons.attach_file),
              label: const Text('Attach file'),
            ),
          ],
        ),
        if (todo.attachments.isNotEmpty) ...[
          const SizedBox(height: 12),
          for (final attachment in todo.attachments) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAttachmentPreview(attachment),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          attachment.name,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatAttachmentSize(attachment.sizeBytes),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Open attachment',
                    onPressed: () => _openAttachment(attachment),
                    icon: const Icon(Icons.open_in_new),
                  ),
                  IconButton(
                    tooltip: 'Remove attachment',
                    onPressed:
                        _isSaving || _isDeleting || _isUploadingAttachment
                        ? null
                        : () => _removeAttachment(todo, attachment),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildAttachmentPreview(TodoAttachment attachment) {
    final colorScheme = Theme.of(context).colorScheme;

    if (attachment.isImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          attachment.url,
          width: 72,
          height: 72,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            width: 72,
            height: 72,
            color: colorScheme.surfaceContainerHighest,
            alignment: Alignment.center,
            child: const Icon(Icons.broken_image_outlined),
          ),
        ),
      );
    }

    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.insert_drive_file_outlined),
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
        if (todo.repeatFrequency != TodoRepeatFrequency.none)
          _buildTimestamp(
            icon: Icons.repeat,
            label: 'Repeats',
            value: _repeatLabel(todo.repeatFrequency),
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

  String _formatDateTime(DateTime dateTime) {
    final localDateTime = dateTime.toLocal();
    final localizations = MaterialLocalizations.of(context);
    final date = localizations.formatMediumDate(localDateTime);
    final time = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(localDateTime),
    );
    return '$date at $time';
  }

  String _formatAttachmentSize(int sizeBytes) {
    if (sizeBytes <= 0) {
      return 'Unknown size';
    }
    if (sizeBytes < 1024) {
      return '$sizeBytes B';
    }
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _storageSafeFileName(String name) {
    return name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  }

  String? _contentTypeForFileName(String name) {
    final extension = name.split('.').last.toLowerCase();
    return switch (extension) {
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'pdf' => 'application/pdf',
      'txt' => 'text/plain',
      'csv' => 'text/csv',
      'json' => 'application/json',
      _ => null,
    };
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

  String _priorityLabel(TodoPriority priority) {
    return switch (priority) {
      TodoPriority.high => 'High priority',
      TodoPriority.medium => 'Medium priority',
      TodoPriority.low => 'Low priority',
    };
  }

  String _repeatLabel(TodoRepeatFrequency frequency) {
    return switch (frequency) {
      TodoRepeatFrequency.none => 'Does not repeat',
      TodoRepeatFrequency.daily => 'Repeats daily',
      TodoRepeatFrequency.weekly => 'Repeats weekly',
      TodoRepeatFrequency.monthly => 'Repeats monthly',
    };
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
            onPressed: _isDeleting || _isSaving || _isUploadingAttachment
                ? null
                : _deleteTodo,
          ),
        ],
      ),
      body: SafeArea(
        child: ResponsiveFrame(
          maxWidth: 760,
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

              if (!_hasLoadedFormState) {
                _titleController.text = todo.text;
                _descriptionController.text = todo.description;
                _categoryController.text = todo.category;
                _locationController.text = todo.location;
                _selectedPriority = todo.priority;
                _repeatFrequency = todo.repeatFrequency;
                _hasLoadedFormState = true;
              }

              return ListView(
                children: [
                  TextField(
                    controller: _titleController,
                    enabled:
                        !_isSaving && !_isDeleting && !_isUploadingAttachment,
                    decoration: const InputDecoration(
                      labelText: 'Todo title',
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _descriptionController,
                    enabled:
                        !_isSaving && !_isDeleting && !_isUploadingAttachment,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      alignLabelWithHint: true,
                    ),
                    minLines: 3,
                    maxLines: 5,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _categoryController,
                    enabled:
                        !_isSaving && !_isDeleting && !_isUploadingAttachment,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSubCategoryControls(todo),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _locationController,
                    enabled:
                        !_isSaving && !_isDeleting && !_isUploadingAttachment,
                    decoration: const InputDecoration(
                      labelText: 'Location',
                      hintText: 'Room, address, or place name',
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildPriorityControls(),
                  const SizedBox(height: 16),
                  _buildRepeatControls(),
                  const SizedBox(height: 16),
                  _buildDueAtControls(todo),
                  const SizedBox(height: 16),
                  _buildSubTodoControls(todo),
                  const SizedBox(height: 16),
                  _buildAttachmentControls(todo),
                  const SizedBox(height: 16),
                  _buildTimeline(todo),
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed:
                          _isSaving || _isDeleting || _isUploadingAttachment
                          ? null
                          : _saveTodo,
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
