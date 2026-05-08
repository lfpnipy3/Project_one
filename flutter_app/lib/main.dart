import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'dart:async';

void main() => runApp(const MyApp());

// Глобальные переменные для текущего пользователя
String? currentUserId;
int? currentUserRole;
int? currentUserPckId;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Управление',
      debugShowCheckedModeBanner: false,
      home: const AuthPage(),
    );
  }
}

// ЭКРАН ВХОДА
class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final TextEditingController _login = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final Dio _dio = Dio(BaseOptions(baseUrl: "http://127.0.0.1:5234"));
  bool _loading = false;

  void _doLogin() async {
    setState(() => _loading = true);
    try {
      var res = await _dio.post('/login', queryParameters: {
        'username': _login.text,
        'password': _password.text,
      });
      if (res.statusCode == 200) {
        currentUserId = res.data['id'];
        currentUserRole = res.data['role_Id'];
        currentUserPckId = res.data['pck_Id'];
        
        if (mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AdminPage()));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ошибка входа')));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          width: 350,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.admin_panel_settings, size: 80),
              const SizedBox(height: 20),
              TextField(controller: _login, decoration: const InputDecoration(labelText: 'Логин', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'Пароль', border: OutlineInputBorder())),
              const SizedBox(height: 20),
              _loading ? const CircularProgressIndicator() : ElevatedButton(onPressed: _doLogin, child: const Text('Войти')),
            ],
          ),
        ),
      ),
    );
  }
}

