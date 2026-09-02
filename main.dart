import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as xlsx;
import 'package:archive/archive.dart' as arc;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = WalidStore();
  await store.load();
  runApp(WalidApp(store: store));
}

// ============================================================
// نماذج البيانات
// ============================================================

class Student {
  String id, name, section, gender, notes;
  Student({
    required this.id,
    required this.name,
    required this.section,
    this.gender = 'ذكر',
    this.notes = '',
  });
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'section': section,
        'gender': gender,
        'notes': notes,
      };
  factory Student.fromJson(Map<String, dynamic> j) => Student(
        id: j['id'],
        name: j['name'],
        section: j['section'],
        gender: j['gender'] ?? 'ذكر',
        notes: j['notes'] ?? '',
      );
}

class Attendance {
  String studentId, date, status;
  Attendance({
    required this.studentId,
    required this.date,
    required this.status,
  });
  Map<String, dynamic> toJson() =>
      {'studentId': studentId, 'date': date, 'status': status};
  factory Attendance.fromJson(Map<String, dynamic> j) => Attendance(
        studentId: j['studentId'],
        date: j['date'],
        status: j['status'],
      );
}

class Grade {
  String studentId, activity;
  double score;
  Grade({
    required this.studentId,
    required this.activity,
    required this.score,
  });
  Map<String, dynamic> toJson() =>
      {'studentId': studentId, 'activity': activity, 'score': score};
  factory Grade.fromJson(Map<String, dynamic> j) => Grade(
        studentId: j['studentId'],
        activity: j['activity'],
        score: (j['score'] as num).toDouble(),
      );
}

class NotebookEntry {
  String text;
  String? fileName;
  String? filePath;
  NotebookEntry({this.text = '', this.fileName, this.filePath});
  Map<String, dynamic> toJson() =>
      {'text': text, 'fileName': fileName, 'filePath': filePath};
  factory NotebookEntry.fromJson(Map<String, dynamic> j) => NotebookEntry(
        text: j['text'] ?? '',
        fileName: j['fileName'],
        filePath: j['filePath'],
      );
}

// ============================================================
// المخزن (الحفظ المحلي)
// ============================================================

class WalidStore extends ChangeNotifier {
  final sections = <String>[];
  final students = <Student>[];
  final attendance = <Attendance>[];
  final grades = <Grade>[];
  bool loaded = false;
  int _counter = 0;

  NotebookEntry yearlyProgram = NotebookEntry();
  NotebookEntry yearlyDistribution = NotebookEntry();
  NotebookEntry term1Notebook = NotebookEntry();
  NotebookEntry term2Notebook = NotebookEntry();
  NotebookEntry term3Notebook = NotebookEntry();

  NotebookEntry _loadNotebook(SharedPreferences p, String key) {
    final raw = p.getString(key);
    if (raw == null) return NotebookEntry();
    try {
      return NotebookEntry.fromJson(jsonDecode(raw));
    } catch (_) {
      return NotebookEntry();
    }
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    sections.addAll(p.getStringList('sections') ?? []);
    students.addAll(
      (p.getStringList('students') ?? [])
          .map((x) => Student.fromJson(jsonDecode(x))),
    );
    attendance.addAll(
      (p.getStringList('attendance') ?? [])
          .map((x) => Attendance.fromJson(jsonDecode(x))),
    );
    grades.addAll(
      (p.getStringList('grades') ?? [])
          .map((x) => Grade.fromJson(jsonDecode(x))),
    );
    yearlyProgram = _loadNotebook(p, 'nb_yearlyProgram');
    yearlyDistribution = _loadNotebook(p, 'nb_yearlyDistribution');
    term1Notebook = _loadNotebook(p, 'nb_term1');
    term2Notebook = _loadNotebook(p, 'nb_term2');
    term3Notebook = _loadNotebook(p, 'nb_term3');
    loaded = true;
    notifyListeners();
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList('sections', sections);
    await p.setStringList(
      'students',
      students.map((x) => jsonEncode(x.toJson())).toList(),
    );
    await p.setStringList(
      'attendance',
      attendance.map((x) => jsonEncode(x.toJson())).toList(),
    );
    await p.setStringList(
      'grades',
      grades.map((x) => jsonEncode(x.toJson())).toList(),
    );
    await p.setString('nb_yearlyProgram', jsonEncode(yearlyProgram.toJson()));
    await p.setString(
      'nb_yearlyDistribution',
      jsonEncode(yearlyDistribution.toJson()),
    );
    await p.setString('nb_term1', jsonEncode(term1Notebook.toJson()));
    await p.setString('nb_term2', jsonEncode(term2Notebook.toJson()));
    await p.setString('nb_term3', jsonEncode(term3Notebook.toJson()));
    notifyListeners();
  }

  String id() {
    _counter++;
    return '${DateTime.now().microsecondsSinceEpoch}_$_counter';
  }
}

// ============================================================
// الهوية البصرية
// ============================================================

class AppColors {
  static const primary = Color(0xFF176B87);
  static const accent = Color(0xFF20A4A9);
  static const bg = Color(0xFFF5F8FA);
  static const gold = Color(0xFFF5A623);
  static const tardy = Color(0xFFE8A33D);
  static const absent = Color(0xFFE85D5D);
  static const excused = Color(0xFF5B8DEF);
  static const present = Color(0xFF2FAE6B);

