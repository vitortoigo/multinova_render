import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_static/shelf_static.dart';
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicia o servidor HTTP local para servir os assets
  await AssetServer.instance.start();

  runApp(MyApp());
}

class AssetServer {
  static final AssetServer _instance = AssetServer._internal();
  static AssetServer get instance => _instance;

  AssetServer._internal();

  HttpServer? _server;
  int _port = 8080;

  Future<void> start() async {
    if (_server != null) return;

    try {
      // Cria um diretório temporário para os assets
      final tempDir = await Directory.systemTemp.createTemp('flutter_assets_');
      await _extractAssets(tempDir);

      // Configura o servidor
      final handler = createStaticHandler(
        tempDir.path,
        defaultDocument: 'index.html',
        serveFilesOutsidePath: true,
      );

      // Inicia o servidor HTTP
      _server = await serve(handler, InternetAddress.loopbackIPv4, _port);
      print('Servidor local iniciado em: http://localhost:$_port');
    } catch (e) {
      print('Erro ao iniciar servidor: $e');
    }
  }

  Future<void> _extractAssets(Directory tempDir) async {
    final manifestContent = await rootBundle.loadString('AssetManifest.json');
    final Map<String, dynamic> manifest = json.decode(manifestContent);

    for (String assetPath in manifest.keys) {
      if (assetPath.startsWith('assets/')) {
        try {
          final data = await rootBundle.load(assetPath);
          final file = File('${tempDir.path}/$assetPath');
          await file.create(recursive: true);
          await file.writeAsBytes(data.buffer.asUint8List());
        } catch (e) {
          print('Erro ao extrair asset $assetPath: $e');
        }
      }
    }
  }

  String getAssetUrl(String assetPath) {
    return 'http://localhost:$_port/$assetPath';
  }

  Future<void> stop() async {
    await _server?.close();
    _server = null;
  }
}

class Product {
  final String name;
  final String url;
  final String image;

  Product({required this.name, required this.url, required this.image});
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void dispose() {
    // Para o servidor quando o app é fechado
    AssetServer.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Produtos - Windows',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: ProductListScreen(),
    );
  }
}

