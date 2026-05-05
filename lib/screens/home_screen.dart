import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:todo/screens/todo_detail_screen.dart';
import 'package:todo/services/auth_service.dart';
import 'package:todo/services/daily_overview_service.dart';
import 'package:todo/services/todo_service.dart';
import 'package:todo/todo.dart';
import 'package:todo/widgets/responsive_frame.dart';

enum _TodoStatusFilter {
  all,
  open,
  completed,
  overdue,
}

enum _TodoSort {
  newest,
  oldest,
  dueSoon,
  priority,
}

enum _HomeView {
  list,
  calendar,
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService = AuthService();
  final _controller = TextEditingController();
  final _searchController = TextEditingController();
  final _todosRef = TodoService.instance.todosRef;
  final _overviewService = const DailyOverviewService();

  String _searchQuery = '';
  TodoPriority _newTodoPriority = TodoPriority.medium;
  TodoPriority? _priorityFilter;
  _TodoStatusFilter _statusFilter = _TodoStatusFilter.all;
  _TodoSort _sort = _TodoSort.newest;
  _HomeView _view = _HomeView.list;
  DateTime _selectedCalendarDate = DateUtils.dateOnly(DateTime.now());
  DateTime _displayedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Todos'),
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
          maxWidth: 920,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: userId == null
              ? _buildEmptyState(
                  icon: Icons.lock_outline,
                  text: 'Sign in to view your todos.',
                )
              : StreamBuilder<QuerySnapshot<Todo>>(
                  stream: _todosRef
                      .where('userId', isEqualTo: userId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text('Could not load todos: ${snapshot.error}'),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final entries = (snapshot.data?.docs ?? [])
                        .map(
                          (snapshot) => _TodoEntry(
                            id: snapshot.id,
                            todo: snapshot.data(),
                          ),
                        )
                        .toList(growable: false);
                    final filteredEntries = _filteredEntries(entries);
                    final visibleEntries = _view == _HomeView.calendar
                        ? filteredEntries
                              .where(
                                (entry) => entry.todo.occursOnDate(
                                  _selectedCalendarDate,
                                ),
                              )
                              .toList(growable: false)
                        : filteredEntries;
                    final overview = _overviewService.generate(
                      todos: entries.map((entry) => entry.todo).toList(),
                      now: DateTime.now(),
                    );

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSearchField(),
                        const SizedBox(height: 12),
                        _buildToolbar(),
                        const SizedBox(height: 12),
                        _buildOverviewPanel(
                          allEntries: entries,
                          visibleEntries: visibleEntries,
                          overview: overview,
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: _view == _HomeView.calendar
                              ? _buildCalendarSection(filteredEntries)
                              : visibleEntries.isEmpty
                              ? _buildEmptyState(
                                  icon:
                                      _statusFilter ==
                                          _TodoStatusFilter.completed
                                      ? Icons.task_alt
                                      : Icons.check_circle_outline,
                                  text: _emptyStateMessage(entries.isEmpty),
                                )
                              : _buildTodoList(visibleEntries),
                        ),
                        const SizedBox(height: 12),
                        _buildAddTodoBar(userId),
                      ],
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (value) {
        setState(() {
          _searchQuery = value.trim().toLowerCase();
        });
      },
      decoration: InputDecoration(
        hintText: 'Search todos',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_searchQuery.isNotEmpty)
              IconButton(
                tooltip: 'Clear search',
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                  });
                },
                icon: const Icon(Icons.close),
              ),
            PopupMenuButton<_TodoSort>(
              tooltip: 'Sort todos',
              initialValue: _sort,
              onSelected: (value) {
                setState(() {
                  _sort = value;
                });
              },
              itemBuilder: (context) => _TodoSort.values
                  .map(
                    (value) => PopupMenuItem<_TodoSort>(
                      value: value,
                      child: Text(_sortLabel(value)),
                    ),
                  )
                  .toList(),
              icon: const Icon(Icons.sort),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    final priorityFilter = DropdownButtonFormField<TodoPriority?>(
      initialValue: _priorityFilter,
      decoration: const InputDecoration(
        labelText: 'Priority',
      ),
      items: const [
        DropdownMenuItem<TodoPriority?>(
          value: null,
          child: Text('All priorities'),
        ),
        DropdownMenuItem<TodoPriority?>(
          value: TodoPriority.high,
          child: Text('High'),
        ),
        DropdownMenuItem<TodoPriority?>(
          value: TodoPriority.medium,
          child: Text('Medium'),
        ),
        DropdownMenuItem<TodoPriority?>(
          value: TodoPriority.low,
          child: Text('Low'),
        ),
      ],
      onChanged: (value) {
        setState(() {
          _priorityFilter = value;
        });
      },
    );

    final statusChips = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _TodoStatusFilter.values
          .map(
            (status) => ChoiceChip(
              label: Text(_statusLabel(status)),
              selected: _statusFilter == status,
              onSelected: (_) {
                setState(() {
                  _statusFilter = status;
                });
              },
            ),
          )
          .toList(growable: false),
    );

    final viewToggle = SegmentedButton<_HomeView>(
      segments: const [
        ButtonSegment<_HomeView>(
          value: _HomeView.list,
          icon: Icon(Icons.view_list),
          label: Text('List'),
        ),
        ButtonSegment<_HomeView>(
          value: _HomeView.calendar,
          icon: Icon(Icons.calendar_month),
          label: Text('Calendar'),
        ),
      ],
      selected: {_view},
      onSelectionChanged: (selection) {
        setState(() {
          _view = selection.first;
        });
      },
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              statusChips,
              const SizedBox(height: 10),
              priorityFilter,
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: viewToggle,
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: statusChips),
            const SizedBox(width: 12),
            SizedBox(width: 180, child: priorityFilter),
            const SizedBox(width: 12),
            viewToggle,
          ],
        );
      },
    );
  }

  Widget _buildOverviewPanel({
    required List<_TodoEntry> allEntries,
    required List<_TodoEntry> visibleEntries,
    required DailyOverview overview,
  }) {
    final openCount = allEntries
        .where((entry) => !entry.todo.isCompleted)
        .length;
    final completedCount = allEntries
        .where((entry) => entry.todo.isCompleted)
        .length;
    final overdueCount = allEntries
        .where((entry) => entry.todo.isOverdue())
        .length;
    final progress = visibleEntries.isEmpty
        ? 0.0
        : visibleEntries.where((entry) => entry.todo.isCompleted).length /
              visibleEntries.length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildStatPill('Open', '$openCount'),
              _buildStatPill('Completed', '$completedCount'),
              _buildStatPill(
                'Overdue',
                '$overdueCount',
                emphasized: overdueCount > 0,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            overview.headline,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            overview.summary,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (overview.focusPoints.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final point in overview.focusPoints.take(2)) ...[
              Text(
                '• $point',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (point != overview.focusPoints.take(2).last)
                const SizedBox(height: 4),
            ],
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                _view == _HomeView.calendar
                    ? 'Selected day progress'
                    : '${_statusLabel(_statusFilter)} progress',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                visibleEntries.isEmpty ? '0%' : '${(progress * 100).round()}%',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill(
    String label,
    String value, {
    bool emphasized = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: emphasized
            ? colorScheme.errorContainer
            : colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label $value',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: emphasized ? colorScheme.onErrorContainer : null,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildCalendarSection(List<_TodoEntry> filteredEntries) {
    final selectedEntries = filteredEntries
        .where((entry) => entry.todo.occursOnDate(_selectedCalendarDate))
        .toList(growable: false);
    final localizations = MaterialLocalizations.of(context);
    final dateLabel = localizations.formatFullDate(_selectedCalendarDate);
    final displayedMonth = DateTime(
      _displayedMonth.year,
      _displayedMonth.month,
    );
    final firstOfMonth = DateTime(displayedMonth.year, displayedMonth.month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(
      displayedMonth.year,
      displayedMonth.month,
    );
    final firstDayOfWeekIndex = localizations.firstDayOfWeekIndex;
    final firstWeekdayIndex = firstOfMonth.weekday % 7;
    final leadingEmptyCells = (firstWeekdayIndex - firstDayOfWeekIndex + 7) % 7;
    final visibleDayCount = leadingEmptyCells + daysInMonth;
    final trailingEmptyCells = (7 - (visibleDayCount % 7)) % 7;
    final totalCells = visibleDayCount + trailingEmptyCells;
    final weekCount = totalCells ~/ 7;
    final taskDateKeys = filteredEntries
        .map((entry) => _dateKey(entry.todo.calendarAnchor))
        .toSet();
    final weekdayLabels = List<String>.generate(7, (index) {
      final labelIndex = (firstDayOfWeekIndex + index) % 7;
      return localizations.narrowWeekdays[labelIndex];
    }, growable: false);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompactHeight = constraints.maxHeight < 640;
        final cardPadding = isCompactHeight ? 10.0 : 12.0;
        final gridSpacing = isCompactHeight ? 4.0 : 6.0;
        final monthHeaderSpacing = isCompactHeight ? 6.0 : 8.0;
        final dateHeaderSpacing = isCompactHeight ? 10.0 : 12.0;
        final monthTitleStyle = Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700);
        final weekdayStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );
        final availableGridWidth = constraints.maxWidth - (cardPadding * 2);
        final dayWidth = (availableGridWidth - (gridSpacing * 6)) / 7;
        final calendarHeightBudget =
            (selectedEntries.isEmpty
                    ? constraints.maxHeight * 0.66
                    : constraints.maxHeight * 0.5)
                .clamp(220.0, 340.0)
                .toDouble();
        final headerHeight = isCompactHeight ? 40.0 : 48.0;
        final weekdayHeight = isCompactHeight ? 18.0 : 20.0;
        final chromeHeight =
            (cardPadding * 2) +
            headerHeight +
            weekdayHeight +
            monthHeaderSpacing +
            monthHeaderSpacing;
        final dayHeightFromBudget =
            ((calendarHeightBudget -
                        chromeHeight -
                        (gridSpacing * (weekCount - 1))) /
                    weekCount)
                .clamp(28.0, 44.0)
                .toDouble();
        final dayExtent = dayWidth < dayHeightFromBudget
            ? dayWidth
            : dayHeightFromBudget;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(cardPadding),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Previous month',
                          onPressed: () => _changeDisplayedMonth(-1),
                          icon: const Icon(Icons.chevron_left),
                          visualDensity: isCompactHeight
                              ? VisualDensity.compact
                              : null,
                        ),
                        Expanded(
                          child: Text(
                            localizations.formatMonthYear(displayedMonth),
                            textAlign: TextAlign.center,
                            style: monthTitleStyle,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Next month',
                          onPressed: () => _changeDisplayedMonth(1),
                          icon: const Icon(Icons.chevron_right),
                          visualDensity: isCompactHeight
                              ? VisualDensity.compact
                              : null,
                        ),
                      ],
                    ),
                    SizedBox(height: monthHeaderSpacing),
                    Row(
                      children: [
                        for (final label in weekdayLabels)
                          Expanded(
                            child: Center(
                              child: Text(label, style: weekdayStyle),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: monthHeaderSpacing),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: totalCells,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        mainAxisSpacing: gridSpacing,
                        crossAxisSpacing: gridSpacing,
                        mainAxisExtent: dayExtent,
                      ),
                      itemBuilder: (context, index) {
                        if (index < leadingEmptyCells ||
                            index >= leadingEmptyCells + daysInMonth) {
                          return const SizedBox.shrink();
                        }

                        final day = index - leadingEmptyCells + 1;
                        final date = DateTime(
                          displayedMonth.year,
                          displayedMonth.month,
                          day,
                        );
                        final normalizedDate = DateUtils.dateOnly(date);
                        final isSelected = _isSameDate(
                          normalizedDate,
                          _selectedCalendarDate,
                        );
                        final hasTasks = taskDateKeys.contains(_dateKey(date));
                        final colorScheme = Theme.of(context).colorScheme;
                        final backgroundColor = isSelected
                            ? hasTasks
                                  ? colorScheme.error
                                  : colorScheme.primary
                            : hasTasks
                            ? colorScheme.errorContainer.withValues(alpha: 0.85)
                            : colorScheme.surfaceContainerLowest;
                        final foregroundColor = isSelected
                            ? (hasTasks
                                  ? colorScheme.onError
                                  : colorScheme.onPrimary)
                            : hasTasks
                            ? colorScheme.error
                            : colorScheme.onSurface;

                        return Material(
                          color: backgroundColor,
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () {
                              setState(() {
                                _selectedCalendarDate = normalizedDate;
                                _displayedMonth = DateTime(
                                  normalizedDate.year,
                                  normalizedDate.month,
                                );
                              });
                            },
                            child: Center(
                              child: Text(
                                '$day',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: foregroundColor,
                                      fontWeight: hasTasks || isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: dateHeaderSpacing),
            Text(
              dateLabel,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: selectedEntries.isEmpty
                  ? _buildEmptyState(
                      icon: Icons.event_available,
                      text: 'No tasks match this day and filter set.',
                    )
                  : _buildTodoList(selectedEntries),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTodoList(List<_TodoEntry> entries) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 2),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return _buildTodoCard(todoId: entry.id, todo: entry.todo);
      },
    );
  }

  Widget _buildTodoCard({
    required String todoId,
    required Todo todo,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isOverdue = todo.isOverdue();
    final primaryMeta = <String>[
      if (todo.category.trim().isNotEmpty) todo.category.trim(),
      _shortPriorityLabel(todo.priority),
      if (todo.dueAt != null)
        isOverdue
            ? 'Overdue ${_formatShortDate(todo.dueAt!)}'
            : 'Due ${_formatShortDate(todo.dueAt!)}',
      if (todo.repeatFrequency != TodoRepeatFrequency.none)
        _shortRepeatLabel(todo.repeatFrequency),
    ];
    final secondaryMeta = <String>[
      if (todo.location.trim().isNotEmpty) todo.location.trim(),
      if (todo.subTodos.isNotEmpty)
        '${todo.completedSubTodoCount}/${todo.subTodos.length} subtasks',
      if (todo.attachments.isNotEmpty)
        '${todo.attachments.length} attachment${todo.attachments.length == 1 ? '' : 's'}',
      if (todo.isCompleted && todo.completedAt != null)
        'Completed ${_formatShortDate(todo.completedAt!)}',
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        color: isOverdue
            ? colorScheme.errorContainer.withValues(alpha: 0.4)
            : null,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 10,
          ),
          leading: Checkbox(
            value: todo.isCompleted,
            onChanged: (value) => _toggleTodoCompletion(todoId, todo, value),
          ),
          title: Text(
            todo.text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              decoration: todo.isCompleted ? TextDecoration.lineThrough : null,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (todo.description.trim().isNotEmpty)
                  Text(
                    todo.description.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                if (primaryMeta.isNotEmpty) ...[
                  if (todo.description.trim().isNotEmpty)
                    const SizedBox(height: 4),
                  Text(
                    primaryMeta.join(' • '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isOverdue
                          ? colorScheme.error
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (secondaryMeta.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    secondaryMeta.join(' • '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (todo.subTodos.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: todo.subTodoProgress,
                      minHeight: 6,
                    ),
                  ),
                ],
              ],
            ),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => TodoDetailScreen(todoId: todoId),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAddTodoBar(String? userId) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final input = TextField(
          controller: _controller,
          onSubmitted: (_) => _addTodo(userId),
          decoration: const InputDecoration(
            hintText: 'Add your todo',
            prefixIcon: Icon(Icons.add_task),
          ),
        );
        final priorityField = DropdownButtonFormField<TodoPriority>(
          initialValue: _newTodoPriority,
          decoration: const InputDecoration(
            labelText: 'Priority',
          ),
          items: TodoPriority.values
              .map(
                (priority) => DropdownMenuItem<TodoPriority>(
                  value: priority,
                  child: Text(_priorityLabel(priority)),
                ),
              )
              .toList(growable: false),
          onChanged: (value) {
            if (value == null) {
              return;
            }
            setState(() {
              _newTodoPriority = value;
            });
          },
        );
        final button = FilledButton.icon(
          onPressed: () => _addTodo(userId),
          icon: const Icon(Icons.send),
          label: const Text('Add'),
        );

        if (constraints.maxWidth < 640) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              input,
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: priorityField),
                  const SizedBox(width: 12),
                  button,
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: input),
            const SizedBox(width: 12),
            SizedBox(width: 170, child: priorityField),
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
          Icon(icon, size: 40, color: colorScheme.secondary),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  List<_TodoEntry> _filteredEntries(List<_TodoEntry> entries) {
    final filtered = entries.where((entry) {
      final todo = entry.todo;
      final queryTargets = [
        todo.text,
        todo.description,
        todo.category,
        todo.location,
        ...todo.subCategories,
      ].join(' ').toLowerCase();
      final matchesSearch =
          _searchQuery.isEmpty || queryTargets.contains(_searchQuery);
      final matchesStatus = switch (_statusFilter) {
        _TodoStatusFilter.all => true,
        _TodoStatusFilter.open => !todo.isCompleted,
        _TodoStatusFilter.completed => todo.isCompleted,
        _TodoStatusFilter.overdue => todo.isOverdue(),
      };
      final matchesPriority =
          _priorityFilter == null || todo.priority == _priorityFilter;

      return matchesSearch && matchesStatus && matchesPriority;
    }).toList();

    filtered.sort(_compareEntries);
    return filtered;
  }

  int _compareEntries(_TodoEntry a, _TodoEntry b) {
    return switch (_sort) {
      _TodoSort.newest => b.todo.createdAt.compareTo(a.todo.createdAt),
      _TodoSort.oldest => a.todo.createdAt.compareTo(b.todo.createdAt),
      _TodoSort.dueSoon => _compareDueDates(a.todo, b.todo),
      _TodoSort.priority => _comparePriorities(a.todo, b.todo),
    };
  }

  int _compareDueDates(Todo a, Todo b) {
    final aDueAt = a.dueAt;
    final bDueAt = b.dueAt;

    if (aDueAt == null && bDueAt == null) {
      return b.createdAt.compareTo(a.createdAt);
    }
    if (aDueAt == null) {
      return 1;
    }
    if (bDueAt == null) {
      return -1;
    }

    final dueComparison = aDueAt.compareTo(bDueAt);
    if (dueComparison != 0) {
      return dueComparison;
    }

    return b.createdAt.compareTo(a.createdAt);
  }

  int _comparePriorities(Todo a, Todo b) {
    final rankComparison = _priorityRank(a.priority).compareTo(
      _priorityRank(b.priority),
    );
    if (rankComparison != 0) {
      return rankComparison;
    }

    return b.createdAt.compareTo(a.createdAt);
  }

  int _priorityRank(TodoPriority priority) {
    return switch (priority) {
      TodoPriority.high => 0,
      TodoPriority.medium => 1,
      TodoPriority.low => 2,
    };
  }

  String _emptyStateMessage(bool hasAnyTodos) {
    if (!hasAnyTodos) {
      return 'No todos yet.';
    }
    if (_view == _HomeView.calendar) {
      return 'No tasks match this day and filter set.';
    }
    if (_statusFilter == _TodoStatusFilter.completed) {
      return 'No completed todos yet.';
    }
    if (_statusFilter == _TodoStatusFilter.overdue) {
      return 'No overdue todos.';
    }
    if (_statusFilter == _TodoStatusFilter.open) {
      return 'No open todos.';
    }
    if (_searchQuery.isNotEmpty || _priorityFilter != null) {
      return 'No todos match your current filters.';
    }
    return 'No todos to show.';
  }

  String _formatShortDate(DateTime dateTime) {
    return MaterialLocalizations.of(
      context,
    ).formatShortDate(dateTime.toLocal());
  }

  void _changeDisplayedMonth(int monthDelta) {
    final nextMonth = DateTime(
      _displayedMonth.year,
      _displayedMonth.month + monthDelta,
    );
    final maxDay = DateUtils.getDaysInMonth(nextMonth.year, nextMonth.month);
    final selectedDay = _selectedCalendarDate.day <= maxDay
        ? _selectedCalendarDate.day
        : maxDay;

    setState(() {
      _displayedMonth = DateTime(nextMonth.year, nextMonth.month);
      _selectedCalendarDate = DateTime(
        nextMonth.year,
        nextMonth.month,
        selectedDay,
      );
    });
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  int _dateKey(DateTime dateTime) {
    final date = DateUtils.dateOnly(dateTime.toLocal());
    return date.year * 10000 + date.month * 100 + date.day;
  }

  Future<void> _toggleTodoCompletion(
    String todoId,
    Todo todo,
    bool? value,
  ) async {
    if (value == null) {
      return;
    }

    try {
      await TodoService.instance.toggleCompletion(
        todoId: todoId,
        todo: todo,
        isCompleted: value,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update todo completion: $error')),
      );
    }
  }

  Future<void> _addTodo(String? userId) async {
    final text = _controller.text.trim();
    if (userId == null || text.isEmpty) {
      return;
    }

    final todo = Todo(
      text: text,
      userId: userId,
      createdAt: DateTime.now(),
      priority: _newTodoPriority,
    );

    await _todosRef.add(todo);
    _controller.clear();
  }

  String _priorityLabel(TodoPriority priority) {
    return switch (priority) {
      TodoPriority.high => 'High priority',
      TodoPriority.medium => 'Medium priority',
      TodoPriority.low => 'Low priority',
    };
  }

  String _shortPriorityLabel(TodoPriority priority) {
    return switch (priority) {
      TodoPriority.high => 'High priority',
      TodoPriority.medium => 'Medium priority',
      TodoPriority.low => 'Low priority',
    };
  }

  String _shortRepeatLabel(TodoRepeatFrequency repeatFrequency) {
    return switch (repeatFrequency) {
      TodoRepeatFrequency.none => 'No repeat',
      TodoRepeatFrequency.daily => 'Repeats daily',
      TodoRepeatFrequency.weekly => 'Repeats weekly',
      TodoRepeatFrequency.monthly => 'Repeats monthly',
    };
  }

  String _sortLabel(_TodoSort sort) {
    return switch (sort) {
      _TodoSort.newest => 'Newest first',
      _TodoSort.oldest => 'Oldest first',
      _TodoSort.dueSoon => 'Due soon',
      _TodoSort.priority => 'Priority',
    };
  }

  String _statusLabel(_TodoStatusFilter status) {
    return switch (status) {
      _TodoStatusFilter.all => 'All',
      _TodoStatusFilter.open => 'Open',
      _TodoStatusFilter.completed => 'Completed',
      _TodoStatusFilter.overdue => 'Overdue',
    };
  }
}

class _TodoEntry {
  const _TodoEntry({
    required this.id,
    required this.todo,
  });

  final String id;
  final Todo todo;
}
