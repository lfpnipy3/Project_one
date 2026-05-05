import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

void main() => runApp(const MyApp());

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
  
  // 16 таблиц
  final List<String> _tables = [
    'Roles', 'Users', 'PCK', 'Positions', 'Degrees', 'Employments',
    'Specialties', 'Curriculums', 'Groups', 'DisciplineCycles', 
    'Disciplines', 'CurriculumLoad', 'Teachers', 'AcademicYears',
    'GroupAcademicYears', 'ActualLoad'
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    setState(() => _loading = true);
    try {
      String tableName = _getTableNameForApi(_currentTable);
      var res = await _dio.get('/$tableName');
      if (mounted) setState(() => _data = res.data);
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
    Map<String, String> fields = {};
    
    switch (_currentTable) {
      case 'Roles':
        fields = {'role_Name': 'Название роли'};
        break;
        
      case 'Users':
        fields = {
          'username': 'Логин',
          'passwordHash': 'Пароль',
          'role_Id': 'ID роли',
          'pck_Id': 'ID ПЦК (опционально)'
        };
        break;
        
      case 'Positions':
        fields = {'position_Name': 'Название должности'};
        break;
        
      case 'Degrees':
        fields = {'degree_Name': 'Название степени'};
        break;
        
      case 'Employments':
        fields = {'employment_Name': 'Название занятости', 'format': 'Формат (полная/частичная)'};
        break;
        
      case 'DisciplineCycles':
        fields = {
          'full_Cycle_Name': 'Полное название цикла',
          'short_Cycle_Name': 'Краткое название',
          'discipline_Group': 'Группа дисциплин'
        };
        break;
        
      case 'AcademicYears':
        fields = {'start_Year': 'Год начала (например: 2024)'};
        break;
        
      case 'Specialties':
        fields = {
          'full_Name_Specialty': 'Полное название специальности',
          'short_Name_Specialty': 'Краткое название'
        };
        break;
        
      case 'PCK':
        fields = {
          'full_PCK_Name': 'Полное название ПЦК',
          'short_PCK_Name': 'Краткое название ПЦК'
        };
        break;
        
      case 'Groups':
        fields = {
          'group_Name': 'Название группы',
          'id_UP': 'ID учебного плана',
          'admission_Year': 'Год поступления',
          'education_Form': 'Форма обучения (очная/заочная)'
        };
        break;
        
      case 'Curriculums':
        fields = {
          'full_Name_UP': 'Полное название УП',
          'short_Name_UP': 'Краткое название',
          'year_Approved': 'Год утверждения',
          'education_Form': 'Форма обучения',
          'specialty_Id': 'ID специальности'
        };
        break;
        
      case 'Disciplines':
        fields = {
          'full_Discipline_Name': 'Полное название дисциплины',
          'short_Discipline_Name': 'Краткое название',
          'pck_Id': 'ID ПЦК',
          'cycle_Id': 'ID цикла',
          'practice_Type': 'Тип практики'
        };
        break;
        
      case 'CurriculumLoad':
        fields = {
          'up_Id': 'ID учебного плана',
          'discipline_Id': 'ID дисциплины',
          'semester': 'Семестр',
          'total_Hours': 'Всего часов',
          'subgroup_Number': 'Номер подгруппы',
          'lectures': 'Лекции',
          'lab_Works': 'Лабораторные',
          'practice_Works': 'Практические',
          'consultations': 'Консультации',
          'is_Credit': 'Зачет (true/false)',
          'is_Diff_Credit': 'Диф.зачет (true/false)',
          'is_Exam': 'Экзамен (true/false)'
        };
        break;
        
      case 'Teachers':
        fields = {
          'user_Id': 'ID пользователя (GUID)',
          'fio': 'ФИО',
          'pck_Id': 'ID ПЦК',
          'kN_Number': 'Номер КН',
          'category': 'Категория',
          'degree_Id': 'ID степени',
          'position_Id': 'ID должности',
          'employment_Id': 'ID занятости',
          'has_Higher_Education': 'Высшее образование (true/false)'
        };
        break;
        
      case 'GroupAcademicYears':
        fields = {
          'group_Id': 'ID группы',
          'academicYear_Id': 'ID учебного года',
          'budget_Students': 'Кол-во бюджетников',
          'contract_Students': 'Кол-во контрактников',
          'first_Subgroup_Count': 'Кол-во в 1 подгруппе'
        };
        break;
        
      case 'ActualLoad':
        fields = {
          'load_UP_Id': 'ID нагрузки',
          'group_Id': 'ID группы',
          'teacher_Id': 'ID преподавателя',
          'lectures': 'Лекции (часы)',
          'lab_Works': 'Лабораторные',
          'practice_Works': 'Практические',
          'consultations': 'Консультации',
          'credit': 'Зачет',
          'diff_Credit': 'Диф.зачет',
          'exam': 'Экзамен',
          'complex_Exam': 'Компл.экзамен',
          'control_Work': 'Контр.работа',
          'course_Work': 'Курс.работа',
          'course_Work_Defense': 'Защита курсовой',
          'is_Approved': 'Утверждено (true/false)'
        };
        break;
        
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Добавление для $_currentTable в разработке'))
        );
        return;
    }
    
    _showAddForm(fields);
  }

  void _showAddForm(Map<String, String> fields) {
    Map<String, TextEditingController> controllers = {};
    fields.forEach((key, label) {
      controllers[key] = TextEditingController();
    });

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Добавить в ${_getRussianName(_currentTable)}'),
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
                  decoration: InputDecoration(
                    labelText: e.value,
                    border: const OutlineInputBorder(),
                    hintText: e.key == 'user_Id' ? 'Пример: 123e4567-e89b-12d3-a456-426614174000' : '',
                  ),
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
                
                // Преобразуем типы данных
                if (key == 'id_UP' || key == 'specialty_Id' || key == 'course' || 
                    key == 'cycle_Id' || key == 'pck_Id' || key == 'pCK_Id' ||
                    key == 'up_Id' || key == 'discipline_Id' || key == 'semester' ||
                    key == 'total_Hours' || key == 'subgroup_Number' || key == 'lectures' ||
                    key == 'lab_Works' || key == 'practice_Works' || key == 'consultations' ||
                    key == 'kN_Number' || key == 'degree_Id' || key == 'position_Id' ||
                    key == 'employment_Id' || key == 'group_Id' || key == 'academicYear_Id' ||
                    key == 'budget_Students' || key == 'contract_Students' || 
                    key == 'first_Subgroup_Count' || key == 'load_UP_Id' || key == 'teacher_Id' ||
                    key == 'role_Id' || key == 'start_Year' || key == 'year_Approved' ||
                    key == 'admission_Year' || key == 'course_Work_Defense') {
                  data[key] = int.tryParse(val) ?? 0;
                }
                else if (key == 'user_Id' || key == 'manager_Id') {
                  data[key] = val.isEmpty ? null : val;
                }
                else if (key == 'is_Credit' || key == 'is_Diff_Credit' || 
                         key == 'is_Exam' || key == 'is_Complex_Exam' ||
                         key == 'is_Control_Work' || key == 'is_Course_Work' ||
                         key == 'has_Higher_Education' || key == 'is_Approved' ||
                         key == 'can_Edit') {
                  data[key] = val.toLowerCase() == 'true';
                }
                else if (key == 'credit' || key == 'diff_Credit' || key == 'exam' ||
                         key == 'complex_Exam' || key == 'control_Work' ||
                         key == 'course_Work') {
                  data[key] = double.tryParse(val) ?? 0.0;
                }
                else {
                  data[key] = val;
                }
              });
              
              // Для Users нужно добавить временную соль
              if (_currentTable == 'Users') {
                if (!data.containsKey('salt')) {
                  data['salt'] = 'temporary_salt_for_' + DateTime.now().millisecondsSinceEpoch.toString();
                }
              }
              
              String tableName = _getTableNameForApi(_currentTable);
              await _dio.post('/$tableName', data: data);
              if (mounted) Navigator.pop(ctx);
              _loadData();
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
  }

  void _editItem(Map item) {
    Map<String, String> fields = {};
    String idField = '';
    
    switch (_currentTable) {
      case 'Roles':
        fields = {'role_Name': 'Название роли'};
        idField = 'id_Role';
        break;
        
      case 'Users':
        fields = {
          'username': 'Логин',
          'role_Id': 'ID роли',
          'pck_Id': 'ID ПЦК'
        };
        idField = 'id';
        break;
        
      case 'PCK':
        fields = {
          'full_PCK_Name': 'Полное название ПЦК',
          'short_PCK_Name': 'Краткое название ПЦК'
        };
        idField = 'id_PCK';
        break;
        
      case 'Positions':
        fields = {'position_Name': 'Название должности'};
        idField = 'id_Position';
        break;
        
      case 'Degrees':
        fields = {'degree_Name': 'Название степени'};
        idField = 'id_Degree';
        break;
        
      case 'Employments':
        fields = {'employment_Name': 'Название занятости', 'format': 'Формат'};
        idField = 'id_Employment';
        break;
        
      case 'Specialties':
        fields = {
          'full_Name_Specialty': 'Полное название специальности',
          'short_Name_Specialty': 'Краткое название'
        };
        idField = 'id_Specialty';
        break;
        
      case 'Curriculums':
        fields = {
          'full_Name_UP': 'Полное название УП',
          'short_Name_UP': 'Краткое название',
          'year_Approved': 'Год утверждения',
          'education_Form': 'Форма обучения',
          'specialty_Id': 'ID специальности'
        };
        idField = 'id_UP';
        break;
        
      case 'Groups':
        fields = {
          'group_Name': 'Название группы',
          'id_UP': 'ID учебного плана',
          'admission_Year': 'Год поступления',
          'education_Form': 'Форма обучения'
        };
        idField = 'id_Group';
        break;
        
      case 'DisciplineCycles':
        fields = {
          'full_Cycle_Name': 'Полное название цикла',
          'short_Cycle_Name': 'Краткое название',
          'discipline_Group': 'Группа дисциплин'
        };
        idField = 'id_Cycle';
        break;
        
      case 'Disciplines':
        fields = {
          'full_Discipline_Name': 'Полное название дисциплины',
          'short_Discipline_Name': 'Краткое название',
          'pck_Id': 'ID ПЦК',
          'cycle_Id': 'ID цикла',
          'practice_Type': 'Тип практики'
        };
        idField = 'id_Discipline';
        break;
        
      case 'CurriculumLoad':
        fields = {
          'up_Id': 'ID учебного плана',
          'discipline_Id': 'ID дисциплины',
          'semester': 'Семестр',
          'total_Hours': 'Всего часов',
          'subgroup_Number': 'Номер подгруппы',
          'lectures': 'Лекции',
          'lab_Works': 'Лабораторные',
          'practice_Works': 'Практические',
          'consultations': 'Консультации',
          'is_Credit': 'Зачет',
          'is_Diff_Credit': 'Диф.зачет',
          'is_Exam': 'Экзамен'
        };
        idField = 'id_Load';
        break;
        
      case 'Teachers':
        fields = {
          'fio': 'ФИО',
          'pck_Id': 'ID ПЦК',
          'kN_Number': 'Номер КН',
          'category': 'Категория',
          'degree_Id': 'ID степени',
          'position_Id': 'ID должности',
          'employment_Id': 'ID занятости',
          'has_Higher_Education': 'Высшее образование'
        };
        idField = 'id_Teacher';
        break;
        
      case 'AcademicYears':
        fields = {'start_Year': 'Год начала', 'can_Edit': 'Можно редактировать'};
        idField = 'id_AcademicYear';
        break;
        
      case 'GroupAcademicYears':
        fields = {
          'group_Id': 'ID группы',
          'academicYear_Id': 'ID учебного года',
          'budget_Students': 'Бюджетников',
          'contract_Students': 'Контрактников',
          'first_Subgroup_Count': 'Кол-во в 1 подгруппе'
        };
        idField = 'id_Group_AcademicYear';
        break;
        
      case 'ActualLoad':
        fields = {
          'lectures': 'Лекции',
          'lab_Works': 'Лабораторные',
          'practice_Works': 'Практические',
          'consultations': 'Консультации',
          'credit': 'Зачет',
          'diff_Credit': 'Диф.зачет',
          'exam': 'Экзамен',
          'complex_Exam': 'Компл.экзамен',
          'control_Work': 'Контр.работа',
          'course_Work': 'Курс.работа',
          'course_Work_Defense': 'Защита курсовой',
          'is_Approved': 'Утверждено'
        };
        idField = 'id_ActualLoad';
        break;
        
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Редактирование для $_currentTable в разработке'))
        );
        return;
    }
    
    _showEditForm(fields, item, idField);
  }

  void _showEditForm(Map<String, String> fields, Map item, String idField) {
    Map<String, TextEditingController> controllers = {};
    fields.forEach((key, label) {
      controllers[key] = TextEditingController(text: item[key]?.toString() ?? '');
    });

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Изменить в ${_getRussianName(_currentTable)}'),
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
                  decoration: InputDecoration(
                    labelText: e.value,
                    border: const OutlineInputBorder(),
                  ),
                ),
              )).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () async {
              Map<String, dynamic> newData = {};
              fields.forEach((key, _) {
                String val = controllers[key]!.text;
                
                if (key == 'id_UP' || key == 'specialty_Id' || key == 'course' || 
                    key == 'cycle_Id' || key == 'pck_Id' || key == 'pCK_Id' ||
                    key == 'up_Id' || key == 'discipline_Id' || key == 'semester' ||
                    key == 'total_Hours' || key == 'subgroup_Number' || key == 'lectures' ||
                    key == 'lab_Works' || key == 'practice_Works' || key == 'consultations' ||
                    key == 'kN_Number' || key == 'degree_Id' || key == 'position_Id' ||
                    key == 'employment_Id' || key == 'group_Id' || key == 'academicYear_Id' ||
                    key == 'budget_Students' || key == 'contract_Students' || 
                    key == 'first_Subgroup_Count' || key == 'load_UP_Id' || key == 'teacher_Id' ||
                    key == 'role_Id' || key == 'start_Year' || key == 'year_Approved' ||
                    key == 'admission_Year') {
                  newData[key] = int.tryParse(val) ?? 0;
                }
                else if (key == 'is_Credit' || key == 'is_Diff_Credit' || 
                         key == 'is_Exam' || key == 'is_Complex_Exam' ||
                         key == 'is_Control_Work' || key == 'is_Course_Work' ||
                         key == 'has_Higher_Education' || key == 'is_Approved' ||
                         key == 'can_Edit') {
                  newData[key] = val.toLowerCase() == 'true';
                }
                else if (key == 'credit' || key == 'diff_Credit' || key == 'exam' ||
                         key == 'complex_Exam' || key == 'control_Work' ||
                         key == 'course_Work' || key == 'course_Work_Defense') {
                  newData[key] = double.tryParse(val) ?? 0.0;
                }
                else {
                  newData[key] = val;
                }
              });
              
              String id = item[idField].toString();
              String tableName = _getTableNameForApi(_currentTable);
              await _dio.put('/$tableName/$id', data: newData);
              if (mounted) Navigator.pop(ctx);
              _loadData();
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _deleteItem(Map item) async {
    // Подтверждение удаления
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
          children: _tables.map((t) => ListTile(
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
      floatingActionButton: FloatingActionButton(
        onPressed: _addItem,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildContent() {
    // Если данные пусты - показываем красивое сообщение
    if (_data.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox,
              size: 120,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 20),
            Text(
              'Нет данных ${_getRussianName(_currentTable)}',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Нажмите кнопку + чтобы добавить',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade500,
              ),
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
            ...keys.map((k) => DataColumn(
              label: Text(
                k.toString(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            )),
            const DataColumn(
              label: Text('Действия', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
          rows: _data.map((row) => DataRow(
            cells: [
              ...keys.map((k) => DataCell(
                Container(
                  constraints: const BoxConstraints(maxWidth: 250),
                  child: Text(
                    row[k]?.toString() ?? '',
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              )),
              DataCell(
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _editItem(row),
                      tooltip: 'Редактировать',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteItem(row),
                      tooltip: 'Удалить',
                    ),
                  ],
                ),
              ),
            ],
          )).toList(),
        ),
      ),
    );
  }
}