class ProductListScreen extends StatelessWidget {
  final List<Product> products = [
    Product(
      name: 'Multimpact',
      url: 'assets/multimpact/index.html',
      image: 'assets/multimpact/multimpact.jpg',
    ),
    Product(
      name: 'Multihidro',
      url: 'assets/multihidro/index.html',
      image: 'assets/multihidro/multihidro.png',
    ),
    Product(
      name: 'Multipiso',
      url: 'assets/multipiso/index.html',
      image: 'assets/multipiso/multipiso.png',
    ),
    Product(
      name: 'Multiterm',
      url: 'assets/multiterm/index.html',
      image: 'assets/multiterm/multiterm.png',
    ),
    Product(
      name: 'Piso Seguro',
      url: 'assets/pisoseguro/index.html',
      image: 'assets/pisoseguro/pisoseguro.png',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 2,
        title: Image.asset(
          'assets/logo.png',
          height: 60,
        ),
      ),
      body: Container(
        padding: EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Calcula o número de colunas baseado no tamanho da tela
            int crossAxisCount = 5;
            if (constraints.maxWidth < 1200) {
              crossAxisCount = 4;
            } else if (constraints.maxWidth < 900) {
              crossAxisCount = 3;
            } else if (constraints.maxWidth < 600) {
              crossAxisCount = 2;
            }

            return GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.85, // Ajustado para Windows
              ),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => WebViewScreen(
                          assetPath: product.url,
                          productName: product.name,
                        ),
                      ),
                    );
                  },
                  child: Card(
                    elevation: 6,
                    shadowColor: Colors.black26,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          flex: 3,
                          child: ClipRRect(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                            child: Container(
                              width: double.infinity,
                              child: Image.asset(
                                product.image,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey[300],
                                    child: Icon(
                                      Icons.image_not_supported,
                                      size: 50,
                                      color: Colors.grey[600],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Container(
                            padding: EdgeInsets.all(12),
                            child: Center(
                              child: Text(
                                product.name,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class WebViewScreen extends StatefulWidget {
  final String assetPath;
  final String productName;

  WebViewScreen({required this.assetPath, required this.productName});

  @override
  _WebViewScreenState createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  final _controller = WebviewController();
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() async {
    try {
      await _controller.initialize();

      // Carrega o conteúdo HTML dos assets
      await _loadHtmlFromAsset();

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print('Erro ao inicializar WebView: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadHtmlFromAsset() async {
    try {
      // Carrega o arquivo HTML dos assets
      final String htmlContent = await rootBundle.loadString(widget.assetPath);

      // Obtém o diretório base do asset
      final String assetDir =
          widget.assetPath.substring(0, widget.assetPath.lastIndexOf('/') + 1);

      // Substitui caminhos relativos por URLs do servidor local
      String modifiedHtml = htmlContent.replaceAllMapped(
        RegExp(r'(src|href)="(?!http|https|data:)([^"]*)"'),
        (match) {
          final String relativePath = match.group(2)!;
          String fullAssetPath;

          if (relativePath.startsWith('./')) {
            // Remove o './' do início
            fullAssetPath = '$assetDir${relativePath.substring(2)}';
          } else if (relativePath.startsWith('../')) {
            // Lida com caminhos relativos para trás
            final List<String> assetParts = assetDir.split('/');
            final List<String> relativeParts = relativePath.split('/');

            List<String> resultParts = List.from(assetParts);
            resultParts.removeLast(); // Remove o último '/'

            for (String part in relativeParts) {
              if (part == '..') {
                if (resultParts.isNotEmpty) {
                  resultParts.removeLast();
                }
              } else if (part != '.') {
                resultParts.add(part);
              }
            }

            fullAssetPath = resultParts.join('/');
            if (!fullAssetPath.startsWith('assets/')) {
              fullAssetPath = 'assets/$fullAssetPath';
            }
          } else {
            // Caminho relativo normal
            fullAssetPath = '$assetDir$relativePath';
          }

          final String serverUrl =
              AssetServer.instance.getAssetUrl(fullAssetPath);
          return '${match.group(1)}="$serverUrl"';
        },
      );

      final url = AssetServer.instance.getAssetUrl(widget.assetPath);
      await _controller.loadUrl(url);
    } catch (e) {
      print('Erro ao carregar HTML: $e');
      // Fallback para página de erro
      await _controller.loadStringContent('''
        <html>
          <head>
            <title>Erro</title>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
              body { 
                font-family: Arial, sans-serif; 
                text-align: center; 
                padding: 50px; 
                background-color: #f5f5f5;
              }
              .error-container {
                background: white;
                padding: 30px;
                border-radius: 10px;
                box-shadow: 0 2px 10px rgba(0,0,0,0.1);
                max-width: 500px;
                margin: 0 auto;
              }
              .error-details {
                background: #ffebee;
                padding: 15px;
                border-radius: 5px;
                margin: 15px 0;
                border-left: 4px solid #f44336;
              }
            </style>
          </head>
          <body>
            <div class="error-container">
              <h2>⚠️ Erro ao carregar o conteúdo</h2>
              <p>Não foi possível carregar o arquivo:</p>
              <p><strong>${widget.assetPath}</strong></p>
              <div class="error-details">
                <strong>Erro:</strong> $e
              </div>
              <p>Verifique se o arquivo existe na pasta assets e se o servidor local está funcionando.</p>
            </div>
          </body>
        </html>
      ''');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.productName,
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 2,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              _controller.reload();
            },
          ),
          IconButton(
            icon: Icon(Icons.open_in_browser),
            onPressed: () {
              // Abre o DevTools do WebView
              _controller.openDevTools();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Webview(_controller),
          ),
          if (isLoading)
            Container(
              color: Colors.white,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Carregando ${widget.productName}...',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
