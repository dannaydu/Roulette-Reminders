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

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final userEmail = FirebaseAuth.instance.currentUser?.email;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('TODO Spring 2026'),
            if (userEmail != null && userEmail.isNotEmpty)
              Text(
                userEmail,
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
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
          maxWidth: 980,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (userId == null)
                Expanded(
                  child: _buildEmptyState(
                    icon: Icons.lock_outline,
                    text: 'Sign in to view your todos.',
                  ),
                )
              else
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Todo>>(
                    stream: _todosRef
                        .where('userId', isEqualTo: userId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Could not load todos: ${snapshot.error}',
                          ),
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
                          .toList();
                      final filteredEntries = _filteredEntries(entries);
                      final calendarEntries = filteredEntries
                          .where(
                            (entry) =>
                                entry.todo.occursOnDate(_selectedCalendarDate),
                          )
                          .toList(growable: false);
                      final displayedEntries = _view == _HomeView.calendar
                          ? calendarEntries
                          : filteredEntries;
                      final overview = _overviewService.generate(
                        todos: entries.map((entry) => entry.todo).toList(),
                        now: DateTime.now(),
                      );

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildSummaryRow(entries),
                          const SizedBox(height: 12),
                          _buildDailyOverview(overview),
                          const SizedBox(height: 12),
                          _buildProgressSection(displayedEntries),
                          const SizedBox(height: 12),
                          _buildSearchField(),
                          const SizedBox(height: 12),
                          _buildToolbar(),
                          const SizedBox(height: 12),
                          Expanded(
                            child: _view == _HomeView.calendar
                                ? _buildCalendarView(filteredEntries)
                                : filteredEntries.isEmpty
                                ? _buildEmptyState(
                                    icon:
                                        _statusFilter ==
                                            _TodoStatusFilter.completed
                                        ? Icons.task_alt
                                        : Icons.check_circle_outline,
                                    text: _emptyStateMessage(entries.isEmpty),
                                  )
                                : _buildTodoList(filteredEntries),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              const SizedBox(height: 12),
              _buildAddTodoBar(userId),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(List<_TodoEntry> entries) {
    final activeCount = entries
        .where((entry) => !entry.todo.isCompleted)
        .length;
    final completedCount = entries
        .where((entry) => entry.todo.isCompleted)
        .length;
    final overdueCount = entries
        .where((entry) => entry.todo.isOverdue())
        .length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 620;
        final children = [
          _buildSummaryCard(
            label: 'Open',
            value: '$activeCount',
            icon: Icons.pending_actions,
          ),
          _buildSummaryCard(
            label: 'Completed',
            value: '$completedCount',
            icon: Icons.task_alt,
          ),
          _buildSummaryCard(
            label: 'Overdue',
            value: '$overdueCount',
            icon: Icons.warning_amber_rounded,
            emphasized: overdueCount > 0,
          ),
        ];

        if (isNarrow) {
          return Column(
            children: [
              for (final child in children) ...[
                child,
                if (child != children.last) const SizedBox(height: 10),
              ],
            ],
          );
        }

        return Row(
          children: [
            for (var index = 0; index < children.length; index++) ...[
              Expanded(child: children[index]),
              if (index != children.length - 1) const SizedBox(width: 10),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSummaryCard({
    required String label,
    required String value,
    required IconData icon,
    bool emphasized = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = emphasized
        ? colorScheme.errorContainer
        : colorScheme.surfaceContainerLowest;
    final foregroundColor = emphasized
        ? colorScheme.onErrorContainer
        : colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(
          color: emphasized
              ? colorScheme.error.withValues(alpha: 0.35)
              : colorScheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: foregroundColor),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: foregroundColor,
                ),
              ),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: foregroundColor.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDailyOverview(DailyOverview overview) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer,
            colorScheme.secondaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: colorScheme.onPrimaryContainer),
              const SizedBox(width: 8),
              Text(
                'Daily overview',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            overview.headline,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            overview.summary,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onPrimaryContainer.withValues(alpha: 0.9),
            ),
          ),
          if (overview.focusPoints.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final point in overview.focusPoints) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.chevron_right,
                    color: colorScheme.onPrimaryContainer,
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      point,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onPrimaryContainer.withValues(
                          alpha: 0.9,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (point != overview.focusPoints.last) const SizedBox(height: 6),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildProgressSection(List<_TodoEntry> entries) {
    final totalCount = entries.length;
    final completedCount = entries
        .where((entry) => entry.todo.isCompleted)
        .length;
    final progress = totalCount == 0 ? 0.0 : completedCount / totalCount;
    final label = _view == _HomeView.calendar
        ? 'Selected day progress'
        : '${_statusLabel(_statusFilter)} progress';

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
          Row(
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                totalCount == 0 ? '0%' : '${(progress * 100).round()}%',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            totalCount == 0
                ? 'No tasks in the current view.'
                : '$completedCount of $totalCount tasks completed.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final priorityFilter = DropdownButtonFormField<TodoPriority?>(
          initialValue: _priorityFilter,
          decoration: const InputDecoration(
            labelText: 'Priority filter',
          ),
          items: const [
            DropdownMenuItem<TodoPriority?>(
              value: null,
              child: Text('All priorities'),
            ),
            DropdownMenuItem<TodoPriority?>(
              value: TodoPriority.high,
              child: Text('High priority'),
            ),
            DropdownMenuItem<TodoPriority?>(
              value: TodoPriority.medium,
              child: Text('Medium priority'),
            ),
            DropdownMenuItem<TodoPriority?>(
              value: TodoPriority.low,
              child: Text('Low priority'),
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
              .toList(),
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
            SizedBox(width: 220, child: priorityFilter),
            const SizedBox(width: 12),
            viewToggle,
          ],
        );
      },
    );
  }

  Widget _buildCalendarView(List<_TodoEntry> filteredEntries) {
    final calendarEntries = filteredEntries
        .where((entry) => entry.todo.occursOnDate(_selectedCalendarDate))
        .toList(growable: false);
    final colorScheme = Theme.of(context).colorScheme;
    final localizations = MaterialLocalizations.of(context);
    final dateLabel = localizations.formatFullDate(_selectedCalendarDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: CalendarDatePicker(
            initialDate: _selectedCalendarDate,
            firstDate: DateTime(DateTime.now().year - 2, 1, 1),
            lastDate: DateTime(DateTime.now().year + 5, 12, 31),
            currentDate: DateTime.now(),
            onDateChanged: (date) {
              setState(() {
                _selectedCalendarDate = DateUtils.dateOnly(date);
              });
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text(
              dateLabel,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              '${calendarEntries.length} task${calendarEntries.length == 1 ? '' : 's'}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: calendarEntries.isEmpty
              ? _buildEmptyState(
                  icon: Icons.event_available,
                  text: 'No tasks match this day and filter set.',
                )
              : _buildTodoList(calendarEntries),
        ),
      ],
    );
  }

  Widget _buildTodoList(List<_TodoEntry> entries) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];

        return _buildTodoCard(
          todoId: entry.id,
          todo: entry.todo,
        );
      },
    );
  }

  Widget _buildTodoCard({
    required String todoId,
    required Todo todo,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isOverdue = todo.isOverdue();
    final priorityColor = _priorityColor(todo.priority);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        color: isOverdue
            ? colorScheme.errorContainer.withValues(alpha: 0.65)
            : todo.isCompleted
            ? colorScheme.surfaceContainerLow
            : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: isOverdue ? colorScheme.error : colorScheme.outlineVariant,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => TodoDetailScreen(todoId: todoId),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: todo.isCompleted,
                  onChanged: (value) =>
                      _toggleTodoCompletion(todoId, todo, value),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              todo.text,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                decoration: todo.isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.chevron_right,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                      if (todo.description.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          todo.description.trim(),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildPriorityBadge(todo.priority, priorityColor),
                          if (todo.category.trim().isNotEmpty)
                            _buildTagBadge(
                              Icons.folder_outlined,
                              todo.category.trim(),
                            ),
                          for (final subCategory in todo.subCategories.take(3))
                            _buildTagBadge(
                              Icons.subdirectory_arrow_right,
                              subCategory,
                            ),
                          if (todo.repeatFrequency != TodoRepeatFrequency.none)
                            _buildTagBadge(
                              Icons.repeat,
                              _repeatLabel(todo.repeatFrequency),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _buildMetaLabel(
                            icon: Icons.access_time,
                            text: 'Created ${_formatDateTime(todo.createdAt)}',
                          ),
                          if (todo.dueAt != null)
                            _buildMetaLabel(
                              icon: isOverdue
                                  ? Icons.warning_amber_rounded
                                  : Icons.event_outlined,
                              text: isOverdue
                                  ? 'Overdue since ${_formatDateTime(todo.dueAt!)}'
                                  : 'Due ${_formatDateTime(todo.dueAt!)}',
                              color: isOverdue
                                  ? colorScheme.error
                                  : priorityColor,
                            ),
                          if (todo.location.trim().isNotEmpty)
                            _buildMetaLabel(
                              icon: Icons.location_on_outlined,
                              text: todo.location.trim(),
                            ),
                          if (todo.subTodos.isNotEmpty)
                            _buildMetaLabel(
                              icon: Icons.playlist_add_check_circle_outlined,
                              text:
                                  '${todo.completedSubTodoCount}/${todo.subTodos.length} subtasks',
                            ),
                          if (todo.attachments.isNotEmpty)
                            _buildMetaLabel(
                              icon: Icons.attach_file,
                              text:
                                  '${todo.attachments.length} attachment${todo.attachments.length == 1 ? '' : 's'}',
                            ),
                          if (todo.isCompleted && todo.completedAt != null)
                            _buildMetaLabel(
                              icon: Icons.task_alt,
                              text:
                                  'Completed ${_formatDateTime(todo.completedAt!)}',
                              color: colorScheme.primary,
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
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityBadge(TodoPriority priority, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _priorityLabel(priority),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildTagBadge(IconData icon, String text) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            text,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
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
              .toList(),
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
          label: const Text('Add todo'),
        );

        if (constraints.maxWidth < 680) {
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: input),
            const SizedBox(width: 12),
            SizedBox(width: 180, child: priorityField),
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

  String _formatDateTime(DateTime dateTime) {
    final localDateTime = dateTime.toLocal();
    final localizations = MaterialLocalizations.of(context);
    final date = localizations.formatMediumDate(localDateTime);
    final time = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(localDateTime),
    );
    return '$date at $time';
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
        SnackBar(
          content: Text('Could not update todo completion: $error'),
        ),
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

  String _repeatLabel(TodoRepeatFrequency repeatFrequency) {
    return switch (repeatFrequency) {
      TodoRepeatFrequency.none => 'No repeat',
      TodoRepeatFrequency.daily => 'Repeats daily',
      TodoRepeatFrequency.weekly => 'Repeats weekly',
      TodoRepeatFrequency.monthly => 'Repeats monthly',
    };
  }

  Color _priorityColor(TodoPriority priority) {
    final colorScheme = Theme.of(context).colorScheme;
    return switch (priority) {
      TodoPriority.high => colorScheme.error,
      TodoPriority.medium => colorScheme.secondary,
      TodoPriority.low => colorScheme.primary,
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
