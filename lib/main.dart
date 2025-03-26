import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
// HTMLエンティティをデコードするために必要
import 'dart:math';
import 'package:flutter_todo_sdk/flutter_todo_sdk.dart';

import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_authenticator/amplify_authenticator.dart';
import 'amplify_outputs.dart'; //もしかしたらいらんかも
import 'package:amplify_storage_s3/amplify_storage_s3.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

// アプリの実行前にflutterとamplifyの初期化を行う
void main() async {
  // Flutterの初期化
  WidgetsFlutterBinding.ensureInitialized();
  try {
    //  Amplify SDKの初期化と設定を行う関数を呼び出し
    await _configureAmplify();
    // アプリの実行
    runApp(const MyApp());
  } on AmplifyException catch (e) {
    runApp(Text("Error configuring Amplify: ${e.message}"));
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 認証UI、状態管理、セキュリティチェック、S3アップロード時の認証トークン管理を自動で行うためAuthenticatorを使用
    return Authenticator(
      child: MaterialApp(
        title: '数字計算アプリ',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.yellow,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        home: const HelloWorldPage(title: 'トップ画面'),
      ),
    );
  }
}

// アプリがAWS Amplifyサービス（認証・ストレージなど）を使用するために必要な設定を行う関数
Future<void> _configureAmplify() async {
  try {
    // 認証プラグインの初期化 
    final auth = AmplifyAuthCognito();
    await Amplify.addPlugin(auth);
    // ストレージプラグインの初期化
    await Amplify.addPlugin(AmplifyStorageS3());
    // amplify_outputs.dartで定義した設定をAmplifyに適用
    await Amplify.configure(jsonEncode(amplifyConfig));
    safePrint('Successfully configured Amplify');
  } on Exception catch (e) {
    safePrint('Error configuring Amplify: $e');
    rethrow;
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

  // 
  Future<void> _openCamera(BuildContext context) async {
    final ImagePicker picker = ImagePicker();
    try {
      // ユーザーにカメラか写真ライブラリを選択させる
      final XFile? imageFile = await showDialog<XFile?>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('画像を選択'),
            content: const Text('画像をカメラで撮影するか、ライブラリから選択してください'),
            actions: <Widget>[
              TextButton.icon(
                icon: const Icon(Icons.camera_alt),
                label: const Text('カメラで撮影'),
                onPressed: () async {
                  Navigator.of(context).pop(
                    await picker.pickImage(source: ImageSource.camera),
                  );
                },
              ),
              TextButton.icon(
                icon: const Icon(Icons.photo_library),
                label: const Text('写真を選択'),
                onPressed: () async {
                  Navigator.of(context).pop(
                    await picker.pickImage(source: ImageSource.gallery),
                  );
                },
              ),
            ],
          );
        },
      );

      if (imageFile != null) {
        if (!context.mounted) return;
        // ユーザーに選択または撮影された画像をアップロードするか確認する
        final shouldUpload = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('画像のアップロード'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.file(
                    File(imageFile.path),
                    height: 200,
                    width: 200,
                    fit: BoxFit.cover,
                  ),
                  const SizedBox(height: 16),
                  const Text('この画像をS3にアップロードしますか？'),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('キャンセル'),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                TextButton(
                  child: const Text('アップロード'),
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ],
            );
          },
        ) ?? false;

        if (shouldUpload && context.mounted) {
          await _uploadImageToS3(context, imageFile);
        }
      }
    } catch (e) {
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('エラー'),
            content: const Text('画像の取得に失敗しました。端末のカメラ/写真へのアクセス権限を確認してください。'),
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

  // 選択した画像をS3にアップロードする関数
  Future<void> _uploadImageToS3(BuildContext context, XFile imageFile) async {
    try {
      safePrint('画像アップロード開始: ${imageFile.path}');
      
      // 一意のファイル名をタイムスタンプとランダム文字で生成
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final randomStr = Random().nextInt(10000).toString().padLeft(4, '0');
      final extension = imageFile.path.split('.').last;
      final path = 'user_images/image_${timestamp}_${randomStr}.$extension';
      
      // S3にアップロード
      final result = await Amplify.Storage.uploadFile(
        localFile: AWSFile.fromPath(imageFile.path),
        path: StoragePath.fromString(path),
        options: const StorageUploadFileOptions(),
      ).result;
      
      safePrint('アップロード成功: ${result.uploadedItem.path}');
      
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('アップロード成功: $path')),
      );
    } catch (e) {
      safePrint('アップロードエラー: $e');
      if (!context.mounted) return;
      
      String errorMessage = 'アップロードに失敗しました';
      String detailMessage = e.toString();
      
      // 権限エラーの場合は具体的なメッセージを表示
      if (e.toString().contains('AccessDenied') || 
          e.toString().contains('access denied') ||
          e.toString().contains('StorageAccessDeniedException')) {
        errorMessage = 'S3へのアクセス権限がありません';
        detailMessage = 'AWS Amplifyの設定で正しい権限が付与されているか確認してください。';
      }
      
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(errorMessage),
            content: SingleChildScrollView(
              child: Text(detailMessage),
            ),
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

  // アップロードボタンのイベントハンドラー
  Future<void> _uploadTestImage(BuildContext context) async {
    try {
      _openCamera(context);
    } catch (e) {
      safePrint('アップロードエラー: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラー: $e')),
      );
    }
  }

