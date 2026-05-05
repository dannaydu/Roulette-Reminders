import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:todo/services/notification_service.dart';
import 'package:todo/todo.dart';

class TodoService {
  TodoService._();

  static final TodoService instance = TodoService._();

  final CollectionReference<Todo> _todosRef = FirebaseFirestore.instance
      .collection('todos')
      .withConverter<Todo>(
        fromFirestore: (snapshot, _) => Todo.fromSnapshot(snapshot),
        toFirestore: (todo, _) => todo.toSnapshot(),
      );

  CollectionReference<Todo> get todosRef => _todosRef;

  Future<void> toggleCompletion({
    required String todoId,
    required Todo todo,
    required bool isCompleted,
  }) async {
    final now = DateTime.now();
    final todoRef = _todosRef.doc(todoId);
    final batch = FirebaseFirestore.instance.batch();

    batch.update(todoRef, {
      'completedAt': isCompleted ? Timestamp.fromDate(now) : null,
    });

    Todo? nextOccurrence;
    String? nextOccurrenceId;

    if (isCompleted &&
        todo.repeatFrequency != TodoRepeatFrequency.none &&
        todo.spawnedNextOccurrenceAt == null) {
      final nextDueAt = _nextDueAt(
        repeatFrequency: todo.repeatFrequency,
        baseDate: todo.dueAt ?? now,
        now: now,
      );

      nextOccurrence = todo.copyWith(
        createdAt: now,
        completedAt: null,
        dueAt: nextDueAt,
        spawnedNextOccurrenceAt: null,
        subTodos: todo.subTodos
            .map(
              (subTodo) => subTodo.copyWith(isCompleted: false),
            )
            .toList(growable: false),
      );

      final nextTodoRef = _todosRef.doc();
      nextOccurrenceId = nextTodoRef.id;

      batch.set(nextTodoRef, nextOccurrence);
      batch.update(todoRef, {
        'spawnedNextOccurrenceAt': Timestamp.fromDate(now),
      });
    }

    await batch.commit();

    if (isCompleted) {
      await NotificationService.instance.cancelTodoDueNotification(todoId);
    } else if (todo.dueAt != null && todo.dueAt!.isAfter(now)) {
      await NotificationService.instance.scheduleTodoDueNotification(
        todoId: todoId,
        todoText: todo.text,
        dueAt: todo.dueAt!,
      );
    }

    if (nextOccurrenceId != null &&
        nextOccurrence != null &&
        nextOccurrence.dueAt != null &&
        nextOccurrence.dueAt!.isAfter(now)) {
      await NotificationService.instance.scheduleTodoDueNotification(
        todoId: nextOccurrenceId,
        todoText: nextOccurrence.text,
        dueAt: nextOccurrence.dueAt!,
      );
    }
  }

  DateTime _nextDueAt({
    required TodoRepeatFrequency repeatFrequency,
    required DateTime baseDate,
    required DateTime now,
  }) {
    var nextDate = switch (repeatFrequency) {
      TodoRepeatFrequency.none => baseDate,
      TodoRepeatFrequency.daily => baseDate.add(const Duration(days: 1)),
      TodoRepeatFrequency.weekly => baseDate.add(const Duration(days: 7)),
      TodoRepeatFrequency.monthly => _addMonths(baseDate, 1),
    };

    while (!nextDate.isAfter(now)) {
      nextDate = switch (repeatFrequency) {
        TodoRepeatFrequency.none => now.add(const Duration(days: 1)),
        TodoRepeatFrequency.daily => nextDate.add(const Duration(days: 1)),
        TodoRepeatFrequency.weekly => nextDate.add(const Duration(days: 7)),
        TodoRepeatFrequency.monthly => _addMonths(nextDate, 1),
      };
    }

    return nextDate;
  }

  DateTime _addMonths(DateTime date, int months) {
    final targetMonth = date.month + months;
    final targetYear = date.year + ((targetMonth - 1) ~/ 12);
    final normalizedMonth = ((targetMonth - 1) % 12) + 1;
    final lastDayOfTargetMonth = DateTime(
      targetYear,
      normalizedMonth + 1,
      0,
    ).day;
    final targetDay = date.day <= lastDayOfTargetMonth
        ? date.day
        : lastDayOfTargetMonth;

    return DateTime(
      targetYear,
      normalizedMonth,
      targetDay,
      date.hour,
      date.minute,
      date.second,
      date.millisecond,
      date.microsecond,
    );
  }
}