  static const avatarPalette = [
    Color(0xFF176B87),
    Color(0xFF20A4A9),
    Color(0xFFE8A33D),
    Color(0xFF6C63C4),
    Color(0xFF5B8DEF),
  ];

  static Color forStatus(String status) {
    switch (status) {
      case 'حاضر':
        return present;
      case 'غائب':
        return absent;
      case 'متأخر':
        return tardy;
      default:
        return excused;
    }
  }
}

String initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '؟';
  if (parts.length == 1) return parts.first.substring(0, 1);
  return parts[0].substring(0, 1) + parts[1].substring(0, 1);
}

Color avatarColorFor(String seed) {
  var sum = 0;
  for (final r in seed.runes) {
    sum += r;
  }
  return AppColors.avatarPalette[sum % AppColors.avatarPalette.length];
}

double? averageFor(WalidStore store, String studentId) {
  final g = store.grades.where((x) => x.studentId == studentId).toList();
  if (g.isEmpty) return null;
  final total = g.fold<double>(0, (sum, x) => sum + x.score);
  return total / g.length;
}

String unescapeXml(String s) => s
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'");

String arabicDate(DateTime d) {
  const months = [
    'جانفي',
    'فيفري',
    'مارس',
    'أفريل',
    'ماي',
    'جوان',
    'جويلية',
    'أوت',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

// ============================================================
// التطبيق
// ============================================================

class WalidApp extends StatelessWidget {
  final WalidStore store;
  const WalidApp({super.key, required this.store});

  @override
  Widget build(BuildContext c) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'WALID',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
          scaffoldBackgroundColor: AppColors.bg,
        ),
        home: WalidHome(store: store),
      );
}

class WalidHome extends StatefulWidget {
  final WalidStore store;
  const WalidHome({super.key, required this.store});
  @override
  State<WalidHome> createState() => _WalidHomeState();
}

class _WalidHomeState extends State<WalidHome> {
  int page = 0;
  final labels = [
    'لوحة التحكم',
    'الأقسام',
    'التلاميذ',
    'الحضور',
    'التقييم',
    'الأنشطة',
    'مذكراتي',
    'التقارير',
    'الإعدادات',
  ];
  final icons = [
    Icons.dashboard_rounded,
    Icons.school_rounded,
    Icons.groups_rounded,
    Icons.fact_check_rounded,
    Icons.assessment_rounded,
    Icons.emoji_events_rounded,
    Icons.menu_book_rounded,
    Icons.description_rounded,
    Icons.settings_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          title: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, AppColors.accent],
                  ),
                ),
                child: const Icon(Icons.directions_run, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'WALID',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
                  ),
                  Text(
                    'إدارة التربية البدنية والرياضية',
                    style: TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                ],
              ),
            ],
          ),
        ),
        body: Row(
          children: [
            NavigationRail(
              backgroundColor: Colors.white,
              selectedIndex: page,
              labelType: NavigationRailLabelType.all,
              minWidth: 82,
              selectedIconTheme: const IconThemeData(color: AppColors.primary),
              selectedLabelTextStyle: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
              onDestinationSelected: (i) => setState(() => page = i),
              destinations: [
                for (int i = 0; i < labels.length; i++)
                  NavigationRailDestination(
                    icon: Icon(icons[i]),
                    selectedIcon: Icon(icons[i]),
                    label: Text(labels[i]),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: AnimatedBuilder(
                animation: widget.store,
                builder: (_, __) => AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: KeyedSubtree(
                    key: ValueKey(page),
                    child: _buildPage(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage() {
    switch (page) {
      case 1:
        return SectionsPage(store: widget.store);
      case 2:
        return StudentsPage(store: widget.store);
      case 3:
        return AttendancePage(store: widget.store);
      case 4:
        return GradesPage(store: widget.store);
      case 5:
        return const ActivitiesPage();
      case 6:
        return NotebooksPage(store: widget.store);
      case 7:
        return ReportsPage(store: widget.store);
      case 8:
        return SettingsPage(store: widget.store);
      default:
        return Dashboard(store: widget.store);
    }
  }
}

// ============================================================
// لوحة التحكم
// ============================================================

class Dashboard extends StatelessWidget {
  final WalidStore store;
  const Dashboard({super.key, required this.store});

  @override
  Widget build(BuildContext c) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(26),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [AppColors.primary, AppColors.accent],
                    ),
                  ),
                  child: const Text(
                    'مرحبًا بك في WALID 👋\nكل أدوات التربية البدنية في مكان واحد.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      height: 1.6,
                    ),
                  ),
                ),
                Positioned(top: -30, left: -30, child: _decoCircle(120, 0.10)),
                Positioned(bottom: -46, right: -20, child: _decoCircle(150, 0.08)),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              Stat('الأقسام', '${store.sections.length}', Icons.school),
              Stat('التلاميذ', '${store.students.length}', Icons.groups),
              Stat(
                'الحضور اليوم',
                '${_attendancePercent(store)}%',
                Icons.fact_check,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'الوصول السريع',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          const Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              Quick('إضافة تلميذ', Icons.person_add_alt_1),
              Quick('تسجيل الحضور', Icons.fact_check),
              Quick('إدخال تقييم', Icons.edit_note),
              Quick('إنشاء تقرير', Icons.summarize),
            ],
          ),
        ],
      );

  static Widget _decoCircle(double size, double opacity) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(opacity),
        ),
      );

  static String _attendancePercent(WalidStore s) {
    final d = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final a = s.attendance.where((x) => x.date == d).toList();
    if (a.isEmpty) return '0';
    return ((a.where((x) => x.status == 'حاضر').length / a.length) * 100)
        .round()
        .toString();
  }
}

