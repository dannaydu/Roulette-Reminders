import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:todo/services/auth_service.dart';
import 'package:todo/screens/todo_detail_screen.dart';
import 'package:todo/todo.dart';
import 'package:todo/widgets/responsive_frame.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService = AuthService();
  final _controller = TextEditingController();
  final _searcbhController = TextEditingController();
  final _todosRef = FirebaseFirestore.instance
      .collection('todos')
      .withConverter<Todo>(
        fromFirestore: (snapshot, _) => Todo.fromSnapshot(snapshot),
        toFirestore: (todo, _) => todo.toSnapshot(),
      );

  bool _isDescending = true;
  String _searchQuery = '';

  String? _extractUrl(String text) {
    return RegExp(r'https?://\S+').stringMatch(text);
  }

  @override
  void dispose() {
    _controller.dispose();
    _searcbhController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('TODO Spring 2026'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _authService.signOut();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ResponsiveFrame(
          maxWidth: 860,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSearchField(),
              const SizedBox(height: 12),
              Expanded(
                child: userId == null
                    ? _buildEmptyState(
                        icon: Icons.lock_outline,
                        text: 'Sign in to view your todos.',
                      )
                    : _buildTodoList(userId),
              ),
              const SizedBox(height: 12),
              _buildAddTodoBar(userId),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searcbhController,
      onChanged: (value) {
        setState(() {
          _searchQuery = value.trim().toLowerCase();
        });
      },
      decoration: InputDecoration(
        hintText: 'Search todos',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: IconButton(
          tooltip: _isDescending ? 'Newest first' : 'Oldest first',
          onPressed: () {
            setState(() {
              _isDescending = !_isDescending;
            });
          },
          icon: Icon(
            _isDescending ? Icons.arrow_downward : Icons.arrow_upward,
          ),
        ),
      ),
    );
  }

  Widget _buildTodoList(String userId) {
    return StreamBuilder<QuerySnapshot<Todo>>(
      stream: _todosRef
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: _isDescending)
          .where(
            'text',
            isGreaterThanOrEqualTo: _searchQuery,
            isLessThan: '${_searchQuery}z',
          )
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final errorMessage = snapshot.error.toString();
          final indexUrl = _extractUrl(errorMessage);
          return SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Could not load todos.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                SelectableText(
                  errorMessage,
                  textAlign: TextAlign.center,
                ),
                if (indexUrl != null) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Index link:',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    indexUrl,
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final todos = snapshot.data?.docs ?? [];
        if (todos.isEmpty) {
          return _buildEmptyState(
            icon: Icons.check_circle_outline,
            text: _searchQuery.isEmpty ? 'No todos yet.' : 'No matching todos.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: todos.length,
          itemBuilder: (context, index) {
            final todoSnapshot = todos[index];
            final todo = todoSnapshot.data();

            return _buildTodoCard(
              todoId: todoSnapshot.id,
              todo: todo,
            );
          },
        );
      },
    );
  }

  Widget _buildTodoCard({
    required String todoId,
    required Todo todo,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => TodoDetailScreen(todoId: todoId),
              ),
            );
          },
          title: Text(
            todo.text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              decoration: todo.completedAt != null
                  ? TextDecoration.lineThrough
                  : null,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 10,
              runSpacing: 6,
              children: [
                _buildMetaLabel(
                  icon: Icons.access_time,
                  text: 'Created ${_formatDateTime(todo.createdAt)}',
                ),
                if (todo.dueAt != null)
                  _buildMetaLabel(
                    icon: Icons.event,
                    text: 'Due ${_formatDateTime(todo.dueAt!)}',
                    color: Theme.of(context).colorScheme.secondary,
                  ),
              ],
            ),
          ),
          leading: Checkbox(
            value: todo.completedAt != null,
            onChanged: (value) {
              final updatedTodo = todo.copyWith(
                completedAt: value == true ? DateTime.now() : null,
              );

              FirebaseFirestore.instance
                  .collection('todos')
                  .doc(todoId)
                  .update(updatedTodo.toSnapshot());
            },
          ),
          trailing: const Icon(Icons.chevron_right),
        ),
      ),
    );
  }

  Widget _buildMetaLabel({
    required IconData icon,
    required String text,
    Color? color,
  }) {
    final labelColor = color ?? Theme.of(context).colorScheme.onSurfaceVariant;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: labelColor),
        const SizedBox(width: 4),
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: labelColor,
          ),
        ),
      ],
    );
  }

  Widget _buildAddTodoBar(String? userId) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 520;
        final input = TextField(
          controller: _controller,
          onSubmitted: (_) => _addTodo(userId),
          decoration: const InputDecoration(
            hintText: 'Add your todo',
            prefixIcon: Icon(Icons.add_task),
          ),
        );
        final button = FilledButton.icon(
          onPressed: () => _addTodo(userId),
          icon: const Icon(Icons.send),
          label: const Text('Add todo'),
        );

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              input,
              const SizedBox(height: 10),
              button,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: input),
            const SizedBox(width: 12),
            button,
          ],
        );
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String text,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42, color: colorScheme.secondary),
          const SizedBox(height: 12),
          Text(
            text,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
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

  void _addTodo(String? userId) {
    final text = _controller.text.trim();
    if (userId == null || text.isEmpty) {
      return;
    }

    final todo = Todo(
      text: text,
      userId: userId,
      createdAt: DateTime.now(),
    );

    _todosRef.add(todo);
    _controller.clear();
  }
}
