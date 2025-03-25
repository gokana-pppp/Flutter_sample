import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
// HTMLエンティティをデコードするために必要
import 'dart:math';
import 'package:flutter_todo_sdk/flutter_todo_sdk.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '数字計算アプリ',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.yellow,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const HelloWorldPage(title: 'トップ画面'),
    );
  }
}

class HelloWorldPage extends StatelessWidget {
  const HelloWorldPage({super.key, required this.title});
  final String title;

  Future<void> _fetchPokemon(BuildContext context) async {
    try {
      final random = Random();
      final pokemonId = random.nextInt(151) + 1;

      final response = await http.get(
        Uri.parse('https://pokeapi.co/api/v2/pokemon/$pokemonId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final name = data['name'];
        final types = (data['types'] as List)
            .map((type) => type['type']['name'])
            .join(', ');
        final imageUrl = data['sprites']['front_default'];

        if (!context.mounted) return;

        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('ポケモン #$pokemonId'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.network(
                    imageUrl,
                    loadingBuilder: (
                      BuildContext context,
                      Widget child,
                      ImageChunkEvent? loadingProgress,
                    ) {
                      if (loadingProgress == null) {
                        return child; // 画像の読み込みが完了
                      }
                      return SizedBox(
                        height: 96, // ポケモン画像の一般的な高さ
                        width: 96, // ポケモン画像の一般的な幅
                        child: Center(
                          child: CircularProgressIndicator(
                            value:
                                loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                          ),
                        ),
                      );
                    },
                    frameBuilder: (
                      BuildContext context,
                      Widget child,
                      int? frame,
                      bool wasSynchronouslyLoaded,
                    ) {
                      if (wasSynchronouslyLoaded) {
                        return child;
                      }
                      return AnimatedOpacity(
                        opacity: frame == null ? 0 : 1,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                        child: child,
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  Text('名前: $name'),
                  Text('タイプ: $types'),
                ],
              ),
              actions: [
                TextButton(
                  child: const Text('閉じる'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('エラー'),
            content: const Text('ポケモン情報の取得に失敗しました'),
            actions: <Widget>[
              TextButton(
                child: const Text('OK'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          );
        },
      );
    }
  }

  Future<void> _openCamera(BuildContext context) async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? photo = await picker.pickImage(source: ImageSource.camera);
      if (photo != null) {
        if (!context.mounted) return;
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('撮影完了'),
              content: const Text('写真を撮影しました'),
              actions: <Widget>[
                TextButton(
                  child: const Text('OK'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('エラー'),
            content: const Text('カメラを使用できません。実機で試してください。'),
            actions: <Widget>[
              TextButton(
                child: const Text('OK'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "HelloWorld",
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MyHomePage(title: '数字計算アプリ'),
                  ),
                );
              },
              child: const Text('計算機能を開く'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TodoPage()),
                );
              },
              child: const Text('Todoアプリを開く'),
            ),
            const SizedBox(height: 20),
            const Icon(Icons.favorite, color: Colors.red, size: 50.0),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _fetchPokemon(context),
              icon: const Icon(Icons.catching_pokemon),
              label: const Text('ポケモンを見る'),
            ),
            const SizedBox(height: 20), // ボタン間のスペース
            ElevatedButton.icon(
              onPressed: () => _openCamera(context),
              icon: const Icon(Icons.camera_alt),
              label: const Text('カメラを開く'),
            ),
          ],
        ),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final TextEditingController _controller = TextEditingController();
  int _result = 0;
  String? _errorText;

  void _calculateDouble() {
    if (_controller.text.isEmpty) {
      setState(() {
        _errorText = '数字を入力してください';
      });
      return;
    }

    final inputNumber = int.parse(_controller.text);
    setState(() {
      _result = inputNumber * 2;
    });
  }

  void _validateNumber(String value) {
    if (value.isEmpty) {
      setState(() {
        _errorText = null;
      });
      return;
    }

    try {
      int.parse(value);
      setState(() {
        _errorText = null;
      });
    } catch (e) {
      setState(() {
        _errorText = '半角数字のみ入力可能です';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _controller,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: '数字を入力してください',
                  errorText: _errorText,
                ),
                onChanged: _validateNumber,
              ),
            ),
            ElevatedButton(
              onPressed: _errorText == null ? _calculateDouble : null,
              child: const Text('計算する'),
            ),
            const SizedBox(height: 20),
            Text(
              '結果: $_result',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
    );
  }
}

// Todoアプリのページクラスをflutter_todo_sdkを使って実装
class TodoPage extends StatefulWidget {
  const TodoPage({super.key});

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  final _todoRepository = InMemoryTodoRepository();
  List<Todo> _todos = [];
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTodos();
  }

  Future<void> _loadTodos() async {
    final todos = await _todoRepository.getTodos();
    setState(() {
      _todos = todos;
    });
  }

  Future<void> _addTodo() async {
    if (_textController.text.isEmpty) return;

    final todo = Todo(title: _textController.text);

    await _todoRepository.addTodo(todo);
    _textController.clear();
    _loadTodos();
  }

  Future<void> _toggleTodo(String id, Todo todo) async {
    final updatedTodo = todo.copyWith(isDone: !todo.isDone);
    await _todoRepository.updateTodo(id, updatedTodo);
    _loadTodos();
  }

  Future<void> _deleteTodo(String id) async {
    await _todoRepository.deleteTodo(id);
    _loadTodos();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Todoリスト')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      hintText: '新しいタスクを入力',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(onPressed: _addTodo, child: const Text('追加')),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _todos.length,
              itemBuilder: (context, index) {
                final todo = _todos[index];
                // リポジトリの実装では、MapのキーがIDとして使われているため、
                // ここでは表示目的でのみindexを使用します
                final id = index.toString();
                return ListTile(
                  leading: Checkbox(
                    value: todo.isDone,
                    onChanged: (_) => _toggleTodo(id, todo),
                  ),
                  title: Text(
                    todo.title,
                    style: TextStyle(
                      decoration:
                          todo.isDone ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _deleteTodo(id),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
}