class Stat extends StatelessWidget {
  final String a, b;
  final IconData i;
  const Stat(this.a, this.b, this.i, {super.key});

  @override
  Widget build(BuildContext c) => Container(
        width: 205,
        height: 122,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(i, color: AppColors.primary, size: 18),
            ),
            const Spacer(),
            Text(a, style: const TextStyle(color: Colors.black54, fontSize: 12)),
            Text(b, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          ],
        ),
      );
}

class Quick extends StatelessWidget {
  final String t;
  final IconData i;
  const Quick(this.t, this.i, {super.key});

  @override
  Widget build(BuildContext c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(i, color: AppColors.primary, size: 19),
            const SizedBox(width: 10),
            Text(t, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      );
}

// ============================================================
// الأقسام
// ============================================================

class SectionsPage extends StatelessWidget {
  final WalidStore store;
  const SectionsPage({super.key, required this.store});

  @override
  Widget build(BuildContext c) => PageShell(
        title: 'الأقسام',
        icon: Icons.school,
        action: 'إضافة قسم',
        onAdd: () => addOrEdit(c),
        child: store.sections.isEmpty
            ? const Empty(icon: Icons.school_outlined, text: 'لا توجد أقسام بعد.')
            : ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  for (final s in store.sections)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border(
                          right: BorderSide(color: avatarColorFor(s), width: 4),
                        ),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: avatarColorFor(s).withOpacity(0.12),
                          child: Icon(Icons.school, color: avatarColorFor(s)),
                        ),
                        title: Text(
                          s,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${store.students.where((x) => x.section == s).length} تلميذ',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'نسخ قائمة التلاميذ',
                              icon: const Icon(Icons.copy_outlined, size: 20),
                              onPressed: () => _copyRoster(c, s),
                            ),
                            rowMenu(
                              onEdit: () => addOrEdit(c, existing: s),
                              onDelete: () => confirm(
                                c,
                                'حذف القسم "$s" وكل تلاميذه؟',
                                () {
                                  store.sections.remove(s);
                                  store.students.removeWhere((x) => x.section == s);
                                  store.save();
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      );

  void _copyRoster(BuildContext c, String section) {
    final list = store.students.where((x) => x.section == section).toList();
    final buffer = StringBuffer('قائمة تلاميذ: $section\n\n');
    for (var i = 0; i < list.length; i++) {
      buffer.writeln('${i + 1}. ${list[i].name}');
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(c).showSnackBar(
      const SnackBar(content: Text('تم نسخ القائمة — يمكنك لصقها في أي مستند للطباعة')),
    );
  }

  Future<void> addOrEdit(BuildContext c, {String? existing}) async {
    final x = TextEditingController(text: existing ?? '');
    await showDialog(
      context: c,
      builder: (_) => AlertDialog(
        title: Text(existing == null ? 'إضافة قسم' : 'تعديل اسم القسم'),
        content: TextField(
          controller: x,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'اسم القسم'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final v = x.text.trim();
              if (v.isEmpty) return;
              if (existing == null) {
                if (!store.sections.contains(v)) {
                  store.sections.add(v);
                  store.save();
                }
              } else if (v != existing && !store.sections.contains(v)) {
                final idx = store.sections.indexOf(existing);
                if (idx != -1) store.sections[idx] = v;
                for (final st in store.students) {
                  if (st.section == existing) st.section = v;
                }
                store.save();
              }
              Navigator.pop(c);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// التلاميذ
// ============================================================

class StudentsPage extends StatefulWidget {
  final WalidStore store;
  const StudentsPage({super.key, required this.store});
  @override
  State<StudentsPage> createState() => _StudentsState();
}

class _StudentsState extends State<StudentsPage> {
  String q = '';

  String _subtitleFor(Student s) {
    final avg = averageFor(widget.store, s.id);
    final base = '${s.section} • ${s.gender}';
    return avg == null ? base : '$base • المعدل: ${avg.toStringAsFixed(1)}';
  }

  @override
  Widget build(BuildContext c) {
    final list =
        widget.store.students.where((s) => s.name.contains(q)).toList();
    return PageShell(
      title: 'التلاميذ',
      icon: Icons.groups,
      action: 'إضافة تلميذ',
      onAdd: () => addOrEdit(c),
      extraActions: [
        OutlinedButton.icon(
          onPressed: () => importDialog(c),
          icon: const Icon(Icons.file_upload_outlined, size: 18),
          label: const Text('استيراد'),
        ),
        const SizedBox(width: 8),
      ],
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (v) => setState(() => q = v),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'بحث عن تلميذ',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? const Empty(icon: Icons.person_search, text: 'لا توجد نتائج.')
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      for (final s in list)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: avatarColorFor(s.name),
                              child: Text(
                                initials(s.name),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              s.name,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(_subtitleFor(s)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (s.notes.trim().isNotEmpty)
                                  const Padding(
                                    padding: EdgeInsets.only(left: 4),
                                    child: Icon(
                                      Icons.sticky_note_2_outlined,
                                      size: 18,
                                      color: AppColors.tardy,
                                    ),
                                  ),
                                rowMenu(
                                  onEdit: () => addOrEdit(c, existing: s),
                                  onDelete: () => confirm(
                                    c,
                                    'حذف التلميذ "${s.name}"؟',
                                    () {
                                      widget.store.students.remove(s);
                                      widget.store.attendance
                                          .removeWhere((a) => a.studentId == s.id);
                                      widget.store.grades
                                          .removeWhere((g) => g.studentId == s.id);
                                      widget.store.save();
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // إضافة / تعديل تلميذ واحد
  // ------------------------------------------------------------
  Future<void> addOrEdit(BuildContext c, {Student? existing}) async {
    if (widget.store.sections.isEmpty) {
      ScaffoldMessenger.of(c).showSnackBar(
        const SnackBar(content: Text('أضف قسمًا أولًا من صفحة الأقسام')),
      );
      return;
    }
    final n = TextEditingController(text: existing?.name ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    String sec = existing?.section ?? widget.store.sections.first;
    String gender = existing?.gender ?? 'ذكر';
    await showDialog(
      context: c,
      builder: (_) => StatefulBuilder(
        builder: (c2, setD) => AlertDialog(
          title: Text(existing == null ? 'إضافة تلميذ' : 'تعديل بيانات التلميذ'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: n,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'الاسم واللقب'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: sec,
                  items: widget.store.sections
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setD(() => sec = v!),
                  decoration: const InputDecoration(labelText: 'القسم'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: gender,
                  items: const [
                    DropdownMenuItem(value: 'ذكر', child: Text('ذكر')),
                    DropdownMenuItem(value: 'أنثى', child: Text('أنثى')),
                  ],
                  onChanged: (v) => setD(() => gender = v!),
                  decoration: const InputDecoration(labelText: 'الجنس'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات (اختياري)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c2),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                final name = n.text.trim();
                if (name.isEmpty) return;
                if (existing == null) {
                  widget.store.students.add(
                    Student(
                      id: widget.store.id(),
                      name: name,
                      section: sec,
                      gender: gender,
                      notes: notesCtrl.text.trim(),
                    ),
                  );
                } else {
                  existing.name = name;
                  existing.section = sec;
                  existing.gender = gender;
                  existing.notes = notesCtrl.text.trim();
                }
                widget.store.save();
                Navigator.pop(c2);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // استيراد قائمة تلاميذ (لصق نص / Excel / CSV / Word)
  // ------------------------------------------------------------
  Future<void> importDialog(BuildContext c) async {
    if (widget.store.sections.isEmpty) {
      ScaffoldMessenger.of(c).showSnackBar(
        const SnackBar(content: Text('أضف قسمًا أولًا من صفحة الأقسام')),
      );
      return;
    }
    String sec = widget.store.sections.first;
    final pasteCtrl = TextEditingController();
    bool busy = false;

    await showDialog(
      context: c,
      builder: (_) => StatefulBuilder(
        builder: (c2, setD) => AlertDialog(
          title: const Text('استيراد قائمة تلاميذ'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: sec,
                  items: widget.store.sections
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setD(() => sec = v!),
                  decoration: const InputDecoration(labelText: 'القسم الافتراضي'),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: busy
                        ? null
                        : () async {
                            setD(() => busy = true);
                            final lines = await _pickAndParseFile(c2);
                            setD(() => busy = false);
                            if (lines == null) return;
                            if (lines.isEmpty) {
                              ScaffoldMessenger.of(c2).showSnackBar(
                                const SnackBar(
                                  content: Text('لم يتم العثور على أسماء في الملف'),
                                ),
                              );
                              return;
                            }
                            final added = _applyImport(lines, sec);
                            if (context.mounted) Navigator.pop(c2);
                            ScaffoldMessenger.of(c).showSnackBar(
                              SnackBar(content: Text('تمت إضافة $added تلميذ')),
                            );
                          },
                    icon: busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.file_upload_outlined),
                    label: Text(busy ? 'جارٍ القراءة...' : 'اختيار ملف'),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'صيغ مدعومة: Excel (xlsx), CSV، Word (docx).\n'
                  'العمود الأول = الاسم، ويمكن إضافة القسم والجنس في أعمدة تالية.',
                  style: TextStyle(fontSize: 11, color: Colors.black45),
                ),
                const Divider(height: 30),
                const Text(
                  'أو الصق الأسماء يدويًا (اسم في كل سطر):',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: pasteCtrl,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'أحمد بلقاسم\nسارة مرابط\n...',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c2),
              child: const Text('إغلاق'),
            ),
            FilledButton(
              onPressed: () {
                final lines = pasteCtrl.text
                    .split(RegExp(r'\r\n|\r|\n'))
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();
                if (lines.isEmpty) {
                  ScaffoldMessenger.of(c2).showSnackBar(
                    const SnackBar(content: Text('الصق أسماء أولًا أو اختر ملفًا')),
                  );
                  return;
                }
                final added = _applyImport(lines, sec);
                Navigator.pop(c2);
                ScaffoldMessenger.of(c).showSnackBar(
                  SnackBar(content: Text('تمت إضافة $added تلميذ')),
                );
              },
              child: const Text('استيراد من النص'),
            ),
          ],
        ),
      ),
    );
  }

  int _applyImport(List<String> rawLines, String defaultSection) {
    var lines = rawLines;
    if (lines.isNotEmpty) {
      final firstToken = lines.first.split(',').first.trim().toLowerCase();
      if (firstToken == 'name' || firstToken == 'الاسم') {
        lines = lines.sublist(1);
      }
    }
    var added = 0;
    for (final raw in lines) {
      final parts = raw.split(',').map((e) => e.trim()).toList();
      final name = parts.isNotEmpty ? parts[0] : '';
      if (name.isEmpty) continue;
      final sec =
          (parts.length > 1 && parts[1].isNotEmpty) ? parts[1] : defaultSection;
      final gender =
          (parts.length > 2 && parts[2].isNotEmpty) ? parts[2] : 'ذكر';
      if (!widget.store.sections.contains(sec)) {
        widget.store.sections.add(sec);
      }
      widget.store.students.add(
        Student(id: widget.store.id(), name: name, section: sec, gender: gender),
      );
      added++;
    }
    if (added > 0) {
      widget.store.save();
      setState(() {});
    }
    return added;
  }

  Future<List<String>?> _pickAndParseFile(BuildContext dialogContext) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'csv', 'docx'],
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return null;
      final file = result.files.single;
      final lowerName = file.name.toLowerCase();

      Uint8List? bytes = file.bytes;
      if (bytes == null && file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      }
      if (bytes == null) {
        _showImportError(dialogContext, 'تعذّرت قراءة الملف');
        return null;
      }

      if (lowerName.endsWith('.csv')) {
        return _parseCsv(bytes);
      } else if (lowerName.endsWith('.xlsx')) {
        return _parseXlsx(bytes);
      } else if (lowerName.endsWith('.docx')) {
        return _parseDocx(bytes);
      }
      _showImportError(dialogContext, 'صيغة الملف غير مدعومة');
      return null;
    } catch (_) {
      _showImportError(dialogContext, 'حدث خطأ أثناء قراءة الملف');
      return null;
    }
  }

  void _showImportError(BuildContext dialogContext, String msg) {
    ScaffoldMessenger.of(dialogContext).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  List<String> _parseCsv(Uint8List bytes) {
    final text = utf8.decode(bytes, allowMalformed: true);
    return text
        .split(RegExp(r'\r\n|\r|\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
  }

  List<String> _parseXlsx(Uint8List bytes) {
    final excelFile = xlsx.Excel.decodeBytes(bytes);
    final lines = <String>[];
    for (final tableName in excelFile.tables.keys) {
      final sheet = excelFile.tables[tableName];
      if (sheet == null) continue;
      for (final row in sheet.rows) {
        final cells = <String>[];
        for (final cell in row) {
          final v = cell?.value;
          final text = v == null ? '' : v.toString().trim();
          if (text.isNotEmpty) cells.add(text);
        }
        if (cells.isNotEmpty) lines.add(cells.join(','));
      }
      break;
    }
    return lines;
  }

  List<String> _parseDocx(Uint8List bytes) {
    final archive = arc.ZipDecoder().decodeBytes(bytes);
    arc.ArchiveFile? docFile;
    for (final f in archive) {
      if (f.name == 'word/document.xml') {
        docFile = f;
        break;
      }
    }
    if (docFile == null) return [];

    final content = docFile.content;
    if (content is! List<int>) return [];
    final xml = utf8.decode(content, allowMalformed: true);

    final paragraphs = xml.split('</w:p>');
    final textReg = RegExp(r'<w:t[^>]*>(.*?)</w:t>', dotAll: true);
    final lines = <String>[];
    for (final p in paragraphs) {
      final buffer = StringBuffer();
      for (final m in textReg.allMatches(p)) {
        buffer.write(unescapeXml(m.group(1) ?? ''));
      }
      final line = buffer.toString().trim();
      if (line.isNotEmpty) lines.add(line);
    }
    return lines;
  }
}

// ============================================================
// الحضور والغياب
// ============================================================

class AttendancePage extends StatefulWidget {
  final WalidStore store;
  const AttendancePage({super.key, required this.store});
  @override
  State<AttendancePage> createState() => _AttendanceState();
}

class _AttendanceState extends State<AttendancePage> {
  DateTime selectedDate = DateTime.now();
  String get dateKey => DateFormat('yyyy-MM-dd').format(selectedDate);

  @override
  Widget build(BuildContext c) => PageShell(
        title: 'الحضور والغياب',
        icon: Icons.fact_check,
        action: 'حفظ الحضور',
        onAdd: save,
        extraActions: [
          OutlinedButton.icon(
            onPressed: copySheet,
            icon: const Icon(Icons.copy_outlined, size: 18),
            label: const Text('نسخ الكشف'),
          ),
          const SizedBox(width: 8),
        ],
        child: Column(
          children: [
            _dateBar(),
            Expanded(
              child: widget.store.students.isEmpty
                  ? const Empty(icon: Icons.groups_outlined, text: 'أضف تلاميذ أولًا.')
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      children: [
                        for (final s in widget.store.students)
                          _AttendanceRow(
                            key: ValueKey('${s.id}_$dateKey'),
                            store: widget.store,
                            student: s,
                            date: dateKey,
                          ),
                      ],
                    ),
            ),
          ],
        ),
      );

  Widget _dateBar() => Container(
        margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: 'اليوم السابق',
              icon: const Icon(Icons.chevron_right),
              onPressed: () => setState(
                () => selectedDate = selectedDate.subtract(const Duration(days: 1)),
              ),
            ),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: pickDate,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.calendar_today, size: 15, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        arabicDate(selectedDate),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'اليوم التالي',
              icon: const Icon(Icons.chevron_left),
              onPressed: () => setState(
                () => selectedDate = selectedDate.add(const Duration(days: 1)),
              ),
            ),
          ],
        ),
      );

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => selectedDate = picked);
  }

  void save() {
    widget.store.save();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حفظ الحضور بنجاح')),
    );
  }

  void copySheet() {
    final buffer = StringBuffer('كشف الحضور — ${arabicDate(selectedDate)}\n\n');
    for (final s in widget.store.students) {
      final rec = widget.store.attendance.where(
        (x) => x.studentId == s.id && x.date == dateKey,
      );
      final status = rec.isNotEmpty ? rec.first.status : 'حاضر';
      buffer.writeln('${s.name} — $status');
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم نسخ كشف الحضور — يمكنك لصقه في أي مستند للطباعة')),
    );
  }
}

class _AttendanceRow extends StatefulWidget {
  final WalidStore store;
  final Student student;
  final String date;
  const _AttendanceRow({
    super.key,
    required this.store,
    required this.student,
    required this.date,
  });
  @override
  State<_AttendanceRow> createState() => _AttendanceRowState();
}

class _AttendanceRowState extends State<_AttendanceRow> {
  String status = 'حاضر';

  @override
  void initState() {
    super.initState();
    final a = widget.store.attendance.where(
      (x) => x.studentId == widget.student.id && x.date == widget.date,
    );
    if (a.isNotEmpty) status = a.first.status;
  }

  @override
  Widget build(BuildContext c) {
    final color = AppColors.forStatus(status);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: avatarColorFor(widget.student.name),
          child: Text(
            initials(widget.student.name),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(widget.student.name),
        subtitle: Text(widget.student.section),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: status,
              icon: Icon(Icons.expand_more, color: color, size: 18),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              dropdownColor: Colors.white,
              items: const ['حاضر', 'غائب', 'متأخر', 'معذور']
                  .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                  .toList(),
              onChanged: (v) {
                setState(() => status = v!);
                widget.store.attendance.removeWhere(
                  (x) =>
                      x.studentId == widget.student.id &&
                      x.date == widget.date,
                );
                widget.store.attendance.add(
                  Attendance(
                    studentId: widget.student.id,
                    date: widget.date,
                    status: status,
                  ),
                );
                widget.store.save();
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// التقييم والنقاط
// ============================================================

class GradesPage extends StatefulWidget {
  final WalidStore store;
  const GradesPage({super.key, required this.store});
  @override
  State<GradesPage> createState() => _GradesState();
}

class _GradesState extends State<GradesPage> {
  @override
  Widget build(BuildContext c) => PageShell(
        title: 'التقييم والنقاط',
        icon: Icons.assessment,
        action: 'إضافة تقييم',
        onAdd: () => addOrEdit(c),
        child: widget.store.grades.isEmpty
            ? const Empty(icon: Icons.assessment_outlined, text: 'لا توجد تقييمات بعد.')
            : ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: [
                  for (final g in widget.store.grades)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: avatarColorFor(_name(g.studentId)),
                          child: Text(
                            initials(_name(g.studentId)),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          _name(g.studentId),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(g.activity),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (g.score >= 16)
                              const Padding(
                                padding: EdgeInsets.only(left: 6),
                                child: Icon(
                                  Icons.emoji_events_rounded,
                                  color: AppColors.gold,
                                  size: 20,
                                ),
                              ),
                            Text(
                              '${g.score.toStringAsFixed(1)}/20',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 17,
                              ),
                            ),
                            rowMenu(
                              onEdit: () => addOrEdit(c, existing: g),
                              onDelete: () => confirm(
                                c,
                                'حذف هذا التقييم؟',
                                () {
                                  widget.store.grades.remove(g);
                                  widget.store.save();
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      );

  String _name(String id) => widget.store.students
      .firstWhere(
        (s) => s.id == id,
        orElse: () => Student(id: '', name: 'غير معروف', section: ''),
      )
      .name;

  Future<void> addOrEdit(BuildContext c, {Grade? existing}) async {
    if (widget.store.students.isEmpty) {
      ScaffoldMessenger.of(c).showSnackBar(
        const SnackBar(content: Text('أضف تلاميذ أولًا')),
      );
      return;
    }
    final presetTitles = ActivitiesPage.activities.map((a) => a.title).toList();
    String st = existing?.studentId ?? widget.store.students.first.id;
    String actChoice =
        (existing != null && !presetTitles.contains(existing.activity))
            ? 'أخرى'
            : (existing?.activity ?? presetTitles.first);
    final customCtrl = TextEditingController(
      text: (existing != null && !presetTitles.contains(existing.activity))
          ? existing.activity
          : '',
    );
    final score = TextEditingController(
      text: existing == null ? '' : existing.score.toString(),
    );
    await showDialog(
      context: c,
      builder: (_) => StatefulBuilder(
        builder: (c2, setD) => AlertDialog(
          title: Text(existing == null ? 'إضافة تقييم' : 'تعديل التقييم'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: st,
                items: widget.store.students
                    .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
                    .toList(),
                onChanged: (v) => setD(() => st = v!),
                decoration: const InputDecoration(labelText: 'التلميذ'),
              ),
              TextField(
                controller: score,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'النقطة / 20'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: actChoice,
                items: [
                  for (final a in ActivitiesPage.activities)
                    DropdownMenuItem(
                      value: a.title,
                      child: Text('${a.title} (${a.term})'),
                    ),
                  const DropdownMenuItem(value: 'أخرى', child: Text('نشاط آخر...')),
                ],
                onChanged: (v) => setD(() => actChoice = v!),
                decoration: const InputDecoration(labelText: 'النشاط'),
              ),
              if (actChoice == 'أخرى') ...[
                const SizedBox(height: 10),
                TextField(
                  controller: customCtrl,
                  decoration: const InputDecoration(labelText: 'اسم النشاط'),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c2),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                final x = double.tryParse(score.text);
                final actText =
                    actChoice == 'أخرى' ? customCtrl.text.trim() : actChoice;
                if (x == null || x < 0 || x > 20 || actText.isEmpty) return;
                if (existing == null) {
                  widget.store.grades.add(
                    Grade(studentId: st, activity: actText, score: x),
                  );
                } else {
                  existing.studentId = st;
                  existing.activity = actText;
                  existing.score = x;
                }
                widget.store.save();
                Navigator.pop(c2);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// الأنشطة
// ============================================================

class ActivityInfo {
  final String term, title;
  final IconData icon;
  const ActivityInfo(this.term, this.title, this.icon);
}

class ActivitiesPage extends StatelessWidget {
  const ActivitiesPage({super.key});

  static const activities = [
    ActivityInfo('الفصل الأول', 'كرة اليد مع السرعة', Icons.sports_handball),
    ActivityInfo('الفصل الثاني', 'كرة السلة مع دفع الجلة', Icons.sports_basketball),
    ActivityInfo('الفصل الثالث', 'كرة الطائرة مع القفز الطويل', Icons.sports_volleyball),
  ];

  @override
  Widget build(BuildContext c) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'الأنشطة الرياضية',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'البرنامج السنوي موزّع على الفصول الثلاثة',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 20),
          for (final a in activities)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.accent],
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(a.icon, color: Colors.white),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.term,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          a.title,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
}

// ============================================================
// مذكراتي
// ============================================================

class NotebooksPage extends StatefulWidget {
  final WalidStore store;
  const NotebooksPage({super.key, required this.store});
  @override
  State<NotebooksPage> createState() => _NotebooksState();
}

class _NotebooksState extends State<NotebooksPage> {
  int tab = 0;
  bool busy = false;
  final labels = [
    'البرنامج السنوي',
    'التوزيع السنوي',
    'الفصل الأول',
    'الفصل الثاني',
    'الفصل الثالث',
  ];
  late final List<TextEditingController> controllers;

  List<NotebookEntry> get _entries => [
        widget.store.yearlyProgram,
        widget.store.yearlyDistribution,
        widget.store.term1Notebook,
        widget.store.term2Notebook,
        widget.store.term3Notebook,
      ];

  void _setEntry(int i, NotebookEntry e) {
    switch (i) {
      case 0:
        widget.store.yearlyProgram = e;
        break;
      case 1:
        widget.store.yearlyDistribution = e;
        break;
      case 2:
        widget.store.term1Notebook = e;
        break;
      case 3:
        widget.store.term2Notebook = e;
        break;
      case 4:
        widget.store.term3Notebook = e;
        break;
    }
  }

  @override
  void initState() {
    super.initState();
    controllers = [for (final e in _entries) TextEditingController(text: e.text)];
  }

  @override
  void dispose() {
    for (final c in controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    for (var i = 0; i < labels.length; i++) {
      final current = _entries[i];
      _setEntry(
        i,
        NotebookEntry(
          text: controllers[i].text,
          fileName: current.fileName,
          filePath: current.filePath,
        ),
      );
    }
    widget.store.save();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم الحفظ')),
      );
    }
  }

  Future<void> _attachFile(int i) async {
    setState(() => busy = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final picked = result.files.single;
      final bytes = picked.bytes;
      if (bytes == null) {
        _toast('تعذّرت قراءة الملف');
        return;
      }
      final dir = await getApplicationDocumentsDirectory();
      final ext = picked.name.contains('.') ? picked.name.split('.').last : 'pdf';
      final savePath = '${dir.path}/notebook_$i.$ext';
      await File(savePath).writeAsBytes(bytes);
      setState(() {
        _setEntry(
          i,
          NotebookEntry(
            text: _entries[i].text,
            fileName: picked.name,
            filePath: savePath,
          ),
        );
      });
      widget.store.save();
      _toast('تم إرفاق الملف بنجاح');
    } catch (_) {
      _toast('حدث خطأ أثناء إرفاق الملف');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _openFile(int i) async {
    final path = _entries[i].filePath;
    if (path == null) return;
    final result = await OpenFilex.open(path);
    if (result.type != ResultType.done) {
      _toast('تعذّر فتح الملف: ${result.message}');
    }
  }

  void _removeFile(int i) {
    final path = _entries[i].filePath;
    if (path != null) {
      try {
        File(path).deleteSync();
      } catch (_) {}
    }
    setState(() {
      _setEntry(i, NotebookEntry(text: _entries[i].text));
    });
    widget.store.save();
  }

  void _toast(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext c) {
    final entry = _entries[tab];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.menu_book_rounded, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'مذكراتي',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
              ),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('حفظ'),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (int i = 0; i < labels.length; i++)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: ChoiceChip(
                    label: Text(labels[i]),
                    selected: tab == i,
                    onSelected: (_) => setState(() => tab = i),
                    selectedColor: AppColors.primary,
                    backgroundColor: Colors.white,
                    labelStyle: TextStyle(
                      color: tab == i ? Colors.white : AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Divider(height: 1),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  onPressed: busy ? null : () => _attachFile(tab),
                  icon: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.attach_file, size: 18),
                  label: Text(
                    entry.fileName == null
                        ? 'إرفاق ملف Word / PDF'
                        : 'استبدال الملف المرفق',
                  ),
                ),
                if (entry.fileName != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE7ECEF)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.description_outlined,
                          color: AppColors.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            entry.fileName!,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _openFile(tab),
                          child: const Text('فتح'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => _removeFile(tab),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Expanded(
                  child: TextField(
                    key: ValueKey(tab),
                    controller: controllers[tab],
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    decoration: const InputDecoration(
                      hintText: 'اكتب أو الصق ملاحظات إضافية هنا (اختياري)...',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// التقارير
// ============================================================

class ReportsPage extends StatelessWidget {
  final WalidStore store;
  const ReportsPage({super.key, required this.store});

  List<MapEntry<Student, double>> get _ranked {
    final entries = <MapEntry<Student, double>>[];
    for (final s in store.students) {
      final avg = averageFor(store, s.id);
      if (avg != null) entries.add(MapEntry(s, avg));
    }
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  @override
  Widget build(BuildContext c) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'التقارير',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 20),
          _reportCard(
            Icons.groups,
            'تقرير التلاميذ',
            '${store.students.length} تلميذ في ${store.sections.length} قسم',
          ),
          _reportCard(
            Icons.assessment,
            'ملخص التقييمات',
            '${store.grades.length} تقييم مسجل',
          ),
          _reportCard(
            Icons.fact_check,
            'ملخص الحضور',
            '${store.attendance.length} سجل حضور',
          ),
          if (_ranked.isNotEmpty) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'معدلات التلاميذ',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _copySheet(c),
                  icon: const Icon(Icons.copy_outlined, size: 16),
                  label: const Text('نسخ الكشف'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final e in _ranked)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: avatarColorFor(e.key.name),
                    child: Text(
                      initials(e.key.name),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(e.key.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(e.key.section),
                  trailing: Text(
                    e.value.toStringAsFixed(1),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
          ],
        ],
      );

  void _copySheet(BuildContext c) {
    final buffer = StringBuffer('كشف معدلات التلاميذ — WALID\n\n');
    for (final e in _ranked) {
      buffer.writeln('${e.key.name} (${e.key.section}) — ${e.value.toStringAsFixed(1)}/20');
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(c).showSnackBar(
      const SnackBar(content: Text('تم نسخ الكشف — يمكنك لصقه في أي مستند للطباعة')),
    );
  }

  Widget _reportCard(IconData icon, String title, String subtitle) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(subtitle),
        ),
      );
}

// ============================================================
// الإعدادات
// ============================================================

class SettingsPage extends StatelessWidget {
  final WalidStore store;
  const SettingsPage({super.key, required this.store});

  @override
  Widget build(BuildContext c) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'الإعدادات',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 15),
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const ListTile(
              title: Text('WALID'),
              subtitle: Text('نظام إدارة التربية البدنية والرياضية'),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              leading: const Icon(Icons.delete_forever, color: AppColors.absent),
              title: const Text('مسح جميع البيانات'),
              onTap: () => confirm(
                c,
                'سيتم حذف جميع البيانات نهائيًا. متابعة؟',
                () {
                  store.sections.clear();
                  store.students.clear();
                  store.attendance.clear();
                  store.grades.clear();
                  store.save();
                },
              ),
            ),
          ),
        ],
      );
}

// ============================================================
// عناصر مشتركة
// ============================================================

class PageShell extends StatelessWidget {
  final String title, action;
  final IconData icon;
  final VoidCallback onAdd;
  final Widget child;
  final List<Widget> extraActions;
  const PageShell({
    super.key,
    required this.title,
    required this.icon,
    required this.action,
    required this.onAdd,
    required this.child,
    this.extraActions = const [],
  });

  @override
  Widget build(BuildContext c) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                ),
                ...extraActions,
                FilledButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add),
                  label: Text(action),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: child),
        ],
      );
}

class Empty extends StatelessWidget {
  final IconData icon;
  final String text;
  const Empty({super.key, this.icon = Icons.inbox_outlined, this.text = 'لا توجد بيانات بعد.'});

  @override
  Widget build(BuildContext c) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 46, color: Colors.black26),
            const SizedBox(height: 10),
            Text(text, style: const TextStyle(color: Colors.black54)),
          ],
        ),
      );
}

Widget rowMenu({required VoidCallback onEdit, required VoidCallback onDelete}) {
  return PopupMenuButton<String>(
    icon: const Icon(Icons.more_vert),
    onSelected: (v) {
      if (v == 'edit') onEdit();
      if (v == 'delete') onDelete();
    },
    itemBuilder: (_) => [
      const PopupMenuItem(
        value: 'edit',
        child: Row(
          children: [
            Icon(Icons.edit_outlined, size: 18),
            SizedBox(width: 8),
            Text('تعديل'),
          ],
        ),
      ),
      const PopupMenuItem(
        value: 'delete',
        child: Row(
          children: [
            Icon(Icons.delete_outline, size: 18, color: AppColors.absent),
            SizedBox(width: 8),
            Text('حذف', style: TextStyle(color: AppColors.absent)),
          ],
        ),
      ),
    ],
  );
}

void confirm(BuildContext c, String title, VoidCallback yes) {
  showDialog(
    context: c,
    builder: (_) => AlertDialog(
      title: Text(title),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(c);
            yes();
          },
          child: const Text('تأكيد'),
        ),
      ],
    ),
  );
}
