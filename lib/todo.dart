import 'package:cloud_firestore/cloud_firestore.dart';

class Todo {
  final String text;
  final String userId;
  final DateTime createdAt;
  final DateTime? completedAt;

  Todo({
    required this.text,
    required this.userId,
    required this.createdAt,
    this.completedAt,
  });

  factory Todo.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();
    if (data == null) {
      throw StateError('Todo ${snapshot.id} has no data.');
    }

    final createdAt = data['createdAt'];
    if (createdAt is! Timestamp) {
      throw StateError('Todo ${snapshot.id} is missing a valid createdAt.');
    }

    final completedAt = data['completedAt'];

    return Todo(
      text: data['text'] as String,
      userId: data['userId'] as String,
      createdAt: createdAt.toDate(),
      completedAt: completedAt is Timestamp ? completedAt.toDate() : null,
    );
  }

  Map<String, dynamic> toSnapshot() {
    return {
      'text': text,
      'userId': userId,
      'createdAt': Timestamp.fromDate(createdAt),
      'completedAt': completedAt == null
          ? null
          : Timestamp.fromDate(completedAt!),
    };
  }
}
