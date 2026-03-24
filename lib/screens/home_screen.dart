import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:todo/services/auth_service.dart';
import 'package:todo/todo.dart';

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
        title: Text('TODO Spring 2026'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              await _authService.signOut();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searcbhController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.trim().toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search...',
                border: OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      _isDescending = !_isDescending;
                    });
                  },
                  icon: Icon(_isDescending ? Icons.arrow_downward : Icons.arrow_upward),
                ),
              ),
            ),
          ),  
          Expanded(
            child: userId == null
                ? const Center(child: Text('Sign in to view your todos.'))
                : StreamBuilder<QuerySnapshot<Todo>>(
                    stream: _todosRef
                        .where('userId', isEqualTo: userId)
                        .orderBy('createdAt', descending: _isDescending)
                        .where( 'text', isGreaterThanOrEqualTo: _searchQuery,
                                isLessThan: _searchQuery + 'z')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        final errorMessage = snapshot.error.toString();
                        final indexUrl = _extractUrl(errorMessage);
                        return SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
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
                        return const Center(child: Text('No todos yet.'));
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        itemCount: todos.length,
                        itemBuilder: (context, index) {
                          final todo = todos[index].data();

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              title: Text(
                                todo.text,
                                style: TextStyle(
                                  decoration: todo.completedAt != null
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                              subtitle: Text(
                                'Created at: ${todo.createdAt.toLocal()}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              leading: Checkbox(value: todo.completedAt != null, 
                              onChanged: (value) {
                                final updatedTodo = Todo(
                                  text: todo.text,
                                  userId: todo.userId,
                                  createdAt: todo.createdAt,
                                  completedAt: value == true ? DateTime.now() : null,
                                );

                                FirebaseFirestore.instance
                                    .collection('todos')
                                    .doc(todos[index].id)
                                    .update(updatedTodo.toSnapshot());
                              }
                                
                                // Handle checkbox change
                              ),
                              
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Add your todo...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                FilledButton(
                  child: Text('Send'),
                  onPressed: () {
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
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
