import 'package:cloud_firestore/cloud_firestore.dart';

class Todo {
  final String text;
  final String userId;
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime? dueAt;

  Todo({
    required this.text,
    required this.userId,
    required this.createdAt,
    this.completedAt,
    this.dueAt,
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
    final dueAt = data['dueAt'];

    return Todo(
      text: data['text'] as String,
      userId: data['userId'] as String,
      createdAt: createdAt.toDate(),
      completedAt: completedAt is Timestamp ? completedAt.toDate() : null,
      dueAt: dueAt is Timestamp ? dueAt.toDate() : null,
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
      'dueAt': dueAt == null ? null : Timestamp.fromDate(dueAt!),
    };
  }

  Todo copyWith({
    String? text,
    String? userId,
    DateTime? createdAt,
    Object? completedAt = _sentinel,
    Object? dueAt = _sentinel,
  }) {
    return Todo(
      text: text ?? this.text,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt == _sentinel
          ? this.completedAt
          : completedAt as DateTime?,
      dueAt: dueAt == _sentinel ? this.dueAt : dueAt as DateTime?,
    );
  }
}

const _sentinel = Object();
