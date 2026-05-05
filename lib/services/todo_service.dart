import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:todo/services/casino_service.dart';
import 'package:todo/services/notification_service.dart';
import 'package:todo/todo.dart';

class TodoCompletionResult {
  const TodoCompletionResult({
    required this.spinAwarded,
    this.bossBetResolved = false,
    this.bossBetWon = false,
    this.bossBetAmount = 0,
    this.bossBetPayout = 0,
  });

  final bool spinAwarded;
  final bool bossBetResolved;
  final bool bossBetWon;
  final int bossBetAmount;
  final int bossBetPayout;
}

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

  Future<void> settleExpiredBossBet({
    required String todoId,
    required Todo todo,
  }) async {
    if (!todo.isBossBetExpired() || !todo.bossBet.isActive) {
      return;
    }

    await _todosRef.doc(todoId).update({
      'bossBet': todo.bossBet
          .copyWith(
            status: TodoBossBetStatus.lost,
            resolvedAt: DateTime.now(),
          )
          .toMap(),
    });
  }

  Future<void> placeBossBet({
    required String todoId,
    required Todo todo,
    required int amount,
  }) async {
    if (amount < 1) {
      throw StateError('Choose a valid chip amount.');
    }
    if (todo.userId.isEmpty) {
      throw StateError('You must be signed in to place a bet.');
    }

    final now = DateTime.now();
    final dueAt = todo.dueAt;
    if (dueAt == null || !dueAt.isAfter(now)) {
      throw StateError('Add a future due date before placing a Boss Bet.');
    }

    final todoRef = _todosRef.doc(todoId);
    final profileRef = CasinoService.instance.profileRef(todo.userId);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final todoSnapshot = await transaction.get(todoRef);
      final currentTodo = todoSnapshot.data();
      if (currentTodo == null) {
        throw StateError('That task no longer exists.');
      }
      if (currentTodo.isCompleted) {
        throw StateError('Completed tasks cannot take new bets.');
      }
      if (currentTodo.hasActiveBossBet(now) || currentTodo.hasBossBet) {
        throw StateError('This task already has a settled or active Boss Bet.');
      }
      if (currentTodo.dueAt == null || !currentTodo.dueAt!.isAfter(now)) {
        throw StateError('Add a future due date before placing a Boss Bet.');
      }

      final profileSnapshot = await transaction.get(profileRef);
      final profile = CasinoProfile.fromData(profileSnapshot.data());
      if (profile.balance < amount) {
        throw StateError('Not enough House Chips for that bet.');
      }

      transaction.set(
        profileRef,
        {
          'balance': FieldValue.increment(-amount),
          'updatedAt': Timestamp.fromDate(now),
        },
        SetOptions(merge: true),
      );
      transaction.update(todoRef, {
        'bossBet': TodoBossBet(
          amount: amount,
          status: TodoBossBetStatus.active,
          placedAt: now,
          resolvedAt: null,
        ).toMap(),
      });
    });
  }

  Future<TodoCompletionResult> toggleCompletion({
    required String todoId,
    required Todo todo,
    required bool isCompleted,
  }) async {
    final now = DateTime.now();
    final isNewCompletion = isCompleted && !todo.isCompleted;
    final todoRef = _todosRef.doc(todoId);
    final batch = FirebaseFirestore.instance.batch();
    final profileUpdates = <String, dynamic>{};
    var bossBetResolved = false;
    var bossBetWon = false;
    var bossBetAmount = 0;
    var bossBetPayout = 0;

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
        bossBet: TodoBossBet.none,
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

    if (isNewCompletion && todo.userId.isNotEmpty) {
      profileUpdates['pendingSpins'] = FieldValue.increment(1);
      profileUpdates['spinsEarned'] = FieldValue.increment(1);
    }

    if (isNewCompletion && todo.bossBet.isActive) {
      bossBetResolved = true;
      bossBetAmount = todo.bossBet.amount;
      final completedBeforeDue =
          todo.dueAt == null || !now.isAfter(todo.dueAt!);
      bossBetWon = completedBeforeDue;
      bossBetPayout = completedBeforeDue ? todo.bossBetPayout : 0;

      batch.update(todoRef, {
        'bossBet': todo.bossBet
            .copyWith(
              status: completedBeforeDue
                  ? TodoBossBetStatus.won
                  : TodoBossBetStatus.lost,
              resolvedAt: now,
            )
            .toMap(),
      });

      if (completedBeforeDue && todo.userId.isNotEmpty) {
        profileUpdates['balance'] = FieldValue.increment(bossBetPayout);
        profileUpdates['lifetimeWinnings'] = FieldValue.increment(
          bossBetPayout,
        );
        profileUpdates['lastPayout'] = bossBetPayout;
      }
    }

    if (profileUpdates.isNotEmpty && todo.userId.isNotEmpty) {
      profileUpdates['updatedAt'] = Timestamp.fromDate(now);
      batch.set(
        CasinoService.instance.profileRef(todo.userId),
        profileUpdates,
        SetOptions(merge: true),
      );
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

    return TodoCompletionResult(
      spinAwarded: isNewCompletion,
      bossBetResolved: bossBetResolved,
      bossBetWon: bossBetWon,
      bossBetAmount: bossBetAmount,
      bossBetPayout: bossBetPayout,
    );
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
