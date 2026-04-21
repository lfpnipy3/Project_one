import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

void main() {
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(backgroundColor: Colors.white, body: AuthPage()),
    ),
  );
}

// Адрес твоего сервера
const String baseUrl = "http://127.0.0.1:5234";

// ==========================================
// 🔐 ЭКРАН 1: АВТОРИЗАЦИЯ
// ==========================================
class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final TextEditingController _loginController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final dio = Dio();

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkAuth() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.blue)),
    );

    try {
      final response = await dio.post(
        '$baseUrl/login',
        queryParameters: {
          'username': _loginController.text,
          'password': _passwordController.text,
        },
      );

      Navigator.pop(context); // Убираем загрузку

      if (response.statusCode == 200) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainPage()),
        );
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка входа! Проверьте данные.'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Center(
        child: Container(
          width: 420.0,
          margin: const EdgeInsets.symmetric(vertical: 60),
          padding: const EdgeInsets.all(32.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24.0),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: Text('Hello World*', style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.blue))),
              const SizedBox(height: 24),
              TextField(controller: _loginController, decoration: const InputDecoration(labelText: 'Логин', border: OutlineInputBorder())),
              const SizedBox(height: 16),
              TextField(controller: _passwordController, obscureText: true, decoration: const InputDecoration(labelText: 'Пароль', border: OutlineInputBorder())),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(minimumSize: const Size(0, 56), backgroundColor: Colors.blue, foregroundColor: Colors.white),
                onPressed: _checkAuth,
                child: const Text('Войти'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 🛠️ ЭКРАН 2: ГЛАВНАЯ ПАНЕЛЬ
// ==========================================
class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with TickerProviderStateMixin {
  final List<String> _openTabs = ['Панель инструментов'];
  late TabController _tabController;
  final dio = Dio();
  List<_Employee> _employees = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _openTabs.length, vsync: this);
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    try {
      final res = await dio.get('$baseUrl/employees');
      final List data = res.data;
      setState(() {
        _employees = data.map((e) => _Employee(
          e['id'], e['name'], e['role'], e['status'], 
          e['status'] == 'Активен' ? Colors.green : Colors.orange
        )).toList();
      });
    } catch (e) { print("Ошибка загрузки: $e"); }
  }

  Future<void> _deleteFromDb(int id) async {
    await dio.delete('$baseUrl/employees/$id');
    _loadEmployees();
  }

  void _openNewTab(String title) {
    setState(() {
      if (_openTabs.contains(title)) {
        _tabController.animateTo(_openTabs.indexOf(title));
        return;
      }
      _openTabs.add(title);
      _tabController = TabController(length: _openTabs.length, vsync: this);
      WidgetsBinding.instance.addPostFrameCallback((_) => _tabController.animateTo(_openTabs.length - 1));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          _buildHeader(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _openTabs.map((title) {
                if (title == 'Панель инструментов') return _buildToolsGrid();
                if (title == 'Сотрудники') return _buildEmployeeTable();
                return Center(child: Text('Экран: $title'));
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        tabs: _openTabs.map((t) => Tab(text: t)).toList(),
      ),
    );
  }

  Widget _buildEmployeeTable() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: PaginatedDataTable(
        columns: const [DataColumn(label: Text('Сотрудник')), DataColumn(label: Text('Должность')), DataColumn(label: Text('Статус')), DataColumn(label: Text('Действия'))],
        source: _EmployeeDataSource(_employees, context, _deleteFromDb),
        rowsPerPage: 5,
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text('MY APP', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)), Text('Администратор')],
      ),
    );
  }

  Widget _buildToolsGrid() {
    return GridView.count(
      crossAxisCount: 3,
      padding: const EdgeInsets.all(32),
      children: [
        _buildToolCard(Icons.people, 'Сотрудники'),
        _buildToolCard(Icons.analytics, 'Аналитика'),
      ],
    );
  }

  Widget _buildToolCard(IconData icon, String title) {
    return InkWell(
      onTap: () => _openNewTab(title),
      child: Card(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 40, color: Colors.blue), Text(title)])),
    );
  }
}

class _Employee {
  final int id;
  final String name;
  final String role;
  final String status;
  final Color statusColor;
  _Employee(this.id, this.name, this.role, this.status, this.statusColor);
}

class _EmployeeDataSource extends DataTableSource {
  final List<_Employee> _employees;
  final BuildContext context;
  final Function(int) onDelete;
  _EmployeeDataSource(this._employees, this.context, this.onDelete);

  @override
  DataRow? getRow(int index) {
    if (index >= _employees.length) return null;
    final emp = _employees[index];
    return DataRow.byIndex(index: index, cells: [
      DataCell(Text(emp.name)),
      DataCell(Text(emp.role)),
      DataCell(Text(emp.status)),
      DataCell(IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => onDelete(emp.id))),
    ]);
  }
  @override int get rowCount => _employees.length;
  @override bool get isRowCountApproximate => false;
  @override int get selectedRowCount => 0;
}
