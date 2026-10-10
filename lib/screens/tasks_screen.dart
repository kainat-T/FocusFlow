import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task_model.dart';
import '../services/auth_service.dart';
import '../services/task_service.dart';

// ── Colour constants (mirrors _C in home_screen) ───────────────────────────
class _C {
  static const bg      = Color(0xFF000000);
  static const surface = Color(0xFF1A1A1A);
  static const text    = Color(0xFFFFFFFF);
  static const subText = Color(0xFFAAAAAA);
  static const accent  = Color(0xFFD4A24C);
  static const divider = Color(0xFF2A2A2A);
}

// ── Priority helpers ───────────────────────────────────────────────────────
extension _PriorityX on TaskPriority {
  String get label => name[0].toUpperCase() + name.substring(1);

  Color get color {
    switch (this) {
      case TaskPriority.high:   return const Color(0xFFE05C5C);
      case TaskPriority.medium: return const Color(0xFFD4A24C);
      case TaskPriority.low:    return const Color(0xFF74957C);
    }
  }

  IconData get icon {
    switch (this) {
      case TaskPriority.high:   return Icons.keyboard_double_arrow_up_rounded;
      case TaskPriority.medium: return Icons.drag_handle_rounded;
      case TaskPriority.low:    return Icons.keyboard_double_arrow_down_rounded;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TasksScreen
// ═══════════════════════════════════════════════════════════════════════════
class TasksScreen extends StatefulWidget {
  final String uid;
  final List<String> initialSubjects;
  const TasksScreen({super.key, required this.uid, this.initialSubjects = const []});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _service = TaskService();

  // filter state
  String? _filterSubject;   // null = all subjects
  late TabController _tabCtrl; // All | Pending | Done tabs

  // saved subjects list (loaded from SharedPreferences)
  List<String> _subjects = [];

  String get _kSubjectsKey =>
      'subjects_list_${AuthService().currentUser?.uid ?? 'guest'}';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _loadSubjects();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // reload subjects when app comes back to foreground
    if (state == AppLifecycleState.resumed) {
      _loadSubjects();
    }
  }

  // Also reload when the widget is built (e.g. tab switch)
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final saved = prefs.getStringList(_kSubjectsKey) ?? [];
    // merge prefs list with whatever home_screen already passed in
    final merged = {...widget.initialSubjects, ...saved}.toList();
    // write merged back so both screens stay in sync
    if (merged.length != saved.length) {
      await prefs.setStringList(_kSubjectsKey, merged);
    }
    if (!mounted) return;
    setState(() => _subjects = merged);
  }

  // ── Filter tasks ───────────────────────────────────────────────────────────
  List<TaskModel> _applyFilters(List<TaskModel> all, int tabIndex) {
    var list = all;
    if (_filterSubject != null) {
      list = list.where((t) => t.subject == _filterSubject).toList();
    }
    switch (tabIndex) {
      case 1: return list.where((t) => !t.isDone).toList();
      case 2: return list.where((t) => t.isDone).toList();
      default: return list;
    }
  }

  // ── Show add / edit bottom sheet ───────────────────────────────────────────
  void _openTaskSheet({TaskModel? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TaskSheet(
        uid: widget.uid,
        subjects: List<String>.from(_subjects),
        existing: existing,
        onSubjectAdded: (newSubject) async {
          // persist to SharedPreferences so HomeScreen picks it up
          final prefs = await SharedPreferences.getInstance();
          final updated = List<String>.from(_subjects);
          if (!updated.contains(newSubject)) {
            updated.add(newSubject);
            await prefs.setStringList(_kSubjectsKey, updated);
            if (mounted) setState(() => _subjects = updated);
          }
        },
        onSave: (title, desc, subject, priority, dueDate) async {
          if (existing == null) {
            await _service.addTask(
              uid: widget.uid,
              title: title,
              description: desc,
              subject: subject,
              priority: priority,
              dueDate: dueDate,
            );
          } else {
            await _service.updateTask(
              widget.uid,
              existing.copyWith(
                title: title,
                description: desc.isEmpty ? null : desc,
                clearDescription: desc.isEmpty,
                subject: subject,
                clearSubject: subject == null,
                priority: priority,
                dueDate: dueDate,
                clearDueDate: dueDate == null,
              ),
            );
          }
        },
      ),
    );
  }

  // ── Delete with confirmation ───────────────────────────────────────────────
  Future<void> _deleteTask(TaskModel task) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _C.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Task',
            style: TextStyle(color: _C.text, fontWeight: FontWeight.bold)),
        content: Text(
          '"${task.title}" will be permanently deleted.',
          style: const TextStyle(color: _C.subText, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: _C.subText)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _service.deleteTask(widget.uid, task.id);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      // header row with subject filter + tab bar
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top bar ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                const Text(
                  'Tasks',
                  style: TextStyle(
                    color: _C.text,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                // Subject filter chip
                if (_subjects.isNotEmpty)
                  GestureDetector(
                    onTap: _showSubjectFilter,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: _filterSubject != null
                            ? _C.accent.withValues(alpha: 0.15)
                            : const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _filterSubject != null
                              ? _C.accent.withValues(alpha: 0.6)
                              : _C.divider,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.filter_list_rounded,
                              size: 13,
                              color: _filterSubject != null
                                  ? _C.accent
                                  : _C.subText),
                          const SizedBox(width: 6),
                          Text(
                            _filterSubject ?? 'All subjects',
                            style: TextStyle(
                              color: _filterSubject != null
                                  ? _C.accent
                                  : _C.subText,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (_filterSubject != null) ...[
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () =>
                                  setState(() => _filterSubject = null),
                              child: const Icon(Icons.close,
                                  size: 12, color: _C.accent),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Tab bar ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: TabBar(
              controller: _tabCtrl,
              onTap: (_) => setState(() {}),
              labelColor: _C.accent,
              unselectedLabelColor: _C.subText,
              labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontSize: 13),
              indicator: UnderlineTabIndicator(
                borderSide: const BorderSide(color: _C.accent, width: 2),
                borderRadius: BorderRadius.circular(2),
              ),
              dividerColor: _C.divider,
              tabs: const [
                Tab(text: 'All'),
                Tab(text: 'Pending'),
                Tab(text: 'Done'),
              ],
            ),
          ),

          // ── Task list ─────────────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<List<TaskModel>>(
              stream: _service.tasksStream(widget.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                        color: _C.accent, strokeWidth: 2),
                  );
                }

                final all = snapshot.data ?? [];
                final filtered =
                    _applyFilters(all, _tabCtrl.index);

                if (all.isEmpty) return _buildEmpty();
                if (filtered.isEmpty) return _buildEmptyFilter();

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) => _TaskCard(
                    task: filtered[i],
                    onToggle: () =>
                        _service.toggleDone(widget.uid, filtered[i]),
                    onEdit: () => _openTaskSheet(existing: filtered[i]),
                    onDelete: () => _deleteTask(filtered[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),

      // ── FAB ───────────────────────────────────────────────────────────────
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openTaskSheet(),
        backgroundColor: _C.accent,
        foregroundColor: Colors.black,
        elevation: 2,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  // ── Subject filter popup ───────────────────────────────────────────────────
  void _showSubjectFilter() async {
    final result = await showModalBottomSheet<String?>(
      context: context,
      backgroundColor: _C.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Filter by Subject',
                style: TextStyle(
                    color: _C.text,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            // "All" option
            _filterTile(ctx, null, 'All subjects', Icons.layers_outlined),
            const Divider(color: _C.divider, height: 1),
            ..._subjects.map((s) =>
                _filterTile(ctx, s, s, Icons.book_outlined)),
          ],
        ),
      ),
    );
    // result == '' means "All", non-null non-empty means a subject
    if (result != null) {
      setState(() => _filterSubject = result.isEmpty ? null : result);
    }
  }

  Widget _filterTile(
      BuildContext ctx, String? value, String label, IconData icon) {
    final selected = _filterSubject == value;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon,
          color: selected ? _C.accent : _C.subText, size: 20),
      title: Text(label,
          style: TextStyle(
              color: selected ? _C.accent : _C.text,
              fontWeight:
                  selected ? FontWeight.w600 : FontWeight.normal)),
      trailing: selected
          ? const Icon(Icons.check_rounded, color: _C.accent, size: 18)
          : null,
      onTap: () => Navigator.pop(ctx, value ?? ''),
    );
  }

  // ── Empty states ───────────────────────────────────────────────────────────
  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _C.surface,
                  border: Border.all(color: _C.divider)),
              child: const Icon(Icons.task_alt_outlined,
                  size: 36, color: Color(0xFF444444)),
            ),
            const SizedBox(height: 20),
            const Text('No tasks yet',
                style: TextStyle(
                    color: _C.subText,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text('Tap + to add your first task',
                style: TextStyle(color: Color(0xFF555555), fontSize: 13)),
          ],
        ),
      );

  Widget _buildEmptyFilter() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off_rounded,
                size: 48, color: Color(0xFF444444)),
            const SizedBox(height: 16),
            const Text('No tasks match this filter',
                style: TextStyle(color: _C.subText, fontSize: 15)),
          ],
        ),
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// Task Card
// ═══════════════════════════════════════════════════════════════════════════
class _TaskCard extends StatelessWidget {
  final TaskModel task;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TaskCard({
    required this.task,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline_rounded,
            color: Colors.redAccent, size: 22),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false; // we handle deletion ourselves via the dialog
      },
      child: GestureDetector(
        onTap: onEdit,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: task.isDone
                ? const Color(0xFF141414)
                : const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: task.isOverdue
                  ? Colors.redAccent.withValues(alpha: 0.4)
                  : _C.divider,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Checkbox
              GestureDetector(
                onTap: onToggle,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 22,
                  height: 22,
                  margin: const EdgeInsets.only(top: 1),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: task.isDone
                        ? _C.accent.withValues(alpha: 0.2)
                        : Colors.transparent,
                    border: Border.all(
                      color: task.isDone ? _C.accent : const Color(0xFF555555),
                      width: 1.5,
                    ),
                  ),
                  child: task.isDone
                      ? const Icon(Icons.check_rounded,
                          size: 13, color: _C.accent)
                      : null,
                ),
              ),

              const SizedBox(width: 14),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        color: task.isDone
                            ? const Color(0xFF555555)
                            : _C.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        decoration: task.isDone
                            ? TextDecoration.lineThrough
                            : null,
                        decorationColor: const Color(0xFF555555),
                      ),
                    ),
                    if (task.description != null &&
                        task.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        task.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Color(0xFF666666), fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 8),
                    // Meta chips row
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        // Priority
                        _metaChip(
                          icon: task.priority.icon,
                          label: task.priority.label,
                          color: task.priority.color,
                        ),
                        // Subject
                        if (task.subject != null)
                          _metaChip(
                            icon: Icons.book_outlined,
                            label: task.subject!,
                            color: const Color(0xFF8B93A6),
                          ),
                        // Due date
                        if (task.dueDate != null)
                          _metaChip(
                            icon: Icons.calendar_today_outlined,
                            label: task.dueDateLabel,
                            color: task.isOverdue
                                ? Colors.redAccent
                                : const Color(0xFF74957C),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Edit icon
              const Padding(
                padding: EdgeInsets.only(left: 8, top: 2),
                child: Icon(Icons.edit_outlined,
                    size: 15, color: Color(0xFF444444)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metaChip(
      {required IconData icon,
      required String label,
      required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Add / Edit Bottom Sheet
// ═══════════════════════════════════════════════════════════════════════════
class _TaskSheet extends StatefulWidget {
  final String uid;
  final List<String> subjects;
  final TaskModel? existing;
  final Future<void> Function(String newSubject) onSubjectAdded;
  final Future<void> Function(
    String title,
    String desc,
    String? subject,
    TaskPriority priority,
    DateTime? dueDate,
  ) onSave;

  const _TaskSheet({
    required this.uid,
    required this.subjects,
    required this.existing,
    required this.onSubjectAdded,
    required this.onSave,
  });

  @override
  State<_TaskSheet> createState() => _TaskSheetState();
}

class _TaskSheetState extends State<_TaskSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;

  String? _subject;
  TaskPriority _priority = TaskPriority.medium;
  DateTime? _dueDate;
  bool _saving = false;

  // local copy of subjects so we can add inside the sheet
  late List<String> _localSubjects;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final t = widget.existing;
    _titleCtrl = TextEditingController(text: t?.title ?? '');
    _descCtrl  = TextEditingController(text: t?.description ?? '');
    _subject   = t?.subject;
    _priority  = t?.priority ?? TaskPriority.medium;
    _dueDate   = t?.dueDate;
    _localSubjects = List<String>.from(widget.subjects);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await widget.onSave(
      _titleCtrl.text.trim(),
      _descCtrl.text.trim(),
      _subject,
      _priority,
      _dueDate,
    );
    if (mounted) Navigator.pop(context);
  }

  // ── Priority popup ─────────────────────────────────────────────────────────
  void _showPriorityMenu(BuildContext btnCtx) async {
    final box = btnCtx.findRenderObject() as RenderBox;
    final offset = box.localToGlobal(Offset.zero);

    final result = await showMenu<TaskPriority>(
      context: context,
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + box.size.height + 4,
        offset.dx + box.size.width,
        0,
      ),
      items: TaskPriority.values.map((p) => PopupMenuItem<TaskPriority>(
        value: p,
        child: Row(
          children: [
            Icon(p.icon, size: 14, color: p.color),
            const SizedBox(width: 10),
            Text(p.label,
                style: TextStyle(
                    color: _priority == p ? p.color : _C.text,
                    fontWeight: _priority == p
                        ? FontWeight.w700
                        : FontWeight.normal,
                    fontSize: 13)),
            if (_priority == p) ...[
              const Spacer(),
              Icon(Icons.check_rounded, size: 14, color: p.color),
            ],
          ],
        ),
      )).toList(),
    );
    if (result != null) setState(() => _priority = result);
  }

  // ── Subject popup ──────────────────────────────────────────────────────────
  void _showSubjectMenu(BuildContext btnCtx) async {
    final box = btnCtx.findRenderObject() as RenderBox;
    final offset = box.localToGlobal(Offset.zero);

    final items = <PopupMenuEntry<String>>[
      // None option
      PopupMenuItem<String>(
        value: '__none__',
        child: Row(
          children: [
            const Icon(Icons.block, size: 13, color: _C.subText),
            const SizedBox(width: 10),
            Text('None',
                style: TextStyle(
                    color: _subject == null ? _C.accent : _C.subText,
                    fontWeight: _subject == null
                        ? FontWeight.w600
                        : FontWeight.normal,
                    fontSize: 13)),
            if (_subject == null) ...[
              const Spacer(),
              const Icon(Icons.check_rounded, size: 14, color: _C.accent),
            ],
          ],
        ),
      ),
      if (_localSubjects.isNotEmpty) const PopupMenuDivider(),
      ..._localSubjects.map((s) => PopupMenuItem<String>(
            value: s,
            child: Row(
              children: [
                const Icon(Icons.book_outlined, size: 13, color: _C.subText),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(s,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: _subject == s ? _C.accent : _C.text,
                          fontWeight: _subject == s
                              ? FontWeight.w600
                              : FontWeight.normal,
                          fontSize: 13)),
                ),
                if (_subject == s)
                  const Icon(Icons.check_rounded,
                      size: 14, color: _C.accent),
              ],
            ),
          )),
      const PopupMenuDivider(),
      const PopupMenuItem<String>(
        value: '__add__',
        child: Row(
          children: [
            Icon(Icons.add_circle_outline, size: 14, color: _C.accent),
            SizedBox(width: 10),
            Text('Add subject',
                style: TextStyle(color: _C.accent, fontSize: 13)),
          ],
        ),
      ),
    ];

    final result = await showMenu<String>(
      context: context,
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + box.size.height + 4,
        offset.dx + box.size.width,
        0,
      ),
      items: items,
    );

    if (result == '__none__') {
      setState(() => _subject = null);
    } else if (result == '__add__') {
      _showAddSubjectDialog();
    } else if (result != null) {
      setState(() => _subject = result);
    }
  }

  // ── Add subject dialog ─────────────────────────────────────────────────────
  void _showAddSubjectDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Subject',
            style: TextStyle(color: _C.text, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: _C.text, fontSize: 14),
          cursorColor: _C.accent,
          decoration: InputDecoration(
            hintText: 'e.g. Mathematics',
            hintStyle: const TextStyle(color: _C.subText),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _C.accent),
            ),
          ),
          onSubmitted: (_) => _confirmAddSubject(ctrl, ctx),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: _C.subText)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.accent,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => _confirmAddSubject(ctrl, ctx),
            child: const Text('Add',
                style: TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmAddSubject(TextEditingController ctrl, BuildContext ctx) {
    final name = ctrl.text.trim();
    Navigator.pop(ctx);
    if (name.isEmpty || _localSubjects.contains(name)) return;
    setState(() {
      _localSubjects.add(name);
      _subject = name; // auto-select the newly added subject
    });
    // persist back to SharedPreferences + update TasksScreen list
    widget.onSubjectAdded(name);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFD4A24C),
            onPrimary: Colors.black,
            surface: Color(0xFF1A1A1A),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.92),
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottom),
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF333333),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              _isEditing ? 'Edit Task' : 'New Task',
              style: const TextStyle(
                  color: _C.text,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Task title field
            _label('Task'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _titleCtrl,
              autofocus: !_isEditing,
              style: const TextStyle(color: _C.text, fontSize: 14),
              cursorColor: _C.accent,
              decoration: _inputDec('e.g. Read chapter 3'),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Task title is required'
                  : null,
            ),

            const SizedBox(height: 14),

            // Description field
            _label('Notes (optional)'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _descCtrl,
              maxLines: 2,
              style: const TextStyle(color: _C.text, fontSize: 14),
              cursorColor: _C.accent,
              decoration: _inputDec('Add details…'),
            ),

            const SizedBox(height: 14),

            // Priority + Subject row
            Row(
              children: [
                // Priority
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Priority'),
                      const SizedBox(height: 6),
                      Builder(builder: (btnCtx) => GestureDetector(
                        onTap: () => _showPriorityMenu(btnCtx),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: _priority.color.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(_priority.icon,
                                  size: 14, color: _priority.color),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(_priority.label,
                                    style: TextStyle(
                                        color: _priority.color,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600)),
                              ),
                              Icon(Icons.keyboard_arrow_down_rounded,
                                  size: 16, color: _priority.color),
                            ],
                          ),
                        ),
                      )),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // Subject
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Subject'),
                      const SizedBox(height: 6),
                      Builder(builder: (btnCtx) => GestureDetector(
                        onTap: () => _showSubjectMenu(btnCtx),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: _subject != null
                                ? _C.accent.withValues(alpha: 0.08)
                                : const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _subject != null
                                  ? _C.accent.withValues(alpha: 0.35)
                                  : const Color(0xFF2A2A2A),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _subject != null
                                    ? Icons.book_outlined
                                    : Icons.add_circle_outline,
                                size: 14,
                                color: _subject != null
                                    ? _C.accent
                                    : _C.subText,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _subject ?? 'None',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: _subject != null
                                          ? _C.accent
                                          : _C.subText,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                              Icon(Icons.keyboard_arrow_down_rounded,
                                  size: 16,
                                  color: _subject != null
                                      ? _C.accent
                                      : _C.subText),
                            ],
                          ),
                        ),
                      )),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Due date
            _label('Due Date (optional)'),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF2A2A2A)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 15,
                      color: _dueDate != null
                          ? const Color(0xFF74957C)
                          : _C.subText,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _dueDate != null
                            ? '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}'
                            : 'Pick a date',
                        style: TextStyle(
                          color: _dueDate != null
                              ? _C.text
                              : _C.subText,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (_dueDate != null)
                      GestureDetector(
                        onTap: () => setState(() => _dueDate = null),
                        child: const Icon(Icons.close,
                            size: 14, color: _C.subText),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Save button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.accent,
                  disabledBackgroundColor:
                      _C.accent.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.black, strokeWidth: 2))
                    : Text(
                        _isEditing ? 'Save Changes' : 'Add Task',
                        style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 15),
                      ),
              ),
            ),
          ],
        ),
        ), // SingleChildScrollView
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
            color: _C.subText,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5),
      );

  InputDecoration _inputDec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(color: Color(0xFF555555), fontSize: 13),
        filled: true,
        fillColor: const Color(0xFF1A1A1A),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _C.accent),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        errorStyle:
            const TextStyle(color: Colors.redAccent, fontSize: 11),
      );
}
