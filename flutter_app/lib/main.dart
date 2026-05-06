import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

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
  
  Map<String, List> _referenceData = {};
  
  // Доступные таблицы в зависимости от роли
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
  }

  void _loadAllReferences() async {
    try {
      var roles = await _dio.get('/roles');
      var pck = await _dio.get('/pck');
      var positions = await _dio.get('/positions');
      var degrees = await _dio.get('/degrees');
      var employments = await _dio.get('/employments');
      var specialties = await _dio.get('/specialties');
      var curriculums = await _dio.get('/curriculums');
      var groups = await _dio.get('/groups');
      var cycles = await _dio.get('/discipline-cycles');
      var disciplines = await _dio.get('/disciplines');
      var loads = await _dio.get('/curriculum-load');
      var teachers = await _dio.get('/teachers');
      var academicYears = await _dio.get('/academic-years');
      var users = await _dio.get('/users');
      
      setState(() {
        _referenceData['roles'] = roles.data;
        _referenceData['pck'] = pck.data;
        _referenceData['positions'] = positions.data;
        _referenceData['degrees'] = degrees.data;
        _referenceData['employments'] = employments.data;
        _referenceData['specialties'] = specialties.data;
        _referenceData['curriculums'] = curriculums.data;
        _referenceData['groups'] = groups.data;
        _referenceData['cycles'] = cycles.data;
        _referenceData['disciplines'] = disciplines.data;
        _referenceData['loads'] = loads.data;
        _referenceData['teachers'] = teachers.data;
        _referenceData['academicYears'] = academicYears.data;
        _referenceData['users'] = users.data;
      });
    } catch (e) {
      print('Ошибка загрузки справочников: $e');
    }
  }

  void _loadData() async {
    setState(() => _loading = true);
    try {
      String tableName = _getTableNameForApi(_currentTable);
      var res = await _dio.get('/$tableName');
      
      var filteredData = res.data;
      if (currentUserRole == 2) {
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
    if (currentUserRole == 2) {
      _showTeacherForm();
      return;
    }
    
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
        _showSimpleForm({
          'full_PCK_Name': 'Полное название ПЦК',
          'short_PCK_Name': 'Краткое название'
        });
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
              fields.forEach((key, _) {
                String val = controllers[key]!.text;
                if (key == 'start_Year' || key == 'year_Approved') {
                  data[key] = int.tryParse(val) ?? 0;
                } else {
                  data[key] = val;
                }
              });
              
              String tableName = _getTableNameForApi(_currentTable);
              if (isEdit) {
                String id = existingItem!['id_Role']?.toString() ?? 
                           existingItem['id']?.toString() ?? 
                           existingItem['id_PCK']?.toString() ??
                           existingItem['id_Position']?.toString() ??
                           existingItem['id_Degree']?.toString() ??
                           existingItem['id_Employment']?.toString() ??
                           existingItem['id_Specialty']?.toString() ??
                           existingItem['id_UP']?.toString() ??
                           existingItem['id_Group']?.toString() ??
                           existingItem['id_Cycle']?.toString() ??
                           existingItem['id_Discipline']?.toString() ??
                           existingItem['id_AcademicYear']?.toString() ?? '';
                await _dio.put('/$tableName/$id', data: data);
              } else {
                await _dio.post('/$tableName', data: data);
              }
              if (mounted) Navigator.pop(ctx);
              _loadData();
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
        const SnackBar(content: Text('У вас нет прав на создание пользователей'), backgroundColor: Colors.red)
      );
      return;
    }
    
    bool isEdit = existingItem != null;
    TextEditingController usernameCtrl = TextEditingController(text: isEdit ? existingItem['username'] ?? '' : '');
    TextEditingController passwordCtrl = TextEditingController(text: '');
    
    dynamic selectedRole = isEdit ? _findById(_referenceData['roles'], existingItem['role_Id']) : null;
    dynamic selectedPck = isEdit ? _findById(_referenceData['pck'], existingItem['pck_Id']) : null;

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
                TextField(controller: usernameCtrl, decoration: const InputDecoration(labelText: 'Логин')),
                const SizedBox(height: 10),
                if (!isEdit) TextField(controller: passwordCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Пароль')),
                const SizedBox(height: 10),
                DropdownButtonFormField(
                  decoration: const InputDecoration(labelText: 'Роль'),
                  value: selectedRole,
                  items: _referenceData['roles']?.map((r) => DropdownMenuItem(
                    value: r,
                    child: Text(r['role_Name']),
                  )).toList(),
                  onChanged: (val) => setStateDialog(() => selectedRole = val),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField(
                  decoration: const InputDecoration(labelText: 'ПЦК'),
                  value: selectedPck,
                  items: _referenceData['pck']?.map((p) => DropdownMenuItem(
                    value: p,
                    child: Text(p['short_PCK_Name'] ?? p['full_PCK_Name']),
                  )).toList(),
                  onChanged: (val) => setStateDialog(() => selectedPck = val),
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
                  'role_Id': selectedRole?['id_Role'] ?? 0,
                  'pck_Id': selectedPck?['id_PCK'],
                  'createdBy': currentUserId,
                };
                if (!isEdit) {
                  data['password'] = passwordCtrl.text;
                }
                
                String tableName = _getTableNameForApi(_currentTable);
                
                if (isEdit) {
                  await _dio.put('/$tableName/${existingItem!['id']}', data: data);
                } else {
                  await _dio.post('/$tableName', data: data);
                }
                
                Navigator.pop(ctx);
                _loadData();
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
    TextEditingController usernameCtrl = TextEditingController(text: '');
    TextEditingController passwordCtrl = TextEditingController(text: '');
    TextEditingController fioCtrl = TextEditingController(text: isEdit ? existingItem['fio'] ?? '' : '');
    TextEditingController knCtrl = TextEditingController(text: isEdit ? existingItem['kN_Number']?.toString() ?? '' : '');
    TextEditingController categoryCtrl = TextEditingController(text: isEdit ? existingItem['category'] ?? '' : '');
    
    bool hasHigherEducation = isEdit ? (existingItem['has_Higher_Education'] == true) : false;
    
    List pckList = _referenceData['pck'] ?? [];
    if (currentUserRole == 2 && currentUserPckId != null) {
      pckList = pckList.where((p) => p['id_PCK'] == currentUserPckId).toList();
    }
    
    dynamic selectedUser = isEdit ? _findById(_referenceData['users'], existingItem['user_Id']) : null;
    dynamic selectedPck = isEdit ? _findById(_referenceData['pck'], existingItem['pck_Id']) : 
        (currentUserRole == 2 && pckList.isNotEmpty ? pckList.first : null);
    dynamic selectedPosition = isEdit ? _findById(_referenceData['positions'], existingItem['position_Id']) : null;
    dynamic selectedDegree = isEdit ? _findById(_referenceData['degrees'], existingItem['degree_Id']) : null;
    dynamic selectedEmployment = isEdit ? _findById(_referenceData['employments'], existingItem['employment_Id']) : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: Text('${isEdit ? 'Изменить' : 'Добавить'} преподавателя'),
          content: SizedBox(
            width: 500,
            height: 650,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (currentUserRole == 2 && !isEdit) ...[
                    TextField(controller: usernameCtrl, decoration: const InputDecoration(labelText: 'Логин пользователя')),
                    const SizedBox(height: 10),
                    TextField(controller: passwordCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Пароль')),
                    const SizedBox(height: 10),
                  ],
                  if (currentUserRole == 1 && isEdit) ...[
                    DropdownButtonFormField(
                      decoration: const InputDecoration(labelText: 'Пользователь'),
                      value: selectedUser,
                      items: _referenceData['users']?.where((u) => u['role_Id'] == 3).map((u) => DropdownMenuItem(
                        value: u,
                        child: Text(u['username']),
                      )).toList(),
                      onChanged: (val) => setStateDialog(() => selectedUser = val),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (currentUserRole == 1 && !isEdit) ...[
                    DropdownButtonFormField(
                      decoration: const InputDecoration(labelText: 'Пользователь (опционально)'),
                      value: selectedUser,
                      items: _referenceData['users']?.where((u) => u['role_Id'] == 3).map((u) => DropdownMenuItem(
                        value: u,
                        child: Text(u['username']),
                      )).toList(),
                      onChanged: (val) => setStateDialog(() => selectedUser = val),
                    ),
                    const SizedBox(height: 10),
                    const Divider(),
                    const Text('Или создайте нового:'),
                    TextField(controller: usernameCtrl, decoration: const InputDecoration(labelText: 'Новый логин')),
                    const SizedBox(height: 10),
                    TextField(controller: passwordCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Новый пароль')),
                    const SizedBox(height: 10),
                  ],
                  TextField(controller: fioCtrl, decoration: const InputDecoration(labelText: 'ФИО')),
                  const SizedBox(height: 10),
                  DropdownButtonFormField(
                    decoration: const InputDecoration(labelText: 'ПЦК'),
                    value: selectedPck,
                    items: pckList.map((p) => DropdownMenuItem(
                      value: p,
                      child: Text(p['short_PCK_Name'] ?? p['full_PCK_Name']),
                    )).toList(),
                    onChanged: (currentUserRole == 1) ? (val) => setStateDialog(() => selectedPck = val) : null,
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: knCtrl, decoration: const InputDecoration(labelText: 'Номер КН')),
                  const SizedBox(height: 10),
                  TextField(controller: categoryCtrl, decoration: const InputDecoration(labelText: 'Категория')),
                  const SizedBox(height: 10),
                  DropdownButtonFormField(
                    decoration: const InputDecoration(labelText: 'Должность'),
                    value: selectedPosition,
                    items: _referenceData['positions']?.map((p) => DropdownMenuItem(
                      value: p,
                      child: Text(p['position_Name']),
                    )).toList(),
                    onChanged: (val) => setStateDialog(() => selectedPosition = val),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField(
                    decoration: const InputDecoration(labelText: 'Ученая степень'),
                    value: selectedDegree,
                    items: _referenceData['degrees']?.map((d) => DropdownMenuItem(
                      value: d,
                      child: Text(d['degree_Name']),
                    )).toList(),
                    onChanged: (val) => setStateDialog(() => selectedDegree = val),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField(
                    decoration: const InputDecoration(labelText: 'Занятость'),
                    value: selectedEmployment,
                    items: _referenceData['employments']?.map((e) => DropdownMenuItem(
                      value: e,
                      child: Text(e['employment_Name']),
                    )).toList(),
                    onChanged: (val) => setStateDialog(() => selectedEmployment = val),
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
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
            ElevatedButton(
              onPressed: () async {
                String? userId;
                
                if (currentUserRole == 2 && !isEdit && usernameCtrl.text.isNotEmpty) {
                  var userData = {
                    'username': usernameCtrl.text,
                    'password': passwordCtrl.text,
                    'role_Id': 3,
                    'pck_Id': currentUserPckId,
                    'createdBy': currentUserId,
                  };
                  
                  var userResponse = await _dio.post('/users', data: userData);
                  userId = userResponse.data['id']?.toString();
                }
                else if (currentUserRole == 1 && !isEdit && usernameCtrl.text.isNotEmpty) {
                  var userData = {
                    'username': usernameCtrl.text,
                    'password': passwordCtrl.text,
                    'role_Id': 3,
                    'pck_Id': selectedPck?['id_PCK'] ?? currentUserPckId,
                    'createdBy': currentUserId,
                  };
                  
                  var userResponse = await _dio.post('/users', data: userData);
                  userId = userResponse.data['id']?.toString();
                }
                else if (selectedUser != null) {
                  userId = selectedUser['id']?.toString();
                }
                
                if (userId == null || userId.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Необходимо указать пользователя'), backgroundColor: Colors.red)
                  );
                  return;
                }
                
                Map<String, dynamic> data = {
                  'user_Id': userId,
                  'fio': fioCtrl.text,
                  'pck_Id': selectedPck?['id_PCK'] ?? (currentUserRole == 2 ? currentUserPckId : 0),
                  'kN_Number': int.tryParse(knCtrl.text),
                  'category': categoryCtrl.text,
                  'position_Id': selectedPosition?['id_Position'],
                  'degree_Id': selectedDegree?['id_Degree'],
                  'employment_Id': selectedEmployment?['id_Employment'],
                  'has_Higher_Education': hasHigherEducation,
                };
                
                String tableName = _getTableNameForApi(_currentTable);
                if (isEdit) {
                  await _dio.put('/$tableName/${existingItem!['id_Teacher']}', data: data);
                } else {
                  await _dio.post('/$tableName', data: data);
                }
                Navigator.pop(ctx);
                _loadData();
              },
              child: Text(isEdit ? 'Сохранить' : 'Добавить'),
            ),
          ],
        ),
      ),
    );
  }

  void _showGroupForm({Map? existingItem}) {
    bool isEdit = existingItem != null;
    TextEditingController nameCtrl = TextEditingController(text: isEdit ? existingItem['group_Name'] ?? '' : '');
    TextEditingController admissionCtrl = TextEditingController(text: isEdit ? existingItem['admission_Year']?.toString() ?? '' : '');
    TextEditingController formCtrl = TextEditingController(text: isEdit ? existingItem['education_Form'] ?? '' : '');
    
    dynamic selectedCurriculum = isEdit ? _findById(_referenceData['curriculums'], existingItem['id_UP']) : null;

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
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Название группы')),
                const SizedBox(height: 10),
                DropdownButtonFormField(
                  decoration: const InputDecoration(labelText: 'Учебный план'),
                  value: selectedCurriculum,
                  items: _referenceData['curriculums']?.map((c) => DropdownMenuItem(
                    value: c,
                    child: Text(c['short_Name_UP'] ?? c['full_Name_UP']),
                  )).toList(),
                  onChanged: (val) => setStateDialog(() => selectedCurriculum = val),
                ),
                const SizedBox(height: 10),
                TextField(controller: admissionCtrl, decoration: const InputDecoration(labelText: 'Год поступления')),
                const SizedBox(height: 10),
                TextField(controller: formCtrl, decoration: const InputDecoration(labelText: 'Форма обучения')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
            ElevatedButton(
              onPressed: () async {
                Map<String, dynamic> data = {
                  'group_Name': nameCtrl.text,
                  'id_UP': selectedCurriculum?['id_UP'] ?? 0,
                  'admission_Year': int.tryParse(admissionCtrl.text),
                  'education_Form': formCtrl.text,
                };
                
                String tableName = _getTableNameForApi(_currentTable);
                if (isEdit) {
                  await _dio.put('/$tableName/${existingItem!['id_Group']}', data: data);
                } else {
                  await _dio.post('/$tableName', data: data);
                }
                Navigator.pop(ctx);
                _loadData();
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
    
    dynamic selectedSpecialty = isEdit ? _findById(_referenceData['specialties'], existingItem['specialty_Id']) : null;

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
                TextField(controller: fullNameCtrl, decoration: const InputDecoration(labelText: 'Полное название')),
                const SizedBox(height: 10),
                TextField(controller: shortNameCtrl, decoration: const InputDecoration(labelText: 'Краткое название')),
                const SizedBox(height: 10),
                DropdownButtonFormField(
                  decoration: const InputDecoration(labelText: 'Специальность'),
                  value: selectedSpecialty,
                  items: _referenceData['specialties']?.map((s) => DropdownMenuItem(
                    value: s,
                    child: Text(s['short_Name_Specialty'] ?? s['full_Name_Specialty']),
                  )).toList(),
                  onChanged: (val) => setStateDialog(() => selectedSpecialty = val),
                ),
                const SizedBox(height: 10),
                TextField(controller: yearCtrl, decoration: const InputDecoration(labelText: 'Год утверждения')),
                const SizedBox(height: 10),
                TextField(controller: formCtrl, decoration: const InputDecoration(labelText: 'Форма обучения')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
            ElevatedButton(
              onPressed: () async {
                Map<String, dynamic> data = {
                  'full_Name_UP': fullNameCtrl.text,
                  'short_Name_UP': shortNameCtrl.text,
                  'specialty_Id': selectedSpecialty?['id_Specialty'],
                  'year_Approved': int.tryParse(yearCtrl.text),
                  'education_Form': formCtrl.text,
                };
                
                String tableName = _getTableNameForApi(_currentTable);
                if (isEdit) {
                  await _dio.put('/$tableName/${existingItem!['id_UP']}', data: data);
                } else {
                  await _dio.post('/$tableName', data: data);
                }
                Navigator.pop(ctx);
                _loadData();
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
    
    dynamic selectedPck = isEdit ? _findById(_referenceData['pck'], existingItem['pck_Id']) : 
        (currentUserRole == 2 && pckList.isNotEmpty ? pckList.first : null);
    dynamic selectedCycle = isEdit ? _findById(_referenceData['cycles'], existingItem['cycle_Id']) : null;

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
                TextField(controller: fullNameCtrl, decoration: const InputDecoration(labelText: 'Полное название')),
                const SizedBox(height: 10),
                TextField(controller: shortNameCtrl, decoration: const InputDecoration(labelText: 'Краткое название')),
                const SizedBox(height: 10),
                DropdownButtonFormField(
                  decoration: const InputDecoration(labelText: 'ПЦК'),
                  value: selectedPck,
                  items: pckList.map((p) => DropdownMenuItem(
                    value: p,
                    child: Text(p['short_PCK_Name'] ?? p['full_PCK_Name']),
                  )).toList(),
                  onChanged: (currentUserRole == 1) ? (val) => setStateDialog(() => selectedPck = val) : null,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField(
                  decoration: const InputDecoration(labelText: 'Цикл дисциплин'),
                  value: selectedCycle,
                  items: _referenceData['cycles']?.map((c) => DropdownMenuItem(
                    value: c,
                    child: Text(c['short_Cycle_Name'] ?? c['full_Cycle_Name']),
                  )).toList(),
                  onChanged: (val) => setStateDialog(() => selectedCycle = val),
                ),
                const SizedBox(height: 10),
                TextField(controller: practiceCtrl, decoration: const InputDecoration(labelText: 'Тип практики')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
            ElevatedButton(
              onPressed: () async {
                Map<String, dynamic> data = {
                  'full_Discipline_Name': fullNameCtrl.text,
                  'short_Discipline_Name': shortNameCtrl.text,
                  'pck_Id': selectedPck?['id_PCK'] ?? 0,
                  'cycle_Id': selectedCycle?['id_Cycle'],
                  'practice_Type': practiceCtrl.text,
                };
                
                String tableName = _getTableNameForApi(_currentTable);
                if (isEdit) {
                  await _dio.put('/$tableName/${existingItem!['id_Discipline']}', data: data);
                } else {
                  await _dio.post('/$tableName', data: data);
                }
                Navigator.pop(ctx);
                _loadData();
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
    
    dynamic selectedCurriculum = isEdit ? _findById(_referenceData['curriculums'], existingItem['up_Id']) : null;
    dynamic selectedDiscipline = isEdit ? _findById(_referenceData['disciplines'], existingItem['discipline_Id']) : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: Text('${isEdit ? 'Изменить' : 'Добавить'} нагрузку'),
          content: SizedBox(
            width: 600,
            height: 600,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField(
                    decoration: const InputDecoration(labelText: 'Учебный план'),
                    value: selectedCurriculum,
                    items: _referenceData['curriculums']?.map((c) => DropdownMenuItem(
                      value: c,
                      child: Text(c['short_Name_UP'] ?? c['full_Name_UP']),
                    )).toList(),
                    onChanged: (val) => setStateDialog(() => selectedCurriculum = val),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField(
                    decoration: const InputDecoration(labelText: 'Дисциплина'),
                    value: selectedDiscipline,
                    items: _referenceData['disciplines']?.map((d) => DropdownMenuItem(
                      value: d,
                      child: Text(d['short_Discipline_Name'] ?? d['full_Discipline_Name']),
                    )).toList(),
                    onChanged: (val) => setStateDialog(() => selectedDiscipline = val),
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: semesterCtrl, decoration: const InputDecoration(labelText: 'Семестр')),
                  const SizedBox(height: 10),
                  TextField(controller: hoursCtrl, decoration: const InputDecoration(labelText: 'Всего часов')),
                  const SizedBox(height: 10),
                  TextField(controller: subgroupCtrl, decoration: const InputDecoration(labelText: 'Номер подгруппы')),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: TextField(controller: lecturesCtrl, decoration: const InputDecoration(labelText: 'Лекции'))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: labCtrl, decoration: const InputDecoration(labelText: 'Лабораторные'))),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: TextField(controller: practiceCtrl, decoration: const InputDecoration(labelText: 'Практические'))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: consultCtrl, decoration: const InputDecoration(labelText: 'Консультации'))),
                  ]),
                  const SizedBox(height: 10),
                  TextField(controller: defenseCtrl, decoration: const InputDecoration(labelText: 'Защита курсовой (часы)')),
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
                  'up_Id': selectedCurriculum?['id_UP'] ?? 0,
                  'discipline_Id': selectedDiscipline?['id_Discipline'] ?? 0,
                  'semester': int.tryParse(semesterCtrl.text) ?? 0,
                  'total_Hours': int.tryParse(hoursCtrl.text),
                  'subgroup_Number': int.tryParse(subgroupCtrl.text),
                  'lectures': int.tryParse(lecturesCtrl.text),
                  'lab_Works': int.tryParse(labCtrl.text),
                  'practice_Works': int.tryParse(practiceCtrl.text),
                  'consultations': int.tryParse(consultCtrl.text),
                  'course_Work_Defense': int.tryParse(defenseCtrl.text),
                  'is_Credit': isCredit,
                  'is_Diff_Credit': isDiffCredit,
                  'is_Exam': isExam,
                  'is_Complex_Exam': isComplexExam,
                  'is_Control_Work': isControlWork,
                  'is_Course_Work': isCourseWork,
                };
                
                String tableName = _getTableNameForApi(_currentTable);
                if (isEdit) {
                  await _dio.put('/$tableName/${existingItem!['id_Load']}', data: data);
                } else {
                  await _dio.post('/$tableName', data: data);
                }
                Navigator.pop(ctx);
                _loadData();
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
    
    dynamic selectedGroup = isEdit ? _findById(_referenceData['groups'], existingItem['group_Id']) : null;
    dynamic selectedYear = isEdit ? _findById(_referenceData['academicYears'], existingItem['academicYear_Id']) : null;

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
                DropdownButtonFormField(
                  decoration: const InputDecoration(labelText: 'Группа'),
                  value: selectedGroup,
                  items: _referenceData['groups']?.map((g) => DropdownMenuItem(
                    value: g,
                    child: Text(g['group_Name']),
                  )).toList(),
                  onChanged: (val) => setStateDialog(() => selectedGroup = val),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField(
                  decoration: const InputDecoration(labelText: 'Учебный год'),
                  value: selectedYear,
                  items: _referenceData['academicYears']?.map((y) => DropdownMenuItem(
                    value: y,
                    child: Text(y['start_Year'].toString()),
                  )).toList(),
                  onChanged: (val) => setStateDialog(() => selectedYear = val),
                ),
                const SizedBox(height: 10),
                TextField(controller: budgetCtrl, decoration: const InputDecoration(labelText: 'Бюджетников')),
                const SizedBox(height: 10),
                TextField(controller: contractCtrl, decoration: const InputDecoration(labelText: 'Контрактников')),
                const SizedBox(height: 10),
                TextField(controller: subgroupCtrl, decoration: const InputDecoration(labelText: 'Кол-во в 1 подгруппе')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
            ElevatedButton(
              onPressed: () async {
                Map<String, dynamic> data = {
                  'group_Id': selectedGroup?['id_Group'] ?? 0,
                  'academicYear_Id': selectedYear?['id_AcademicYear'] ?? 0,
                  'budget_Students': int.tryParse(budgetCtrl.text),
                  'contract_Students': int.tryParse(contractCtrl.text),
                  'first_Subgroup_Count': int.tryParse(subgroupCtrl.text),
                };
                
                String tableName = _getTableNameForApi(_currentTable);
                if (isEdit) {
                  await _dio.put('/$tableName/${existingItem!['id_Group_AcademicYear']}', data: data);
                } else {
                  await _dio.post('/$tableName', data: data);
                }
                Navigator.pop(ctx);
                _loadData();
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
    
    dynamic selectedLoad = isEdit ? _findById(_referenceData['loads'], existingItem['load_UP_Id']) : null;
    dynamic selectedGroup = isEdit ? _findById(_referenceData['groups'], existingItem['group_Id']) : null;
    dynamic selectedTeacher = isEdit ? _findById(teachersList, existingItem['teacher_Id']) : null;

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
                  DropdownButtonFormField(
                    decoration: const InputDecoration(labelText: 'Нагрузка'),
                    value: selectedLoad,
                    items: _referenceData['loads']?.map((l) => DropdownMenuItem(
                      value: l,
                      child: Text('${l['id_Load']} - Дисциплина: ${l['discipline_Id']}'),
                    )).toList(),
                    onChanged: (val) => setStateDialog(() => selectedLoad = val),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField(
                    decoration: const InputDecoration(labelText: 'Группа'),
                    value: selectedGroup,
                    items: _referenceData['groups']?.map((g) => DropdownMenuItem(
                      value: g,
                      child: Text(g['group_Name']),
                    )).toList(),
                    onChanged: (val) => setStateDialog(() => selectedGroup = val),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField(
                    decoration: const InputDecoration(labelText: 'Преподаватель'),
                    value: selectedTeacher,
                    items: teachersList.map((t) => DropdownMenuItem(
                      value: t,
                      child: Text(t['fio'] ?? 'Преподаватель ${t['id_Teacher']}'),
                    )).toList(),
                    onChanged: (val) => setStateDialog(() => selectedTeacher = val),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: TextField(controller: lecturesCtrl, decoration: const InputDecoration(labelText: 'Лекции'))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: labCtrl, decoration: const InputDecoration(labelText: 'Лабораторные'))),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: TextField(controller: practiceCtrl, decoration: const InputDecoration(labelText: 'Практические'))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: consultCtrl, decoration: const InputDecoration(labelText: 'Консультации'))),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: TextField(controller: creditCtrl, decoration: const InputDecoration(labelText: 'Зачет'))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: diffCreditCtrl, decoration: const InputDecoration(labelText: 'Диф.зачет'))),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: TextField(controller: examCtrl, decoration: const InputDecoration(labelText: 'Экзамен'))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: complexExamCtrl, decoration: const InputDecoration(labelText: 'Компл.экзамен'))),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: TextField(controller: controlWorkCtrl, decoration: const InputDecoration(labelText: 'Контр.работа'))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: courseWorkCtrl, decoration: const InputDecoration(labelText: 'Курс.работа'))),
                  ]),
                  const SizedBox(height: 10),
                  TextField(controller: courseWorkDefenseCtrl, decoration: const InputDecoration(labelText: 'Защита курсовой')),
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
                  'load_UP_Id': selectedLoad?['id_Load'] ?? 0,
                  'group_Id': selectedGroup?['id_Group'] ?? 0,
                  'teacher_Id': selectedTeacher?['id_Teacher'] ?? 0,
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
                if (isEdit) {
                  await _dio.put('/$tableName/${existingItem!['id_ActualLoad']}', data: data);
                } else {
                  await _dio.post('/$tableName', data: data);
                }
                Navigator.pop(ctx);
                _loadData();
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
    
    if (currentUserRole == 2 && _currentTable != 'Teachers') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('У вас нет прав на редактирование этой таблицы'), backgroundColor: Colors.orange)
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
      case 'PCK':
        if (currentUserRole != 1) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Только администратор может редактировать'), backgroundColor: Colors.orange)
          );
          return;
        }
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
        else if (_currentTable == 'PCK') fields = {'full_PCK_Name': 'Полное название', 'short_PCK_Name': 'Краткое название'};
        _showSimpleForm(fields, existingItem: item);
        break;
      case 'Users':
        if (currentUserRole != 1) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Только администратор может редактировать пользователей'), backgroundColor: Colors.orange)
          );
          return;
        }
        _showUserForm(existingItem: item);
        break;
      case 'Groups':
        _showGroupForm(existingItem: item);
        break;
      case 'Curriculums':
        if (currentUserRole != 1) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Только администратор может редактировать учебные планы'), backgroundColor: Colors.orange)
          );
          return;
        }
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

  dynamic _findById(List? list, dynamic id) {
    if (list == null || id == null) return null;
    try {
      return list.firstWhere((item) => 
        (item['id_Role'] == id) ||
        (item['id_PCK'] == id) ||
        (item['id_Position'] == id) ||
        (item['id_Degree'] == id) ||
        (item['id_Employment'] == id) ||
        (item['id_Specialty'] == id) ||
        (item['id_UP'] == id) ||
        (item['id_Group'] == id) ||
        (item['id_Cycle'] == id) ||
        (item['id_Discipline'] == id) ||
        (item['id_Load'] == id) ||
        (item['id_Teacher'] == id) ||
        (item['id_AcademicYear'] == id) ||
        (item['id'] == id)
      );
    } catch (e) {
      return null;
    }
  }

  void _deleteItem(Map item) async {
    if (!canEdit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('У вас нет прав на удаление'), backgroundColor: Colors.orange)
      );
      return;
    }
    
    if (currentUserRole == 2 && _currentTable != 'Teachers') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('У вас нет прав на удаление из этой таблицы'), backgroundColor: Colors.orange)
      );
      return;
    }
    
    if (currentUserRole == 2 && _currentTable == 'Teachers') {
      if (item['pck_Id'] != currentUserPckId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Нельзя удалять преподавателей из другого ПЦК'), backgroundColor: Colors.red)
        );
        return;
      }
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
    else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Удаление для этой таблицы временно отключено'))
      );
      return;
    }
    
    try {
      await _dio.delete('/$tableName/$id');
      _loadData();
      if (mounted) {
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
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
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