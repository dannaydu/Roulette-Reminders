import 'package:todo/todo.dart';

class DailyOverview {
  const DailyOverview({
    required this.headline,
    required this.summary,
    required this.focusPoints,
  });

  final String headline;
  final String summary;
  final List<String> focusPoints;
}

class DailyOverviewService {
  const DailyOverviewService();

  DailyOverview generate({
    required List<Todo> todos,
    required DateTime now,
  }) {
    final openTodos = todos.where((todo) => !todo.isCompleted).toList();
    final completedToday = todos.where((todo) {
      final completedAt = todo.completedAt?.toLocal();
      final localNow = now.toLocal();
      if (completedAt == null) {
        return false;
      }

      return completedAt.year == localNow.year &&
          completedAt.month == localNow.month &&
          completedAt.day == localNow.day;
    }).length;
    final overdueTodos = openTodos
        .where((todo) => todo.isOverdue(now))
        .toList();
    final dueTodayTodos = openTodos.where((todo) {
      final dueAt = todo.dueAt?.toLocal();
      final localNow = now.toLocal();
      if (dueAt == null) {
        return false;
      }

      return dueAt.year == localNow.year &&
          dueAt.month == localNow.month &&
          dueAt.day == localNow.day;
    }).toList();
    final highPriorityTodos = openTodos
        .where((todo) => todo.priority == TodoPriority.high)
        .toList();
    final repeatingTodos = openTodos
        .where((todo) => todo.repeatFrequency != TodoRepeatFrequency.none)
        .length;
    final strongestCategory = _topCategory(openTodos);

    final headline = switch ((overdueTodos.length, dueTodayTodos.length)) {
      (> 0, _) => 'Handle the red-zone items first.',
      (0, > 0) => 'You have a clear list for today.',
      _ when openTodos.isEmpty => 'Today is clear.',
      _ => 'Momentum is on your side today.',
    };

    final summary = StringBuffer()
      ..write(
        openTodos.isEmpty
            ? 'Everything on your board is complete.'
            : 'You have ${openTodos.length} open task${openTodos.length == 1 ? '' : 's'} right now.',
      );

    if (dueTodayTodos.isNotEmpty) {
      summary.write(
        ' ${dueTodayTodos.length} ${dueTodayTodos.length == 1 ? 'is' : 'are'} due today.',
      );
    }

    if (overdueTodos.isNotEmpty) {
      summary.write(
        ' ${overdueTodos.length} ${overdueTodos.length == 1 ? 'is' : 'are'} already overdue.',
      );
    }

    if (completedToday > 0) {
      summary.write(' You have already finished $completedToday today.');
    }

    final focusPoints = <String>[
      if (overdueTodos.isNotEmpty)
        'Close ${overdueTodos.length} overdue task${overdueTodos.length == 1 ? '' : 's'} before starting new work.',
      if (highPriorityTodos.isNotEmpty)
        'Prioritize ${highPriorityTodos.first.text} and the rest of your high-priority stack.',
      if (dueTodayTodos.length > 1)
        'Bundle today\'s due tasks into one focused block to reduce context switching.',
      if (strongestCategory != null)
        'Most of your open work sits in "$strongestCategory", so that category is your highest-leverage focus area.',
      if (repeatingTodos > 0)
        '$repeatingTodos repeating task${repeatingTodos == 1 ? '' : 's'} will keep feeding the board, so clear the fixed deadlines first.',
      if (openTodos.isEmpty)
        'Use the breathing room to plan tomorrow or add your next high-value task.',
    ].take(3).toList(growable: false);

    return DailyOverview(
      headline: headline,
      summary: summary.toString(),
      focusPoints: focusPoints,
    );
  }

  String? _topCategory(List<Todo> todos) {
    final counts = <String, int>{};
    for (final todo in todos) {
      final category = todo.category.trim();
      if (category.isEmpty) {
        continue;
      }
      counts.update(category, (value) => value + 1, ifAbsent: () => 1);
    }

    if (counts.isEmpty) {
      return null;
    }

    final sortedEntries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sortedEntries.first.key;
  }
}
