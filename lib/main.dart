import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:rxdart/rxdart.dart';
import 'package:faker/faker.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  if (!Hive.isBoxOpen('names')) {
    await Hive.openBox<String>('names');
  }
  await setupHiveAndStoreData(10, 20);
  runApp(const MyApp());
}

Future<void> setupHiveAndStoreData(int numPages, int itemsPerPage) async {
  var box = Hive.box<String>('names');
  if (box.isEmpty) {
    for (int page = 0; page < numPages; page++) {
      for (int i = 0; i < itemsPerPage; i++) {
        String uniqueName = faker.person.name();
        await box.add(uniqueName);
      }
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final BehaviorSubject<List<String>> _dataSubject = BehaviorSubject<List<String>>.seeded([]);
  final ScrollController _scrollController = ScrollController();
  final int _perPage = 20;
  int _currentPage = 0;
  late Box<String> _box;
  bool _isLoading = false;
  TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _box = Hive.box<String>('names');
    loadData();
    _searchController.addListener(() {
      filterSearchResults(_searchController.text);
    });
  }

  @override
  void dispose() {
    _dataSubject.close();
    _scrollController.dispose();
    Hive.close();
    _searchController.dispose();
    super.dispose();
  }

  void loadData() {
    if (!_isLoading) {
      setState(() {
        _isLoading = true;
      });
      Future.delayed(const Duration(seconds: 1), () {
        List<String> newData = [];
        for (int i = _currentPage * _perPage; i < (_currentPage + 1) * _perPage && i < _box.length; i++) {
          newData.add(_box.getAt(i)!);
        }
        if (newData.isNotEmpty) {
          _dataSubject.add(List.from(_dataSubject.value)..addAll(newData));
          _currentPage++;
        }
        setState(() {
          _isLoading = false;
        });
      });
    }
  }

  void _scrollListener() {
    if (_scrollController.offset >= _scrollController.position.maxScrollExtent &&
        !_scrollController.position.outOfRange && !_isLoading) {
      loadData();
    }
  }

  void filterSearchResults(String query) {
    if(query.isEmpty) {
      _dataSubject.add(_box.values.toList());
    } else {
      List<String> filteredList = _box.values.where((item) => item.toLowerCase().contains(query.toLowerCase())).toList();
      _dataSubject.add(filteredList);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: <Widget>[
            Expanded(
              flex: 1,
              child: Text('Infinite Scroll (Local Storage)'),
            ),
            Expanded(
              flex: 1,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: "Search...",
                  border: InputBorder.none,
                  fillColor: Colors.white,
                  filled: true,
                ),
              ),
            ),
          ],
        ),
      ),
      body: StreamBuilder<List<String>>(
        stream: _dataSubject.stream,
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            final data = snapshot.data!;
            return ListView.builder(
              controller: _scrollController,
              itemCount: data.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index < data.length) {
                  return ListTile(
                    title: Text(data[index]),
                  );
                } else {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 30),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
              },
            );
          } else {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
        },
      ),
    );
  }
}
