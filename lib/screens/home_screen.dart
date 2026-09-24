import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'profile_screen.dart';

// ---------------------------------------------------------------------------
// Colour palette (mirrors main.dart FFColors)
// ---------------------------------------------------------------------------
class _C {
  static const bg = Color(0xFF000000);
  static const surface = Color(0xFF1A1A1A);
  static const border = Color(0xFFFFFFFF);
  static const text = Color(0xFFFFFFFF);
  static const subText = Color(0xFFAAAAAA);
  static const accent = Color(0xFFD4A24C);
  static const drawerBg = Color(0xFF111111);
  static const navBg = Color(0xFF0D0D0D);
  static const divider = Color(0xFF2A2A2A);
}

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------
enum TimerState { idle, running, paused }

enum NavTab { home, stats, progress, sessions, tasks }

// ---------------------------------------------------------------------------
// HomeScreen
// ---------------------------------------------------------------------------
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ── subjects ──────────────────────────────────────────────────────────────
  final List<String> _subjects = [];
  String? _selectedSubject;

  // ── timer ─────────────────────────────────────────────────────────────────
  static const int _totalSeconds = 25 * 60;
  int _remaining = _totalSeconds;
  TimerState _timerState = TimerState.idle;
  Timer? _timer;

  // ── nav ───────────────────────────────────────────────────────────────────
  NavTab _currentTab = NavTab.home;

  // ── scaffold key for drawer ───────────────────────────────────────────────
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // ── timer helpers ─────────────────────────────────────────────────────────
  void _startTimer() {
    setState(() => _timerState = TimerState.running);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remaining <= 0) {
        _timer?.cancel();
        setState(() => _timerState = TimerState.idle);
        return;
      }
      setState(() => _remaining--);
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() => _timerState = TimerState.paused);
  }

  void _resumeTimer() => _startTimer();

  void _restartTimer() {
    _timer?.cancel();
    setState(() {
      _remaining = _totalSeconds;
      _timerState = TimerState.idle;
    });
  }

  String get _timeLabel {
    final m = (_remaining ~/ 60).toString().padLeft(2, '0');
    final s = (_remaining % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── subject dialog ────────────────────────────────────────────────────────
  void _showAddSubjectDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _C.surface,
        title: const Text('Add Subject',
            style: TextStyle(color: _C.text, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: _C.text),
          cursorColor: _C.accent,
          decoration: InputDecoration(
            hintText: 'e.g. Mathematics',
            hintStyle: const TextStyle(color: _C.subText),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _C.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _C.accent),
            ),
          ),
          onSubmitted: (_) => _confirmAdd(controller),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Cancel', style: TextStyle(color: _C.subText)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _C.accent),
            onPressed: () => _confirmAdd(controller),
            child: const Text('Add',
                style: TextStyle(color: Colors.black,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmAdd(TextEditingController c) {
    final name = c.text.trim();
    if (name.isNotEmpty && !_subjects.contains(name)) {
      setState(() => _subjects.add(name));
    }
    Navigator.pop(context);
  }

  // ── subject popup ─────────────────────────────────────────────────────────
  void _showSubjectMenu(BuildContext btnCtx) async {
    final RenderBox box = btnCtx.findRenderObject() as RenderBox;
    final Offset offset = box.localToGlobal(Offset.zero);

    final items = <PopupMenuEntry<String>>[
      ..._subjects.map(
        (s) => PopupMenuItem<String>(
          value: s,
          child: Row(
            children: [
              Icon(Icons.circle,
                  size: 8,
                  color:
                      _selectedSubject == s ? _C.accent : _C.subText),
              const SizedBox(width: 10),
              Text(s,
                  style: TextStyle(
                      color: _selectedSubject == s
                          ? _C.accent
                          : _C.text)),
            ],
          ),
        ),
      ),
      if (_subjects.isNotEmpty)
        const PopupMenuDivider(),
      const PopupMenuItem<String>(
        value: '__add__',
        child: Row(
          children: [
            Icon(Icons.add, size: 16, color: _C.accent),
            SizedBox(width: 8),
            Text('Add subject',
                style: TextStyle(color: _C.accent)),
          ],
        ),
      ),
    ];

    // If no subjects yet, only show Add subject
    final menuItems = _subjects.isEmpty
        ? [
            const PopupMenuItem<String>(
              value: '__add__',
              child: Row(
                children: [
                  Icon(Icons.add, size: 16, color: _C.accent),
                  SizedBox(width: 8),
                  Text('Add subject',
                      style: TextStyle(color: _C.accent)),
                ],
              ),
            ),
          ]
        : items;

    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + box.size.height,
        offset.dx + box.size.width,
        0,
      ),
      color: _C.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      items: menuItems,
    );

    if (result == '__add__') {
      _showAddSubjectDialog();
    } else if (result != null) {
      setState(() => _selectedSubject = result);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ── build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _C.bg,
      // ── App bar ────────────────────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Focus Flow',
          style: TextStyle(
            color: _C.text,
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: 0.5,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.menu, color: _C.text),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
      ),
      // ── Drawer ─────────────────────────────────────────────────────────
      drawer: _buildDrawer(),
      // ── Body ───────────────────────────────────────────────────────────
      body: _currentTab == NavTab.home
          ? _buildHomeBody()
          : _buildPlaceholder(_currentTab),
      // ── Bottom Nav ─────────────────────────────────────────────────────
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── Home body ─────────────────────────────────────────────────────────────
  Widget _buildHomeBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Subject selector
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Builder(
            builder: (btnCtx) => GestureDetector(
              onTap: () => _showSubjectMenu(btnCtx),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _C.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _C.divider),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _selectedSubject ?? 'Select subject',
                      style: TextStyle(
                        color: _selectedSubject != null
                            ? _C.text
                            : _C.subText,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_drop_down,
                        color: _C.subText, size: 20),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Timer area – sits in upper-centre of the remaining space
        Expanded(
          child: Align(
            alignment: const Alignment(0, -0.35),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Circular timer
                SizedBox(
                  width: 260,
                  height: 260,
                  child: CustomPaint(
                    painter: _TimerRingPainter(
                      progress: _remaining / _totalSeconds,
                      trackColor: _C.divider,
                      arcColor: _timerState == TimerState.idle
                          ? _C.border
                          : _timerState == TimerState.paused
                              ? _C.subText
                              : _C.accent,
                      strokeWidth: 4,
                    ),
                    child: Center(
                      child: Text(
                        _timeLabel,
                        style: const TextStyle(
                          color: _C.text,
                          fontSize: 52,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 3,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // Buttons
                _buildTimerButtons(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Timer buttons ─────────────────────────────────────────────────────────
  Widget _buildTimerButtons() {
    if (_timerState == TimerState.idle) {
      return _pill(
        label: 'Start',
        onTap: _startTimer,
        filled: false,
      );
    }

    if (_timerState == TimerState.running) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _pill(label: 'Pause', onTap: _pauseTimer, filled: false),
          const SizedBox(width: 12),
          _pill(label: 'Restart', onTap: _restartTimer, filled: false),
        ],
      );
    }

    // paused
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _pill(label: 'Resume', onTap: _resumeTimer, filled: false),
        const SizedBox(width: 12),
        _pill(label: 'Restart', onTap: _restartTimer, filled: false),
      ],
    );
  }

  Widget _pill({
    required String label,
    required VoidCallback onTap,
    bool filled = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 22, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: _C.text, width: 1),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: _C.text,
            fontSize: 16,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  // ── Bottom navigation ─────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: _C.navBg,
        border: Border(top: BorderSide(color: _C.divider, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navIcon(NavTab.home, Icons.timer_outlined, Icons.timer,
                  'Timer'),
              _navIcon(NavTab.stats, Icons.bar_chart_outlined,
                  Icons.bar_chart, 'Stats'),
              _navIcon(NavTab.progress, Icons.trending_up_outlined,
                  Icons.trending_up, 'Progress'),
              _navIcon(NavTab.sessions, Icons.history_outlined,
                  Icons.history, 'Sessions'),
              _navIcon(
                  NavTab.tasks, Icons.task_alt_outlined, Icons.task_alt, 'Tasks'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navIcon(
      NavTab tab, IconData outlineIcon, IconData filledIcon, String label) {
    final active = _currentTab == tab;
    return GestureDetector(
      onTap: () => setState(() => _currentTab = tab),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              active ? filledIcon : outlineIcon,
              color: active ? _C.accent : _C.subText,
              size: 24,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: active ? _C.accent : _C.subText,
                fontSize: 10,
                fontWeight:
                    active ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Placeholder for non-home tabs ─────────────────────────────────────────
  Widget _buildPlaceholder(NavTab tab) {
    final labels = {
      NavTab.stats: ('Weekly Study Stats', Icons.bar_chart),
      NavTab.progress: ('Progress Dashboard', Icons.trending_up),
      NavTab.sessions: ('Completed Sessions', Icons.history),
      NavTab.tasks: ('Task Management', Icons.task_alt),
    };
    final info = labels[tab]!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(info.$2, size: 64, color: _C.subText),
          const SizedBox(height: 16),
          Text(
            info.$1,
            style: const TextStyle(
                color: _C.subText,
                fontSize: 20,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          const Text(
            'Coming soon',
            style: TextStyle(color: _C.divider, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ── Drawer ────────────────────────────────────────────────────────────────
  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: _C.drawerBg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: _C.surface,
                    child: const Icon(Icons.person,
                        size: 36, color: _C.subText),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AuthService().currentUser?.displayName ?? 'Focus Flow',
                    style: const TextStyle(
                        color: _C.text,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AuthService().currentUser?.email ?? 'Stay focused, stay ahead',
                    style: const TextStyle(color: _C.subText, fontSize: 12),
                  ),
                ],
              ),
            ),

            Divider(color: _C.divider, thickness: 0.5,
                indent: 20, endIndent: 20),
            const SizedBox(height: 8),

            // Menu items
            _drawerItem(
              icon: Icons.person_outline,
              label: 'Profile',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ProfileScreen()),
                );
              },
            ),
            _drawerItem(
              icon: Icons.palette_outlined,
              label: 'App Theme',
              onTap: () {
                Navigator.pop(context);
                _showSnack('Theme settings – coming soon');
              },
            ),
            _drawerItem(
              icon: Icons.settings_outlined,
              label: 'Settings',
              onTap: () {
                Navigator.pop(context);
                _showSnack('Settings – coming soon');
              },
            ),

            const Spacer(),

            Divider(color: _C.divider, thickness: 0.5,
                indent: 20, endIndent: 20),

            _drawerItem(
              icon: Icons.logout,
              label: 'Logout',
              iconColor: Colors.redAccent,
              labelColor: Colors.redAccent,
              onTap: () async {
                Navigator.pop(context); // close drawer first
                await AuthService().logout();
                // AuthGate's StreamBuilder handles the redirect to LoginScreen
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color iconColor = _C.subText,
    Color labelColor = _C.text,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor, size: 22),
      title: Text(label,
          style: TextStyle(
              color: labelColor,
              fontSize: 15,
              fontWeight: FontWeight.w500)),
      horizontalTitleGap: 8,
      onTap: onTap,
      hoverColor: _C.surface,
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }
}

// ---------------------------------------------------------------------------
// Timer ring painter
// ---------------------------------------------------------------------------
class _TimerRingPainter extends CustomPainter {
  final double progress;   // 1.0 = full, 0.0 = empty
  final Color trackColor;
  final Color arcColor;
  final double strokeWidth;

  const _TimerRingPainter({
    required this.progress,
    required this.trackColor,
    required this.arcColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - strokeWidth / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track ring (full dim circle)
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc — starts at top (–π/2), sweeps clockwise
    final sweepAngle = 2 * math.pi * progress;

    final arcPaint = Paint()
      ..color = arcColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    canvas.drawArc(
      rect,
      -math.pi / 2,       // start at 12 o'clock
      sweepAngle,         // sweep proportional to remaining time
      false,
      arcPaint,
    );

    // Dot at the shrinking tip (end of the arc)
    if (progress > 0) {
      final tipAngle = -math.pi / 2 + sweepAngle;
      final tipX = center.dx + radius * math.cos(tipAngle);
      final tipY = center.dy + radius * math.sin(tipAngle);

      // Slightly larger white filled circle
      final dotPaint = Paint()
        ..color = const Color(0xFFFFFFFF)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(tipX, tipY), strokeWidth * 0.85, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_TimerRingPainter old) =>
      old.progress != progress ||
      old.arcColor != arcColor ||
      old.trackColor != trackColor;
}