// サインアップ
  Future<void> _signUp(BuildContext context) async {
    try {
      final username = 'm.kurata+test@visk.co.jp';
      final password = 'Password123!';
      
      safePrint('サインアップ試行中...');
      safePrint('ユーザー名: $username');
      
      final result = await Amplify.Auth.signUp(
        username: username,
        password: password,
        options: SignUpOptions(
          userAttributes: {
            AuthUserAttributeKey.email: 'm.kurata+test@visk.co.jp',
          },
        ),
      );
      
      safePrint('サインアップ結果:');
      safePrint('- isSignUpComplete: ${result.isSignUpComplete}');
      safePrint('- userId: ${result.userId}');
      safePrint('- nextStep: ${result.nextStep.signUpStep}');
      
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('サインアップ処理完了（詳細はログを確認してください）')),
      );
    } catch (e) {
      safePrint('サインアップエラー: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('サインアップエラー: $e')),
      );
    }
  }

// サインイン
  Future<void> _signIn(BuildContext context) async {
    try {
      final username = 'm.kurata+test@visk.co.jp';
      final password = 'Password123!';
      
      safePrint('サインイン試行中...');
      safePrint('ユーザー名: $username');
      
      // cognitoへアクセス
      final result = await Amplify.Auth.signIn(
        username: username,
        password: password,
        options: const SignInOptions(),
      );
      
      safePrint('サインイン結果:');
      safePrint('- isSignedIn: ${result.isSignedIn}');
      
      // 次のステップに応じた処理
      if (result.nextStep.signInStep == AuthSignInStep.confirmSignInWithNewPassword) {
        safePrint('新しいパスワードでの確認が必要です');
        // 必要に応じて新しいパスワードの確認処理を実装
      } else if (result.nextStep.signInStep == AuthSignInStep.confirmSignUp) {
        safePrint('サインアップの確認が必要です。確認コードを入力してください。');
        // 確認コードの入力処理
        await _confirmSignUp(context, username);
      } else if (result.nextStep.signInStep == AuthSignInStep.resetPassword) {
        safePrint('パスワードのリセットが必要です');
        // パスワードリセット処理
      } else if (result.nextStep.signInStep == AuthSignInStep.done) {
        safePrint('サインイン成功！');
      }
      
      if (result.isSignedIn) {
        safePrint('サインイン成功！');
        // 現在の認証状態を取得
        final session = await Amplify.Auth.fetchAuthSession();
        safePrint('認証セッション情報:');
        safePrint('- isSignedIn: ${session.isSignedIn}');
        safePrint('- session type: ${session.runtimeType}');
        
        // Cognitoセッション情報を取得
        if (session is CognitoAuthSession) {
          safePrint('- Cognitoセッション: 有効');
          
          try {
            // 利用可能なセッション情報を表示
            safePrint('- セッション詳細:');
            
            // isSignedInとruntimeTypeは基本的なプロパティなので安全にアクセス可能
            safePrint('  - isSignedIn: ${session.isSignedIn}');
            
            // Amplify Debug情報
            safePrint('  - デバッグ情報:');
            // セッションオブジェクトをdumpして中身を確認
            safePrint('  - オブジェクト型: ${session.runtimeType}');
            safePrint('  - 利用可能なメソッド: ${session.toString()}');
            
          } catch (e) {
            safePrint('セッション詳細取得エラー: $e');
          }
        }
      }
      
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('サインイン処理完了（詳細はログを確認してください）')),
      );
    } catch (e) {
      safePrint('サインインエラー: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('サインインエラー: $e')),
      );
    }
  }

  Future<void> _confirmSignUp(BuildContext context, String username) async {
    try {
      // ダイアログを表示して確認コードを入力
      String? confirmationCode = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          final TextEditingController codeController = TextEditingController();
          return AlertDialog(
            title: const Text('確認コード入力'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('メールに送信された確認コードを入力してください'),
                TextField(
                  controller: codeController,
                  decoration: const InputDecoration(
                    labelText: '確認コード',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
            actions: [
              TextButton(
                child: const Text('確認'),
                onPressed: () {
                  Navigator.of(context).pop(codeController.text);
                },
              ),
            ],
          );
        },
      );
      
      if (confirmationCode != null && confirmationCode.isNotEmpty) {
        safePrint('確認コード送信中: $confirmationCode');
        final result = await Amplify.Auth.confirmSignUp(
          username: username,
          confirmationCode: confirmationCode,
        );
        
        safePrint('確認結果: ${result.isSignUpComplete}');
        if (result.isSignUpComplete) {
          // 確認完了後、再度サインインを試みる
          await _signIn(context);
        }
      }
    } catch (e) {
      safePrint('確認エラー: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('確認エラー: $e')),
      );
    }
  }

  Future<void> _signOut(BuildContext context) async {
    try {
      safePrint('サインアウト試行中...');
      await Amplify.Auth.signOut();
      safePrint('サインアウト成功');
      
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('サインアウト処理完了（詳細はログを確認してください）')),
      );
    } catch (e) {
      safePrint('サインアウトエラー: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('サインアウトエラー: $e')),
      );
    }
  }


// 画面に描画されているボタン群
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
              onPressed: () => _signUp(context),
              child: const Text('サインアップ'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => _signIn(context),
              child: const Text('サインイン'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => _signOut(context),
              child: const Text('サインアウト'),
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
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _uploadTestImage(context),
              icon: const Icon(Icons.cloud_upload),
              label: const Text('テスト画像をアップロード'),
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

Future<void> uploadFile(File file) async {
  // Web環境ではこの関数を使用しない
  if (kIsWeb) {
    print('Web環境ではこの関数はサポートされていません');
    return;
  }

  try {
    final path = 'test_file_${DateTime.now().millisecondsSinceEpoch}.txt';
    // ネイティブプラットフォーム用のコード
    final result = await Amplify.Storage.uploadFile(
      localFile: AWSFile.fromPath(file.path),
      path: StoragePath.fromString(path),
      options: const StorageUploadFileOptions(),
    ).result;
    print('アップロード成功: $path');
  } catch (e) {
    print('アップロードエラー: $e');
  }
}