// ГЛАВНАЯ АДМИНКА
class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final Dio _dio = Dio(BaseOptions(baseUrl: "http://127.0.0.1:5234"));
  String _currentTable = 'Roles';
  List _data = [];
  bool _loading = false;
  Timer? _refreshTimer;
  
  Map<String, List> _referenceData = {};
  
  List<String> get _availableTables {
    if (currentUserRole == 1) {
      return [
        'Roles', 'Users', 'PCK', 'Positions', 'Degrees', 'Employments',
        'Specialties', 'Curriculums', 'Groups', 'DisciplineCycles', 
        'Disciplines', 'CurriculumLoad', 'Teachers', 'AcademicYears',
        'GroupAcademicYears', 'ActualLoad'
      ];
    } else if (currentUserRole == 2) {
      return ['Teachers', 'Disciplines', 'Groups', 'CurriculumLoad', 'ActualLoad'];
    } else {
      return ['Teachers', 'Groups', 'Disciplines', 'ActualLoad'];
    }
  }
  
  bool get canEdit => currentUserRole == 1 || currentUserRole == 2;
  bool get canCreate => currentUserRole == 1 || currentUserRole == 2;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadAllReferences();
    
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _refreshAllData();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshAllData() async {
    await _loadAllReferences();
    await _loadData();
  }

  Future<void> _loadAllReferences() async {
    try {
      final results = await Future.wait([
        _dio.get('/roles'),
        _dio.get('/pck'),
        _dio.get('/positions'),
        _dio.get('/degrees'),
        _dio.get('/employments'),
        _dio.get('/specialties'),
        _dio.get('/curriculums'),
        _dio.get('/groups'),
        _dio.get('/discipline-cycles'),
        _dio.get('/disciplines'),
        _dio.get('/curriculum-load'),
        _dio.get('/teachers'),
        _dio.get('/academic-years'),
        _dio.get('/users'),
      ]);
      
      if (mounted) {
        setState(() {
          _referenceData['roles'] = results[0].data;
          _referenceData['pck'] = results[1].data;
          _referenceData['positions'] = results[2].data;
          _referenceData['degrees'] = results[3].data;
          _referenceData['employments'] = results[4].data;
          _referenceData['specialties'] = results[5].data;
          _referenceData['curriculums'] = results[6].data;
          _referenceData['groups'] = results[7].data;
          _referenceData['cycles'] = results[8].data;
          _referenceData['disciplines'] = results[9].data;
          _referenceData['loads'] = results[10].data;
          _referenceData['teachers'] = results[11].data;
          _referenceData['academicYears'] = results[12].data;
          _referenceData['users'] = results[13].data;
        });
      }
    } catch (e) {
      print('Ошибка загрузки справочников: $e');
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      await _loadAllReferences();
      
      String tableName = _getTableNameForApi(_currentTable);
      var res = await _dio.get('/$tableName');
      
      var filteredData = res.data;
      if (currentUserRole == 2 && _referenceData['disciplines'] != null) {
        if (_currentTable == 'Teachers') {
          filteredData = res.data.where((t) => t['pck_Id'] == currentUserPckId).toList();
        }
        else if (_currentTable == 'Disciplines') {
          filteredData = res.data.where((d) => d['pck_Id'] == currentUserPckId).toList();
        }
        else if (_currentTable == 'CurriculumLoad') {
          filteredData = res.data.where((l) {
            var discipline = _referenceData['disciplines']?.firstWhere(
              (d) => d['id_Discipline'] == l['discipline_Id'],
              orElse: () => null
            );
            return discipline != null && discipline['pck_Id'] == currentUserPckId;
          }).toList();
        }
        else if (_currentTable == 'ActualLoad') {
          filteredData = res.data.where((a) {
            var teacher = _referenceData['teachers']?.firstWhere(
              (t) => t['id_Teacher'] == a['teacher_Id'],
              orElse: () => null
            );
            return teacher != null && teacher['pck_Id'] == currentUserPckId;
          }).toList();
        }
      }
      
      if (mounted) setState(() => _data = filteredData);
    } catch (e) {
      print('Ошибка загрузки: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки: $_currentTable'), backgroundColor: Colors.red)
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  String _getTableNameForApi(String table) {
    switch (table) {
      case 'PCK': return 'pck';
      case 'DisciplineCycles': return 'discipline-cycles';
      case 'CurriculumLoad': return 'curriculum-load';
      case 'AcademicYears': return 'academic-years';
      case 'GroupAcademicYears': return 'group-academic-years';
      case 'ActualLoad': return 'actual-load';
      default: return table.toLowerCase();
    }
  }

  String _getRussianName(String table) {
    switch (table) {
      case 'Roles': return 'ролей';
      case 'Users': return 'пользователей';
      case 'PCK': return 'предметно-цикловых комиссий';
      case 'Positions': return 'должностей';
      case 'Degrees': return 'ученых степеней';
      case 'Employments': return 'видов занятости';
      case 'Specialties': return 'специальностей';
      case 'Curriculums': return 'учебных планов';
      case 'Groups': return 'групп';
      case 'DisciplineCycles': return 'циклов дисциплин';
      case 'Disciplines': return 'дисциплин';
      case 'CurriculumLoad': return 'нагрузки по плану';
      case 'Teachers': return 'преподавателей';
      case 'AcademicYears': return 'учебных годов';
      case 'GroupAcademicYears': return 'связей групп с годами';
      case 'ActualLoad': return 'фактической нагрузки';
      default: return table;
    }
  }

  void _addItem() {
    switch (_currentTable) {
      case 'Roles':
        _showSimpleForm({'role_Name': 'Название роли'});
        break;
      case 'Users':
        _showUserForm();
        break;
      case 'Positions':
        _showSimpleForm({'position_Name': 'Название должности'});
        break;
      case 'Degrees':
        _showSimpleForm({'degree_Name': 'Название степени'});
        break;
      case 'Employments':
        _showSimpleForm({'employment_Name': 'Название занятости', 'format': 'Формат'});
        break;
      case 'DisciplineCycles':
        _showSimpleForm({
          'full_Cycle_Name': 'Полное название цикла',
          'short_Cycle_Name': 'Краткое название',
          'discipline_Group': 'Группа дисциплин'
        });
        break;
      case 'AcademicYears':
        _showSimpleForm({'start_Year': 'Год начала'});
        break;
      case 'Specialties':
        _showSimpleForm({
          'full_Name_Specialty': 'Полное название',
          'short_Name_Specialty': 'Краткое название'
        });
        break;
      case 'PCK':
        _showPCKForm();
        break;
      case 'Groups':
        _showGroupForm();
        break;
      case 'Curriculums':
        _showCurriculumForm();
        break;
      case 'Disciplines':
        _showDisciplineForm();
        break;
      case 'CurriculumLoad':
        _showCurriculumLoadForm();
        break;
      case 'Teachers':
        _showTeacherForm();
        break;
      case 'GroupAcademicYears':
        _showGroupAcademicYearForm();
        break;
      case 'ActualLoad':
        _showActualLoadForm();
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Добавление для $_currentTable в разработке'))
        );
        break;
    }
  }

  void _showPCKForm({Map? existingItem}) {
    bool isEdit = existingItem != null;
    TextEditingController fullNameCtrl = TextEditingController(text: isEdit ? existingItem['full_PCK_Name'] ?? '' : '');
    TextEditingController shortNameCtrl = TextEditingController(text: isEdit ? existingItem['short_PCK_Name'] ?? '' : '');
    
    String? selectedManagerId = isEdit ? existingItem['manager_Id']?.toString() : null;
    List usersList = _referenceData['users'] ?? [];
    List managerCandidates = usersList.where((u) => u['role_Id'] == 1 || u['role_Id'] == 2).toList();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: Text('${isEdit ? 'Изменить' : 'Добавить'} ПЦК'),
          content: SizedBox(
            width: 450,
            height: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: fullNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Полное название ПЦК',
                    border: OutlineInputBorder(),
                    hintText: 'Программирования и информационных технологий'
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: shortNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Краткое название ПЦК',
                    border: OutlineInputBorder(),
                    hintText: 'ПИТ'
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Руководитель ПЦК',
                    border: OutlineInputBorder(),
                  ),
                  value: selectedManagerId,
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('-- Не выбран --'),
                    ),
                    ...managerCandidates.map((u) => DropdownMenuItem<String>(
                      value: u['id'].toString(),
                      child: Text('${u['username']} (${u['role_Id'] == 1 ? "Администратор" : "Зав. отделением"})'),
                    )).toList(),
                  ],
                  onChanged: (val) => setStateDialog(() => selectedManagerId = val),
                ),
                const SizedBox(height: 10),
                if (managerCandidates.isEmpty)
                  Text(
                    'ВНИМАНИЕ: Нет доступных пользователей для назначения руководителем. Сначала создайте пользователя с ролью "Администратор" или "Зав. отделением".',
                    style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (fullNameCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Введите полное название ПЦК'), backgroundColor: Colors.red)
                  );
                  return;
                }
                if (shortNameCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Введите краткое название ПЦК'), backgroundColor: Colors.red)
                  );
                  return;
                }
                
                Map<String, dynamic> data = {
                  'full_PCK_Name': fullNameCtrl.text,
                  'short_PCK_Name': shortNameCtrl.text,
                  'manager_Id': selectedManagerId,
                };
                
                String tableName = _getTableNameForApi(_currentTable);
                try {
                  if (isEdit) {
                    await _dio.put('/$tableName/${existingItem!['id_PCK']}', data: data);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('ПЦК изменен!'), backgroundColor: Colors.green)
                    );
                  } else {
                    await _dio.post('/$tableName', data: data);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('ПЦК добавлен!'), backgroundColor: Colors.green)
                    );
                  }
                  if (mounted) {
                    Navigator.pop(ctx);
                    await _refreshAllData();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red)
                    );
                  }
                }
              },
              child: Text(isEdit ? 'Сохранить' : 'Добавить'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSimpleForm(Map<String, String> fields, {Map? existingItem}) {
    bool isEdit = existingItem != null;
    Map<String, TextEditingController> controllers = {};
    fields.forEach((key, label) {
      controllers[key] = TextEditingController(text: isEdit ? existingItem[key]?.toString() ?? '' : '');
    });

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${isEdit ? 'Изменить' : 'Добавить'} в ${_getRussianName(_currentTable)}'),
        content: SizedBox(
          width: 500,
          height: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: fields.entries.map((e) => Padding(
                padding: const EdgeInsets.all(8),
                child: TextField(
                  controller: controllers[e.key],
                  decoration: InputDecoration(labelText: e.value, border: const OutlineInputBorder()),
                ),
              )).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () async {
              Map<String, dynamic> data = {};
              for (var entry in fields.entries) {
                String key = entry.key;
                String val = controllers[key]!.text;
                if (key == 'start_Year' || key == 'year_Approved') {
                  data[key] = int.tryParse(val) ?? 0;
                } else {
                  data[key] = val;
                }
              }
              
              String tableName = _getTableNameForApi(_currentTable);
              try {
                if (isEdit) {
                  String id = '';
                  if (existingItem!.containsKey('id_Role')) id = existingItem['id_Role'].toString();
                  else if (existingItem.containsKey('id')) id = existingItem['id'].toString();
                  else if (existingItem.containsKey('id_Position')) id = existingItem['id_Position'].toString();
                  else if (existingItem.containsKey('id_Degree')) id = existingItem['id_Degree'].toString();
                  else if (existingItem.containsKey('id_Employment')) id = existingItem['id_Employment'].toString();
                  else if (existingItem.containsKey('id_Specialty')) id = existingItem['id_Specialty'].toString();
                  else if (existingItem.containsKey('id_UP')) id = existingItem['id_UP'].toString();
                  else if (existingItem.containsKey('id_Group')) id = existingItem['id_Group'].toString();
                  else if (existingItem.containsKey('id_Cycle')) id = existingItem['id_Cycle'].toString();
                  else if (existingItem.containsKey('id_Discipline')) id = existingItem['id_Discipline'].toString();
                  else if (existingItem.containsKey('id_AcademicYear')) id = existingItem['id_AcademicYear'].toString();
                  
                  if (id.isNotEmpty) {
                    await _dio.put('/$tableName/$id', data: data);
                    if (mounted) {
                      Navigator.pop(ctx);
                      await _refreshAllData();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Изменено!'), backgroundColor: Colors.green)
                      );
                    }
                  }
                } else {
                  await _dio.post('/$tableName', data: data);
                  if (mounted) {
                    Navigator.pop(ctx);
                    await _refreshAllData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Добавлено!'), backgroundColor: Colors.green)
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red)
                  );
                }
              }
            },
            child: Text(isEdit ? 'Сохранить' : 'Добавить'),
          ),
        ],
      ),
    );
  }

  void _showUserForm({Map? existingItem}) {
    if (currentUserRole != 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Только администратор может создавать пользователей'), backgroundColor: Colors.red)
      );
      return;
    }
    
    bool isEdit = existingItem != null;
    TextEditingController usernameCtrl = TextEditingController(text: isEdit ? existingItem['username'] ?? '' : '');
    TextEditingController passwordCtrl = TextEditingController(text: '');
    
    int? selectedRoleId = isEdit ? existingItem['role_Id'] : null;
    int? selectedPckId = isEdit ? existingItem['pck_Id'] : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: Text('${isEdit ? 'Изменить' : 'Добавить'} пользователя'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: usernameCtrl, decoration: const InputDecoration(labelText: 'Логин', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                if (!isEdit) TextField(controller: passwordCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Пароль', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(labelText: 'Роль', border: OutlineInputBorder()),
                  value: selectedRoleId,
                  items: _referenceData['roles']?.map((r) => DropdownMenuItem<int>(
                    value: r['id_Role'],
                    child: Text(r['role_Name']),
                  )).toList(),
                  onChanged: (val) => setStateDialog(() => selectedRoleId = val),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(labelText: 'ПЦК', border: OutlineInputBorder()),
                  value: selectedPckId,
                  items: [
                    const DropdownMenuItem<int>(value: null, child: Text('-- Не выбран --')),
                    ...(_referenceData['pck']?.map((p) => DropdownMenuItem<int>(
                      value: p['id_PCK'],
                      child: Text(p['short_PCK_Name'] ?? p['full_PCK_Name']),
                    )).toList() ?? []),
                  ],
                  onChanged: (val) => setStateDialog(() => selectedPckId = val),
                ),
                const SizedBox(height: 10),
                Text(
                  'ВНИМАНИЕ: Для роли "Преподаватель" лучше использовать форму добавления преподавателя',
                  style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
            ElevatedButton(
              onPressed: () async {
                Map<String, dynamic> data = {
                  'username': usernameCtrl.text,
                  'role_Id': selectedRoleId ?? 0,
                  'pck_Id': selectedPckId,
                  'createdBy': currentUserId,
                };
                if (!isEdit) {
                  data['password'] = passwordCtrl.text;
                }
                
                String tableName = _getTableNameForApi(_currentTable);
                
                try {
                  if (isEdit) {
                    await _dio.put('/$tableName/${existingItem!['id']}', data: data);
                  } else {
                    await _dio.post('/$tableName', data: data);
                  }
                  
                  if (mounted) {
                    Navigator.pop(ctx);
                    await _refreshAllData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(isEdit ? 'Пользователь изменен!' : 'Пользователь добавлен!'), backgroundColor: Colors.green)
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red)
                    );
                  }
                }
              },
              child: Text(isEdit ? 'Сохранить' : 'Добавить'),
            ),
          ],
        ),
      ),
    );
  }

  void _showTeacherForm({Map? existingItem}) {
    bool isEdit = existingItem != null;
    TextEditingController fioCtrl = TextEditingController(text: isEdit ? existingItem['fio'] ?? '' : '');
    TextEditingController knCtrl = TextEditingController(text: isEdit ? existingItem['kN_Number']?.toString() ?? '' : '');
    TextEditingController categoryCtrl = TextEditingController(text: isEdit ? existingItem['category'] ?? '' : '');
    TextEditingController usernameCtrl = TextEditingController(text: '');
    TextEditingController passwordCtrl = TextEditingController(text: '');
    
    bool hasHigherEducation = isEdit ? (existingItem['has_Higher_Education'] == true) : false;
    
    List pckList = _referenceData['pck'] ?? [];
    if (currentUserRole == 2 && currentUserPckId != null) {
      pckList = pckList.where((p) => p['id_PCK'] == currentUserPckId).toList();
    }
    
    int? selectedPckId = isEdit ? existingItem['pck_Id'] : 
        (currentUserRole == 2 && pckList.isNotEmpty ? currentUserPckId : null);
    int? selectedPositionId = isEdit ? existingItem['position_Id'] : null;
    int? selectedDegreeId = isEdit ? existingItem['degree_Id'] : null;
    int? selectedEmploymentId = isEdit ? existingItem['employment_Id'] : null;
    
    String? selectedExistingUserId = null;
    List usersList = _referenceData['users'] ?? [];
    List teacherUsersList = usersList.where((u) => u['role_Id'] == 3).toList();
    
    bool createNewUser = !isEdit && currentUserRole == 1;
    
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) {
          return AlertDialog(
            title: Text('${isEdit ? 'Изменить' : 'Добавить'} преподавателя'),
            content: SizedBox(
              width: 500,
              height: isEdit ? 550 : (currentUserRole == 1 ? 700 : 550),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: fioCtrl, decoration: const InputDecoration(labelText: 'ФИО', border: OutlineInputBorder())),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      decoration: const InputDecoration(labelText: 'ПЦК', border: OutlineInputBorder()),
                      value: selectedPckId,
                      items: pckList.map((p) => DropdownMenuItem<int>(
                        value: p['id_PCK'],
                        child: Text(p['short_PCK_Name'] ?? p['full_PCK_Name']),
                      )).toList(),
                      onChanged: (currentUserRole == 1) ? (val) => setStateDialog(() => selectedPckId = val) : null,
                    ),
                    const SizedBox(height: 10),
                    TextField(controller: knCtrl, decoration: const InputDecoration(labelText: 'Номер КН', border: OutlineInputBorder())),
                    const SizedBox(height: 10),
                    TextField(controller: categoryCtrl, decoration: const InputDecoration(labelText: 'Категория', border: OutlineInputBorder())),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      decoration: const InputDecoration(labelText: 'Должность', border: OutlineInputBorder()),
                      value: selectedPositionId,
                      items: [
                        const DropdownMenuItem<int>(value: null, child: Text('-- Не выбрана --')),
                        ...(_referenceData['positions']?.map((p) => DropdownMenuItem<int>(
                          value: p['id_Position'],
                          child: Text(p['position_Name']),
                        )).toList() ?? []),
                      ],
                      onChanged: (val) => setStateDialog(() => selectedPositionId = val),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      decoration: const InputDecoration(labelText: 'Ученая степень', border: OutlineInputBorder()),
                      value: selectedDegreeId,
                      items: [
                        const DropdownMenuItem<int>(value: null, child: Text('-- Не выбрана --')),
                        ...(_referenceData['degrees']?.map((d) => DropdownMenuItem<int>(
                          value: d['id_Degree'],
                          child: Text(d['degree_Name']),
                        )).toList() ?? []),
                      ],
                      onChanged: (val) => setStateDialog(() => selectedDegreeId = val),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      decoration: const InputDecoration(labelText: 'Занятость', border: OutlineInputBorder()),
                      value: selectedEmploymentId,
                      items: [
                        const DropdownMenuItem<int>(value: null, child: Text('-- Не выбрана --')),
                        ...(_referenceData['employments']?.map((e) => DropdownMenuItem<int>(
                          value: e['id_Employment'],
                          child: Text(e['employment_Name']),
                        )).toList() ?? []),
                      ],
                      onChanged: (val) => setStateDialog(() => selectedEmploymentId = val),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Checkbox(
                          value: hasHigherEducation,
                          onChanged: (val) => setStateDialog(() => hasHigherEducation = val ?? false),
                        ),
                        const Text('Высшее образование'),
                      ],
                    ),
                    
                    if (currentUserRole == 1 && !isEdit) ...[
                      const Divider(height: 20, thickness: 1),
                      const Text('Создание пользователя для преподавателя:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                setStateDialog(() {
                                  createNewUser = false;
                                  usernameCtrl.clear();
                                  passwordCtrl.clear();
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: !createNewUser ? Colors.blue : Colors.grey,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Выбрать существующего'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                setStateDialog(() {
                                  createNewUser = true;
                                  selectedExistingUserId = null;
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: createNewUser ? Colors.blue : Colors.grey,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Создать нового'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (!createNewUser) ...[
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(labelText: 'Выберите пользователя', border: OutlineInputBorder()),
                          value: selectedExistingUserId,
                          items: teacherUsersList.map((u) => DropdownMenuItem<String>(
                            value: u['id'].toString(),
                            child: Text(u['username']),
                          )).toList(),
                          onChanged: (val) => setStateDialog(() => selectedExistingUserId = val),
                        ),
                        const SizedBox(height: 10),
                        Text('ВНИМАНИЕ: Пользователь должен иметь роль "Преподаватель"', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      ],
                      if (createNewUser) ...[
                        TextField(controller: usernameCtrl, decoration: const InputDecoration(labelText: 'Логин для входа', border: OutlineInputBorder(), hintText: 'ivanov.teacher')),
                        const SizedBox(height: 10),
                        TextField(controller: passwordCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Пароль', border: OutlineInputBorder(), hintText: 'пароль123')),
                        const SizedBox(height: 10),
                        Text('Будет создан новый пользователь с ролью "Преподаватель"', style: TextStyle(fontSize: 12, color: Colors.green)),
                      ],
                    ],
                    
                    if (currentUserRole == 2 && !isEdit) ...[
                      const Divider(height: 20, thickness: 1),
                      const Text('Создание пользователя для преподавателя:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      TextField(controller: usernameCtrl, decoration: const InputDecoration(labelText: 'Логин для входа', border: OutlineInputBorder(), hintText: 'ivanov.teacher')),
                      const SizedBox(height: 10),
                      TextField(controller: passwordCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Пароль', border: OutlineInputBorder(), hintText: 'пароль123')),
                      const SizedBox(height: 10),
                      Text('Пользователь будет создан автоматически и привязан к вашему ПЦК', style: TextStyle(fontSize: 12, color: Colors.green)),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
              ElevatedButton(
                onPressed: () async {
                  try {
                    String? userId;
                    
                    if (isEdit) {
                      userId = existingItem!['user_Id'].toString();
                    } 
                    else if (currentUserRole == 1) {
                      if (!createNewUser && selectedExistingUserId != null) {
                        userId = selectedExistingUserId;
                      } else if (createNewUser && usernameCtrl.text.isNotEmpty && passwordCtrl.text.isNotEmpty) {
                        var userData = {
                          'username': usernameCtrl.text,
                          'password': passwordCtrl.text,
                          'role_Id': 3,
                          'pck_Id': selectedPckId,
                          'createdBy': currentUserId,
                        };
                        var userResponse = await _dio.post('/users', data: userData);
                        userId = userResponse.data['id']?.toString();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Необходимо выбрать пользователя или создать нового'), backgroundColor: Colors.red),
                        );
                        return;
                      }
                    } 
                    else if (currentUserRole == 2) {
                      if (usernameCtrl.text.isEmpty || passwordCtrl.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Необходимо заполнить логин и пароль'), backgroundColor: Colors.red),
                        );
                        return;
                      }
                      var userData = {
                        'username': usernameCtrl.text,
                        'password': passwordCtrl.text,
                        'role_Id': 3,
                        'pck_Id': selectedPckId ?? currentUserPckId,
                        'createdBy': currentUserId,
                      };
                      var userResponse = await _dio.post('/users', data: userData);
                      userId = userResponse.data['id']?.toString();
                    } 
                    else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('У вас нет прав на создание преподавателей')));
                      return;
                    }
                    
                    if (userId == null || userId.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ошибка: не удалось создать/найти пользователя')));
                      return;
                    }
                    
                    Map<String, dynamic> teacherData = {
                      'user_Id': userId,
                      'fio': fioCtrl.text,
                      'pck_Id': selectedPckId ?? 0,
                      'kN_Number': int.tryParse(knCtrl.text),
                      'category': categoryCtrl.text.isEmpty ? null : categoryCtrl.text,
                      'position_Id': selectedPositionId,
                      'degree_Id': selectedDegreeId,
                      'employment_Id': selectedEmploymentId,
                      'has_Higher_Education': hasHigherEducation,
                      'createdBy': currentUserId,
                    };
                    
                    String tableName = _getTableNameForApi(_currentTable);
                    
                    if (isEdit) {
                      await _dio.put('/$tableName/${existingItem!['id_Teacher']}', data: teacherData);
                      if (mounted) {
                        Navigator.pop(ctx);
                        await _refreshAllData();
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Преподаватель изменен!'), backgroundColor: Colors.green));
                      }
                    } else {
                      await _dio.post('/$tableName', data: teacherData);
                      if (mounted) {
                        Navigator.pop(ctx);
                        await _refreshAllData();
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Преподаватель добавлен!'), backgroundColor: Colors.green));
                      }
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red));
                    }
                  }
                },
                child: Text(isEdit ? 'Сохранить' : 'Добавить'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showGroupForm({Map? existingItem}) {
    bool isEdit = existingItem != null;
    TextEditingController nameCtrl = TextEditingController(text: isEdit ? existingItem['group_Name'] ?? '' : '');
    TextEditingController admissionCtrl = TextEditingController(text: isEdit ? existingItem['admission_Year']?.toString() ?? '' : '');
    TextEditingController formCtrl = TextEditingController(text: isEdit ? existingItem['education_Form'] ?? '' : '');
    
    int? selectedCurriculumId = isEdit ? existingItem['id_UP'] : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: Text('${isEdit ? 'Изменить' : 'Добавить'} группу'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Название группы', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(labelText: 'Учебный план', border: OutlineInputBorder()),
                  value: selectedCurriculumId,
                  items: _referenceData['curriculums']?.map((c) => DropdownMenuItem<int>(
                    value: c['id_UP'],
                    child: Text(c['short_Name_UP'] ?? c['full_Name_UP']),
                  )).toList(),
                  onChanged: (val) => setStateDialog(() => selectedCurriculumId = val),
                ),
                const SizedBox(height: 10),
                TextField(controller: admissionCtrl, decoration: const InputDecoration(labelText: 'Год поступления', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: formCtrl, decoration: const InputDecoration(labelText: 'Форма обучения', border: OutlineInputBorder())),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
            ElevatedButton(
              onPressed: () async {
                Map<String, dynamic> data = {
                  'group_Name': nameCtrl.text,
                  'id_UP': selectedCurriculumId ?? 0,
                  'admission_Year': int.tryParse(admissionCtrl.text),
                  'education_Form': formCtrl.text.isEmpty ? null : formCtrl.text,
                };
                
                String tableName = _getTableNameForApi(_currentTable);
                try {
                  if (isEdit) {
                    await _dio.put('/$tableName/${existingItem!['id_Group']}', data: data);
                  } else {
                    await _dio.post('/$tableName', data: data);
                  }
                  if (mounted) {
                    Navigator.pop(ctx);
                    await _refreshAllData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(isEdit ? 'Группа изменена!' : 'Группа добавлена!'), backgroundColor: Colors.green)
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red)
                    );
                  }
                }
              },
              child: Text(isEdit ? 'Сохранить' : 'Добавить'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCurriculumForm({Map? existingItem}) {
    bool isEdit = existingItem != null;
    TextEditingController fullNameCtrl = TextEditingController(text: isEdit ? existingItem['full_Name_UP'] ?? '' : '');
    TextEditingController shortNameCtrl = TextEditingController(text: isEdit ? existingItem['short_Name_UP'] ?? '' : '');
    TextEditingController yearCtrl = TextEditingController(text: isEdit ? existingItem['year_Approved']?.toString() ?? '' : '');
    TextEditingController formCtrl = TextEditingController(text: isEdit ? existingItem['education_Form'] ?? '' : '');
    
    int? selectedSpecialtyId = isEdit ? existingItem['specialty_Id'] : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: Text('${isEdit ? 'Изменить' : 'Добавить'} учебный план'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: fullNameCtrl, decoration: const InputDecoration(labelText: 'Полное название', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: shortNameCtrl, decoration: const InputDecoration(labelText: 'Краткое название', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(labelText: 'Специальность', border: OutlineInputBorder()),
                  value: selectedSpecialtyId,
                  items: [
                    const DropdownMenuItem<int>(value: null, child: Text('-- Не выбрана --')),
                    ...(_referenceData['specialties']?.map((s) => DropdownMenuItem<int>(
                      value: s['id_Specialty'],
                      child: Text(s['short_Name_Specialty'] ?? s['full_Name_Specialty']),
                    )).toList() ?? []),
                  ],
                  onChanged: (val) => setStateDialog(() => selectedSpecialtyId = val),
                ),
                const SizedBox(height: 10),
                TextField(controller: yearCtrl, decoration: const InputDecoration(labelText: 'Год утверждения', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: formCtrl, decoration: const InputDecoration(labelText: 'Форма обучения', border: OutlineInputBorder())),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
            ElevatedButton(
              onPressed: () async {
                Map<String, dynamic> data = {
                  'full_Name_UP': fullNameCtrl.text,
                  'short_Name_UP': shortNameCtrl.text.isEmpty ? null : shortNameCtrl.text,
                  'specialty_Id': selectedSpecialtyId,
                  'year_Approved': int.tryParse(yearCtrl.text),
                  'education_Form': formCtrl.text.isEmpty ? null : formCtrl.text,
                };
                
                String tableName = _getTableNameForApi(_currentTable);
                try {
                  if (isEdit) {
                    await _dio.put('/$tableName/${existingItem!['id_UP']}', data: data);
                  } else {
                    await _dio.post('/$tableName', data: data);
                  }
                  if (mounted) {
                    Navigator.pop(ctx);
                    await _refreshAllData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(isEdit ? 'План изменен!' : 'План добавлен!'), backgroundColor: Colors.green)
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red)
                    );
                  }
                }
              },
              child: Text(isEdit ? 'Сохранить' : 'Добавить'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDisciplineForm({Map? existingItem}) {
    bool isEdit = existingItem != null;
    TextEditingController fullNameCtrl = TextEditingController(text: isEdit ? existingItem['full_Discipline_Name'] ?? '' : '');
    TextEditingController shortNameCtrl = TextEditingController(text: isEdit ? existingItem['short_Discipline_Name'] ?? '' : '');
    TextEditingController practiceCtrl = TextEditingController(text: isEdit ? existingItem['practice_Type'] ?? '' : '');
    
    List pckList = _referenceData['pck'] ?? [];
    if (currentUserRole == 2 && currentUserPckId != null) {
      pckList = pckList.where((p) => p['id_PCK'] == currentUserPckId).toList();
    }
    
    int? selectedPckId = isEdit ? existingItem['pck_Id'] : 
        (currentUserRole == 2 && pckList.isNotEmpty ? currentUserPckId : null);
    int? selectedCycleId = isEdit ? existingItem['cycle_Id'] : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: Text('${isEdit ? 'Изменить' : 'Добавить'} дисциплину'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: fullNameCtrl, decoration: const InputDecoration(labelText: 'Полное название', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: shortNameCtrl, decoration: const InputDecoration(labelText: 'Краткое название', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(labelText: 'ПЦК', border: OutlineInputBorder()),
                  value: selectedPckId,
                  items: pckList.map((p) => DropdownMenuItem<int>(
                    value: p['id_PCK'],
                    child: Text(p['short_PCK_Name'] ?? p['full_PCK_Name']),
                  )).toList(),
                  onChanged: (currentUserRole == 1) ? (val) => setStateDialog(() => selectedPckId = val) : null,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(labelText: 'Цикл дисциплин', border: OutlineInputBorder()),
                  value: selectedCycleId,
                  items: [
                    const DropdownMenuItem<int>(value: null, child: Text('-- Не выбран --')),
                    ...(_referenceData['cycles']?.map((c) => DropdownMenuItem<int>(
                      value: c['id_Cycle'],
                      child: Text(c['short_Cycle_Name'] ?? c['full_Cycle_Name']),
                    )).toList() ?? []),
                  ],
                  onChanged: (val) => setStateDialog(() => selectedCycleId = val),
                ),
                const SizedBox(height: 10),
                TextField(controller: practiceCtrl, decoration: const InputDecoration(labelText: 'Тип практики', border: OutlineInputBorder())),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
            ElevatedButton(
              onPressed: () async {
                Map<String, dynamic> data = {
                  'full_Discipline_Name': fullNameCtrl.text,
                  'short_Discipline_Name': shortNameCtrl.text.isEmpty ? null : shortNameCtrl.text,
                  'pck_Id': selectedPckId ?? 0,
                  'cycle_Id': selectedCycleId,
                  'practice_Type': practiceCtrl.text.isEmpty ? null : practiceCtrl.text,
                };
                
                String tableName = _getTableNameForApi(_currentTable);
                try {
                  if (isEdit) {
                    await _dio.put('/$tableName/${existingItem!['id_Discipline']}', data: data);
                  } else {
                    await _dio.post('/$tableName', data: data);
                  }
                  if (mounted) {
                    Navigator.pop(ctx);
                    await _refreshAllData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(isEdit ? 'Дисциплина изменена!' : 'Дисциплина добавлена!'), backgroundColor: Colors.green)
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red)
                    );
                  }
                }
              },
              child: Text(isEdit ? 'Сохранить' : 'Добавить'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCurriculumLoadForm({Map? existingItem}) {
    bool isEdit = existingItem != null;
    TextEditingController semesterCtrl = TextEditingController(text: isEdit ? existingItem['semester']?.toString() ?? '' : '');
    TextEditingController hoursCtrl = TextEditingController(text: isEdit ? existingItem['total_Hours']?.toString() ?? '' : '');
    TextEditingController subgroupCtrl = TextEditingController(text: isEdit ? existingItem['subgroup_Number']?.toString() ?? '' : '');
    TextEditingController lecturesCtrl = TextEditingController(text: isEdit ? existingItem['lectures']?.toString() ?? '' : '');
    TextEditingController labCtrl = TextEditingController(text: isEdit ? existingItem['lab_Works']?.toString() ?? '' : '');
    TextEditingController practiceCtrl = TextEditingController(text: isEdit ? existingItem['practice_Works']?.toString() ?? '' : '');
    TextEditingController consultCtrl = TextEditingController(text: isEdit ? existingItem['consultations']?.toString() ?? '' : '');
    TextEditingController defenseCtrl = TextEditingController(text: isEdit ? existingItem['course_Work_Defense']?.toString() ?? '' : '');
    
    bool isCredit = isEdit ? (existingItem['is_Credit'] == true) : false;
    bool isDiffCredit = isEdit ? (existingItem['is_Diff_Credit'] == true) : false;
    bool isExam = isEdit ? (existingItem['is_Exam'] == true) : false;
    bool isComplexExam = isEdit ? (existingItem['is_Complex_Exam'] == true) : false;
    bool isControlWork = isEdit ? (existingItem['is_Control_Work'] == true) : false;
    bool isCourseWork = isEdit ? (existingItem['is_Course_Work'] == true) : false;
    
    int? selectedCurriculumId = isEdit ? existingItem['up_Id'] : null;
    int? selectedDisciplineId = isEdit ? existingItem['discipline_Id'] : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: Text('${isEdit ? 'Изменить' : 'Добавить'} нагрузку'),
          content: SizedBox(
            width: 600,
            height: 620,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(labelText: 'Учебный план', border: OutlineInputBorder()),
                    value: selectedCurriculumId,
                    items: _referenceData['curriculums']?.map((c) => DropdownMenuItem<int>(
                      value: c['id_UP'],
                      child: Text(c['short_Name_UP'] ?? c['full_Name_UP']),
                    )).toList(),
                    onChanged: (val) => setStateDialog(() => selectedCurriculumId = val),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(labelText: 'Дисциплина', border: OutlineInputBorder()),
                    value: selectedDisciplineId,
                    items: _referenceData['disciplines']?.map((d) => DropdownMenuItem<int>(
                      value: d['id_Discipline'],
                      child: Text(d['short_Discipline_Name'] ?? d['full_Discipline_Name']),
                    )).toList(),
                    onChanged: (val) => setStateDialog(() => selectedDisciplineId = val),
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: semesterCtrl, decoration: const InputDecoration(labelText: 'Семестр', border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  TextField(controller: hoursCtrl, decoration: const InputDecoration(labelText: 'Всего часов', border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  TextField(controller: subgroupCtrl, decoration: const InputDecoration(labelText: 'Номер подгруппы', border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: TextField(controller: lecturesCtrl, decoration: const InputDecoration(labelText: 'Лекции', border: OutlineInputBorder()))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: labCtrl, decoration: const InputDecoration(labelText: 'Лабораторные', border: OutlineInputBorder()))),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: TextField(controller: practiceCtrl, decoration: const InputDecoration(labelText: 'Практические', border: OutlineInputBorder()))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: consultCtrl, decoration: const InputDecoration(labelText: 'Консультации', border: OutlineInputBorder()))),
                  ]),
                  const SizedBox(height: 10),
                  TextField(controller: defenseCtrl, decoration: const InputDecoration(labelText: 'Защита курсовой (часы)', border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  const Text('Формы контроля:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Wrap(
                    children: [
                      SizedBox(width: 200, child: CheckboxListTile(value: isCredit, onChanged: (val) => setStateDialog(() => isCredit = val ?? false), title: const Text('Зачет'), contentPadding: EdgeInsets.zero)),
                      SizedBox(width: 200, child: CheckboxListTile(value: isDiffCredit, onChanged: (val) => setStateDialog(() => isDiffCredit = val ?? false), title: const Text('Диф.зачет'), contentPadding: EdgeInsets.zero)),
                      SizedBox(width: 200, child: CheckboxListTile(value: isExam, onChanged: (val) => setStateDialog(() => isExam = val ?? false), title: const Text('Экзамен'), contentPadding: EdgeInsets.zero)),
                      SizedBox(width: 200, child: CheckboxListTile(value: isComplexExam, onChanged: (val) => setStateDialog(() => isComplexExam = val ?? false), title: const Text('Компл.экзамен'), contentPadding: EdgeInsets.zero)),
                      SizedBox(width: 200, child: CheckboxListTile(value: isControlWork, onChanged: (val) => setStateDialog(() => isControlWork = val ?? false), title: const Text('Контр.работа'), contentPadding: EdgeInsets.zero)),
                      SizedBox(width: 200, child: CheckboxListTile(value: isCourseWork, onChanged: (val) => setStateDialog(() => isCourseWork = val ?? false), title: const Text('Курс.работа'), contentPadding: EdgeInsets.zero)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
            ElevatedButton(
              onPressed: () async {
                Map<String, dynamic> data = {
                  'up_Id': selectedCurriculumId ?? 0,
                  'discipline_Id': selectedDisciplineId ?? 0,
                  'semester': int.tryParse(semesterCtrl.text) ?? 0,
                  'total_Hours': int.tryParse(hoursCtrl.text),
                  'subgroup_Number': int.tryParse(subgroupCtrl.text) ?? 1,
                  'lectures': int.tryParse(lecturesCtrl.text) ?? 0,
                  'lab_Works': int.tryParse(labCtrl.text) ?? 0,
                  'practice_Works': int.tryParse(practiceCtrl.text) ?? 0,
                  'consultations': int.tryParse(consultCtrl.text) ?? 0,
                  'course_Work_Defense': int.tryParse(defenseCtrl.text) ?? 0,
                  'is_Credit': isCredit,
                  'is_Diff_Credit': isDiffCredit,
                  'is_Exam': isExam,
                  'is_Complex_Exam': isComplexExam,
                  'is_Control_Work': isControlWork,
                  'is_Course_Work': isCourseWork,
                };
                
                String tableName = _getTableNameForApi(_currentTable);
                try {
                  if (isEdit) {
                    await _dio.put('/$tableName/${existingItem!['id_Load']}', data: data);
                  } else {
                    await _dio.post('/$tableName', data: data);
                  }
                  if (mounted) {
                    Navigator.pop(ctx);
                    await _refreshAllData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(isEdit ? 'Нагрузка изменена!' : 'Нагрузка добавлена!'), backgroundColor: Colors.green)
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red)
                    );
                  }
                }
              },
              child: Text(isEdit ? 'Сохранить' : 'Добавить'),
            ),
          ],
        ),
      ),
    );
  }

  void _showGroupAcademicYearForm({Map? existingItem}) {
    bool isEdit = existingItem != null;
    TextEditingController budgetCtrl = TextEditingController(text: isEdit ? existingItem['budget_Students']?.toString() ?? '' : '');
    TextEditingController contractCtrl = TextEditingController(text: isEdit ? existingItem['contract_Students']?.toString() ?? '' : '');
    TextEditingController subgroupCtrl = TextEditingController(text: isEdit ? existingItem['first_Subgroup_Count']?.toString() ?? '' : '');
    
    int? selectedGroupId = isEdit ? existingItem['group_Id'] : null;
    int? selectedYearId = isEdit ? existingItem['academicYear_Id'] : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: Text('${isEdit ? 'Изменить' : 'Добавить'} связь группы с годом'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(labelText: 'Группа', border: OutlineInputBorder()),
                  value: selectedGroupId,
                  items: _referenceData['groups']?.map((g) => DropdownMenuItem<int>(
                    value: g['id_Group'],
                    child: Text(g['group_Name']),
                  )).toList(),
                  onChanged: (val) => setStateDialog(() => selectedGroupId = val),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(labelText: 'Учебный год', border: OutlineInputBorder()),
                  value: selectedYearId,
                  items: _referenceData['academicYears']?.map((y) => DropdownMenuItem<int>(
                    value: y['id_AcademicYear'],
                    child: Text(y['start_Year'].toString()),
                  )).toList(),
                  onChanged: (val) => setStateDialog(() => selectedYearId = val),
                ),
                const SizedBox(height: 10),
                TextField(controller: budgetCtrl, decoration: const InputDecoration(labelText: 'Бюджетников', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: contractCtrl, decoration: const InputDecoration(labelText: 'Контрактников', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: subgroupCtrl, decoration: const InputDecoration(labelText: 'Кол-во в 1 подгруппе', border: OutlineInputBorder())),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
            ElevatedButton(
              onPressed: () async {
                Map<String, dynamic> data = {
                  'group_Id': selectedGroupId ?? 0,
                  'academicYear_Id': selectedYearId ?? 0,
                  'budget_Students': int.tryParse(budgetCtrl.text),
                  'contract_Students': int.tryParse(contractCtrl.text),
                  'first_Subgroup_Count': int.tryParse(subgroupCtrl.text),
                };
                
                String tableName = _getTableNameForApi(_currentTable);
                try {
                  if (isEdit) {
                    await _dio.put('/$tableName/${existingItem!['id_Group_AcademicYear']}', data: data);
                  } else {
                    await _dio.post('/$tableName', data: data);
                  }
                  if (mounted) {
                    Navigator.pop(ctx);
                    await _refreshAllData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(isEdit ? 'Связь изменена!' : 'Связь добавлена!'), backgroundColor: Colors.green)
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red)
                    );
                  }
                }
              },
              child: Text(isEdit ? 'Сохранить' : 'Добавить'),
            ),
          ],
        ),
      ),
    );
  }

  void _showActualLoadForm({Map? existingItem}) {
    bool isEdit = existingItem != null;
    TextEditingController lecturesCtrl = TextEditingController(text: isEdit ? existingItem['lectures']?.toString() ?? '' : '');
    TextEditingController labCtrl = TextEditingController(text: isEdit ? existingItem['lab_Works']?.toString() ?? '' : '');
    TextEditingController practiceCtrl = TextEditingController(text: isEdit ? existingItem['practice_Works']?.toString() ?? '' : '');
    TextEditingController consultCtrl = TextEditingController(text: isEdit ? existingItem['consultations']?.toString() ?? '' : '');
    TextEditingController creditCtrl = TextEditingController(text: isEdit ? existingItem['credit']?.toString() ?? '' : '');
    TextEditingController diffCreditCtrl = TextEditingController(text: isEdit ? existingItem['diff_Credit']?.toString() ?? '' : '');
    TextEditingController examCtrl = TextEditingController(text: isEdit ? existingItem['exam']?.toString() ?? '' : '');
    TextEditingController complexExamCtrl = TextEditingController(text: isEdit ? existingItem['complex_Exam']?.toString() ?? '' : '');
    TextEditingController controlWorkCtrl = TextEditingController(text: isEdit ? existingItem['control_Work']?.toString() ?? '' : '');
    TextEditingController courseWorkCtrl = TextEditingController(text: isEdit ? existingItem['course_Work']?.toString() ?? '' : '');
    TextEditingController courseWorkDefenseCtrl = TextEditingController(text: isEdit ? existingItem['course_Work_Defense']?.toString() ?? '' : '');
    bool isApproved = isEdit ? (existingItem['is_Approved'] == true) : false;
    
    List teachersList = _referenceData['teachers'] ?? [];
    if (currentUserRole == 2 && currentUserPckId != null) {
      teachersList = teachersList.where((t) => t['pck_Id'] == currentUserPckId).toList();
    }
    
    int? selectedLoadId = isEdit ? existingItem['load_UP_Id'] : null;
    int? selectedGroupId = isEdit ? existingItem['group_Id'] : null;
    int? selectedTeacherId = isEdit ? existingItem['teacher_Id'] : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: Text('${isEdit ? 'Изменить' : 'Добавить'} фактическую нагрузку'),
          content: SizedBox(
            width: 650,
            height: 600,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(labelText: 'Нагрузка', border: OutlineInputBorder()),
                    value: selectedLoadId,
                    items: _referenceData['loads']?.map((l) => DropdownMenuItem<int>(
                      value: l['id_Load'],
                      child: Text('${l['id_Load']} - ${l['discipline_Id']}'),
                    )).toList(),
                    onChanged: (val) => setStateDialog(() => selectedLoadId = val),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(labelText: 'Группа', border: OutlineInputBorder()),
                    value: selectedGroupId,
                    items: _referenceData['groups']?.map((g) => DropdownMenuItem<int>(
                      value: g['id_Group'],
                      child: Text(g['group_Name']),
                    )).toList(),
                    onChanged: (val) => setStateDialog(() => selectedGroupId = val),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(labelText: 'Преподаватель', border: OutlineInputBorder()),
                    value: selectedTeacherId,
                    items: teachersList.map((t) => DropdownMenuItem<int>(
                      value: t['id_Teacher'],
                      child: Text(t['fio'] ?? 'Преподаватель ${t['id_Teacher']}'),
                    )).toList(),
                    onChanged: (val) => setStateDialog(() => selectedTeacherId = val),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: TextField(controller: lecturesCtrl, decoration: const InputDecoration(labelText: 'Лекции', border: OutlineInputBorder()))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: labCtrl, decoration: const InputDecoration(labelText: 'Лабораторные', border: OutlineInputBorder()))),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: TextField(controller: practiceCtrl, decoration: const InputDecoration(labelText: 'Практические', border: OutlineInputBorder()))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: consultCtrl, decoration: const InputDecoration(labelText: 'Консультации', border: OutlineInputBorder()))),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: TextField(controller: creditCtrl, decoration: const InputDecoration(labelText: 'Зачет', border: OutlineInputBorder()))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: diffCreditCtrl, decoration: const InputDecoration(labelText: 'Диф.зачет', border: OutlineInputBorder()))),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: TextField(controller: examCtrl, decoration: const InputDecoration(labelText: 'Экзамен', border: OutlineInputBorder()))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: complexExamCtrl, decoration: const InputDecoration(labelText: 'Компл.экзамен', border: OutlineInputBorder()))),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: TextField(controller: controlWorkCtrl, decoration: const InputDecoration(labelText: 'Контр.работа', border: OutlineInputBorder()))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: courseWorkCtrl, decoration: const InputDecoration(labelText: 'Курс.работа', border: OutlineInputBorder()))),
                  ]),
                  const SizedBox(height: 10),
                  TextField(controller: courseWorkDefenseCtrl, decoration: const InputDecoration(labelText: 'Защита курсовой', border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Checkbox(
                        value: isApproved,
                        onChanged: (val) => setStateDialog(() => isApproved = val ?? false),
                      ),
                      const Text('Утверждено'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
            ElevatedButton(
              onPressed: () async {
                Map<String, dynamic> data = {
                  'load_UP_Id': selectedLoadId ?? 0,
                  'group_Id': selectedGroupId ?? 0,
                  'teacher_Id': selectedTeacherId ?? 0,
                  'lectures': double.tryParse(lecturesCtrl.text),
                  'lab_Works': double.tryParse(labCtrl.text),
                  'practice_Works': double.tryParse(practiceCtrl.text),
                  'consultations': double.tryParse(consultCtrl.text),
                  'credit': double.tryParse(creditCtrl.text),
                  'diff_Credit': double.tryParse(diffCreditCtrl.text),
                  'exam': double.tryParse(examCtrl.text),
                  'complex_Exam': double.tryParse(complexExamCtrl.text),
                  'control_Work': double.tryParse(controlWorkCtrl.text),
                  'course_Work': double.tryParse(courseWorkCtrl.text),
                  'course_Work_Defense': double.tryParse(courseWorkDefenseCtrl.text),
                  'is_Approved': isApproved,
                };
                
                String tableName = _getTableNameForApi(_currentTable);
                try {
                  if (isEdit) {
                    await _dio.put('/$tableName/${existingItem!['id_ActualLoad']}', data: data);
                  } else {
                    await _dio.post('/$tableName', data: data);
                  }
                  if (mounted) {
                    Navigator.pop(ctx);
                    await _refreshAllData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(isEdit ? 'Нагрузка изменена!' : 'Нагрузка добавлена!'), backgroundColor: Colors.green)
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red)
                    );
                  }
                }
              },
              child: Text(isEdit ? 'Сохранить' : 'Добавить'),
            ),
          ],
        ),
      ),
    );
  }

  void _editItem(Map item) {
    if (!canEdit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('У вас нет прав на редактирование'), backgroundColor: Colors.orange)
      );
      return;
    }
    
    switch (_currentTable) {
      case 'Roles':
      case 'Positions':
      case 'Degrees':
      case 'Employments':
      case 'DisciplineCycles':
      case 'AcademicYears':
      case 'Specialties':
        Map<String, String> fields = {};
        if (_currentTable == 'Roles') fields = {'role_Name': 'Название роли'};
        else if (_currentTable == 'Positions') fields = {'position_Name': 'Название должности'};
        else if (_currentTable == 'Degrees') fields = {'degree_Name': 'Название степени'};
        else if (_currentTable == 'Employments') fields = {'employment_Name': 'Название занятости', 'format': 'Формат'};
        else if (_currentTable == 'DisciplineCycles') fields = {
          'full_Cycle_Name': 'Полное название',
          'short_Cycle_Name': 'Краткое название',
          'discipline_Group': 'Группа дисциплин'
        };
        else if (_currentTable == 'AcademicYears') fields = {'start_Year': 'Год начала'};
        else if (_currentTable == 'Specialties') fields = {'full_Name_Specialty': 'Полное название', 'short_Name_Specialty': 'Краткое название'};
        _showSimpleForm(fields, existingItem: item);
        break;
      case 'PCK':
        _showPCKForm(existingItem: item);
        break;
      case 'Users':
        _showUserForm(existingItem: item);
        break;
      case 'Groups':
        _showGroupForm(existingItem: item);
        break;
      case 'Curriculums':
        _showCurriculumForm(existingItem: item);
        break;
      case 'Disciplines':
        _showDisciplineForm(existingItem: item);
        break;
      case 'CurriculumLoad':
        _showCurriculumLoadForm(existingItem: item);
        break;
      case 'Teachers':
        _showTeacherForm(existingItem: item);
        break;
      case 'GroupAcademicYears':
        _showGroupAcademicYearForm(existingItem: item);
        break;
      case 'ActualLoad':
        _showActualLoadForm(existingItem: item);
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Редактирование для $_currentTable в разработке'))
        );
        break;
    }
  }

  void _deleteItem(Map item) async {
    if (!canEdit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('У вас нет прав на удаление'), backgroundColor: Colors.orange)
      );
      return;
    }
    
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Подтверждение'),
        content: Text('Удалить запись из ${_getRussianName(_currentTable)}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Нет')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Да')),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    String id = '';
    String tableName = _getTableNameForApi(_currentTable);
    
    if (_currentTable == 'Roles') id = item['id_Role'].toString();
    else if (_currentTable == 'Users') id = item['id'].toString();
    else if (_currentTable == 'Groups') id = item['id_Group'].toString();
    else if (_currentTable == 'PCK') id = item['id_PCK'].toString();
    else if (_currentTable == 'Teachers') id = item['id_Teacher'].toString();
    else if (_currentTable == 'Disciplines') id = item['id_Discipline'].toString();
    else if (_currentTable == 'Specialties') id = item['id_Specialty'].toString();
    else if (_currentTable == 'Positions') id = item['id_Position'].toString();
    else if (_currentTable == 'Degrees') id = item['id_Degree'].toString();
    else if (_currentTable == 'Employments') id = item['id_Employment'].toString();
    else if (_currentTable == 'Curriculums') id = item['id_UP'].toString();
    else if (_currentTable == 'DisciplineCycles') id = item['id_Cycle'].toString();
    else if (_currentTable == 'CurriculumLoad') id = item['id_Load'].toString();
    else if (_currentTable == 'AcademicYears') id = item['id_AcademicYear'].toString();
    else if (_currentTable == 'GroupAcademicYears') id = item['id_Group_AcademicYear'].toString();
    else if (_currentTable == 'ActualLoad') id = item['id_ActualLoad'].toString();
    
    try {
      await _dio.delete('/$tableName/$id');
      if (mounted) {
        await _refreshAllData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Запись удалена'), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка удаления: $e'), backgroundColor: Colors.red)
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Управление: ${_getRussianName(_currentTable)}'), 
        backgroundColor: Colors.blueGrey,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshAllData, tooltip: 'Обновить'),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          children: _availableTables.map((t) => ListTile(
            title: Text(t),
            subtitle: Text(_getRussianName(t), style: const TextStyle(fontSize: 10)),
            selected: _currentTable == t,
            onTap: () {
              setState(() => _currentTable = t);
              Navigator.pop(context);
              _loadData();
            },
          )).toList(),
        ),
      ),
      body: _loading 
        ? const Center(child: CircularProgressIndicator())
        : _buildContent(),
      floatingActionButton: canCreate ? FloatingActionButton(
        onPressed: _addItem,
        child: const Icon(Icons.add),
      ) : null,
    );
  }

  Widget _buildContent() {
    if (_data.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 120, color: Colors.grey.shade400),
            const SizedBox(height: 20),
            Text('Нет данных ${_getRussianName(_currentTable)}',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 10),
            Text('Нажмите кнопку + чтобы добавить',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }
    return _buildTable();
  }

  Widget _buildTable() {
    Map firstRow = _data.first;
    List keys = firstRow.keys.toList();
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: DataTable(
          columnSpacing: 20,
          columns: [
            ...keys.map((k) => DataColumn(label: Text(k.toString(), style: const TextStyle(fontWeight: FontWeight.bold)))),
            if (canEdit) const DataColumn(label: Text('Действия', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: _data.map((row) => DataRow(cells: [
            ...keys.map((k) => DataCell(
              Container(
                constraints: const BoxConstraints(maxWidth: 250),
                child: Text(row[k]?.toString() ?? '', overflow: TextOverflow.ellipsis),
              )
            )),
            if (canEdit) DataCell(
              Row(
                children: [
                  IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _editItem(row), tooltip: 'Редактировать'),
                  IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteItem(row), tooltip: 'Удалить'),
                ],
              ),
            ),
          ])).toList(),
        ),
      ),
    );
  }
}