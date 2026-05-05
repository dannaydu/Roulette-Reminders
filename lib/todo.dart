import 'package:cloud_firestore/cloud_firestore.dart';

enum TodoPriority {
  high,
  medium,
  low
  ;

  static TodoPriority fromFirestoreValue(Object? value) {
    return switch (value) {
      'high' => TodoPriority.high,
      'low' => TodoPriority.low,
      _ => TodoPriority.medium,
    };
  }
}

enum TodoRepeatFrequency {
  none,
  daily,
  weekly,
  monthly
  ;

  static TodoRepeatFrequency fromFirestoreValue(Object? value) {
    return switch (value) {
      'daily' => TodoRepeatFrequency.daily,
      'weekly' => TodoRepeatFrequency.weekly,
      'monthly' => TodoRepeatFrequency.monthly,
      _ => TodoRepeatFrequency.none,
    };
  }
}

class TodoSubTask {
  const TodoSubTask({
    required this.id,
    required this.text,
    this.isCompleted = false,
  });

  final String id;
  final String text;
  final bool isCompleted;

  factory TodoSubTask.fromMap(Map<String, dynamic> map) {
    return TodoSubTask(
      id: map['id'] as String? ?? '',
      text: map['text'] as String? ?? '',
      isCompleted: map['isCompleted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'isCompleted': isCompleted,
    };
  }

  TodoSubTask copyWith({
    String? id,
    String? text,
    bool? isCompleted,
  }) {
    return TodoSubTask(
      id: id ?? this.id,
      text: text ?? this.text,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

class TodoAttachment {
  const TodoAttachment({
    required this.name,
    required this.url,
    required this.storagePath,
    required this.createdAt,
    this.contentType,
    this.sizeBytes = 0,
  });

  final String name;
  final String url;
  final String storagePath;
  final DateTime createdAt;
  final String? contentType;
  final int sizeBytes;

  factory TodoAttachment.fromMap(Map<String, dynamic> map) {
    final createdAt = map['createdAt'];

    return TodoAttachment(
      name: map['name'] as String? ?? 'Attachment',
      url: map['url'] as String? ?? '',
      storagePath: map['storagePath'] as String? ?? '',
      createdAt: createdAt is Timestamp ? createdAt.toDate() : DateTime.now(),
      contentType: map['contentType'] as String?,
      sizeBytes: map['sizeBytes'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'url': url,
      'storagePath': storagePath,
      'createdAt': Timestamp.fromDate(createdAt),
      'contentType': contentType,
      'sizeBytes': sizeBytes,
    };
  }

  bool get isImage {
    if (contentType != null && contentType!.startsWith('image/')) {
      return true;
    }

    final normalized = name.toLowerCase();
    return normalized.endsWith('.png') ||
        normalized.endsWith('.jpg') ||
        normalized.endsWith('.jpeg') ||
        normalized.endsWith('.gif') ||
        normalized.endsWith('.webp');
  }
}

class Todo {
  const Todo({
    required this.text,
    required this.userId,
    required this.createdAt,
    this.description = '',
    this.category = '',
    this.subCategories = const [],
    this.subTodos = const [],
    this.attachments = const [],
    this.location = '',
    this.completedAt,
    this.dueAt,
    this.priority = TodoPriority.medium,
    this.repeatFrequency = TodoRepeatFrequency.none,
    this.spawnedNextOccurrenceAt,
  });

  final String text;
  final String description;
  final String category;
  final List<String> subCategories;
  final List<TodoSubTask> subTodos;
  final List<TodoAttachment> attachments;
  final String location;
  final String userId;
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime? dueAt;
  final TodoPriority priority;
  final TodoRepeatFrequency repeatFrequency;
  final DateTime? spawnedNextOccurrenceAt;

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
    final spawnedNextOccurrenceAt = data['spawnedNextOccurrenceAt'];

    return Todo(
      text: data['text'] as String? ?? '',
      description: data['description'] as String? ?? '',
      category: data['category'] as String? ?? '',
      subCategories: _stringList(data['subCategories']),
      subTodos: _subTasks(data['subTodos']),
      attachments: _attachments(data['attachments']),
      location: data['location'] as String? ?? '',
      userId: data['userId'] as String? ?? '',
      createdAt: createdAt.toDate(),
      completedAt: completedAt is Timestamp ? completedAt.toDate() : null,
      dueAt: dueAt is Timestamp ? dueAt.toDate() : null,
      priority: TodoPriority.fromFirestoreValue(data['priority']),
      repeatFrequency: TodoRepeatFrequency.fromFirestoreValue(
        data['repeatFrequency'],
      ),
      spawnedNextOccurrenceAt: spawnedNextOccurrenceAt is Timestamp
          ? spawnedNextOccurrenceAt.toDate()
          : null,
    );
  }

  Map<String, dynamic> toSnapshot() {
    return {
      'text': text,
      'description': description,
      'category': category,
      'subCategories': subCategories,
      'subTodos': subTodos.map((subTodo) => subTodo.toMap()).toList(),
      'attachments': attachments
          .map((attachment) => attachment.toMap())
          .toList(),
      'location': location,
      'userId': userId,
      'createdAt': Timestamp.fromDate(createdAt),
      'completedAt': completedAt == null
          ? null
          : Timestamp.fromDate(completedAt!),
      'dueAt': dueAt == null ? null : Timestamp.fromDate(dueAt!),
      'priority': priority.name,
      'repeatFrequency': repeatFrequency.name,
      'spawnedNextOccurrenceAt': spawnedNextOccurrenceAt == null
          ? null
          : Timestamp.fromDate(spawnedNextOccurrenceAt!),
    };
  }

  Todo copyWith({
    String? text,
    String? description,
    String? category,
    List<String>? subCategories,
    List<TodoSubTask>? subTodos,
    List<TodoAttachment>? attachments,
    String? location,
    String? userId,
    DateTime? createdAt,
    Object? completedAt = _sentinel,
    Object? dueAt = _sentinel,
    TodoPriority? priority,
    TodoRepeatFrequency? repeatFrequency,
    Object? spawnedNextOccurrenceAt = _sentinel,
  }) {
    return Todo(
      text: text ?? this.text,
      description: description ?? this.description,
      category: category ?? this.category,
      subCategories: subCategories ?? this.subCategories,
      subTodos: subTodos ?? this.subTodos,
      attachments: attachments ?? this.attachments,
      location: location ?? this.location,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt == _sentinel
          ? this.completedAt
          : completedAt as DateTime?,
      dueAt: dueAt == _sentinel ? this.dueAt : dueAt as DateTime?,
      priority: priority ?? this.priority,
      repeatFrequency: repeatFrequency ?? this.repeatFrequency,
      spawnedNextOccurrenceAt: spawnedNextOccurrenceAt == _sentinel
          ? this.spawnedNextOccurrenceAt
          : spawnedNextOccurrenceAt as DateTime?,
    );
  }

  bool get isCompleted => completedAt != null;

  bool isOverdue([DateTime? now]) {
    if (isCompleted || dueAt == null) {
      return false;
    }

    return dueAt!.isBefore(now ?? DateTime.now());
  }

  int get completedSubTodoCount {
    return subTodos.where((subTodo) => subTodo.isCompleted).length;
  }

  double get subTodoProgress {
    if (subTodos.isEmpty) {
      return isCompleted ? 1 : 0;
    }

    return completedSubTodoCount / subTodos.length;
  }

  DateTime get calendarAnchor => dueAt ?? createdAt;

  bool occursOnDate(DateTime date) {
    final anchor = calendarAnchor.toLocal();
    final localDate = date.toLocal();
    return anchor.year == localDate.year &&
        anchor.month == localDate.month &&
        anchor.day == localDate.day;
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) {
      return const [];
    }

    return value.whereType<String>().toList(growable: false);
  }

  static List<TodoSubTask> _subTasks(Object? value) {
    if (value is! List) {
      return const [];
    }

    return value
        .whereType<Map>()
        .map(
          (entry) => TodoSubTask.fromMap(
            entry.map(
              (key, value) => MapEntry('$key', value),
            ),
          ),
        )
        .toList(growable: false);
  }

  static List<TodoAttachment> _attachments(Object? value) {
    if (value is! List) {
      return const [];
    }

    return value
        .whereType<Map>()
        .map(
          (entry) => TodoAttachment.fromMap(
            entry.map(
              (key, value) => MapEntry('$key', value),
            ),
          ),
        )
        .toList(growable: false);
  }
}

const _sentinel = Object();
