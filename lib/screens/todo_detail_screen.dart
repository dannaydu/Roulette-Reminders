import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:todo/todo.dart';

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
      body: StreamBuilder<DocumentSnapshot<Todo>>(
        stream: _todoRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Could not load todo: ${snapshot.error}'),
              ),
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
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  labelText: 'Todo text',
                  border: OutlineInputBorder(),
                ),
                maxLines: null,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 16),
              Text('Created at: ${todo.createdAt.toLocal()}'),
              if (todo.completedAt != null) ...[
                const SizedBox(height: 8),
                Text('Completed at: ${todo.completedAt!.toLocal()}'),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isSaving || _isDeleting ? null : _saveTodo,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }
}
