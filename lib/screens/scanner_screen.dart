// scanner_screen.dart
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/supabase_service.dart';
import 'asset_detail_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with WidgetsBindingObserver {
  final MobileScannerController cameraController = MobileScannerController(
    // Opcional: melhora performance e evita falsos positivos
    formats: [BarcodeFormat.qrCode],
  );

  bool _isProcessing = false;
  bool _flashOn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    cameraController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!cameraController.value.isInitialized) return;

    switch (state) {
      case AppLifecycleState.resumed:
        if (mounted && !_isProcessing) {
          cameraController.start();
        }
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        cameraController.stop();
        break;
      default:
        break;
    }
  }

  Future<void> _processCode(String code) async {
    if (_isProcessing || !mounted) return;

    code = code.trim();
    if (code.isEmpty) return;

    setState(() => _isProcessing = true);
    await cameraController.stop();

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final asset = await SupabaseService.getAssetByCode(code);

      if (!mounted) return;

      if (asset == null) {
        _showFeedback(messenger, 'Ativo não encontrado: $code', error: true);
      } else {
        await navigator.push(
          MaterialPageRoute(
            builder: (_) => AssetDetailScreen(asset: asset),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showFeedback(
          messenger,
          'Erro de conexão. Verifique sua internet.',
          error: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
        await cameraController.start();
      }
    }
  }

  void _showFeedback(ScaffoldMessengerState messenger, String message,
      {bool error = false}) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red[700] : Colors.green[700],
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () => messenger.hideCurrentSnackBar(),
        ),
      ),
    );
  }

  void _toggleFlash() {
    setState(() => _flashOn = !_flashOn);
    cameraController.toggleTorch();
  }

  void _showManualInputDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Digitar Código Manualmente'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Código do ativo',
            hintText: 'Ex: AST123456',
            border: OutlineInputBorder(),
            counterText: '',
          ),
          maxLength: 50,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final code = controller.text.trim();
              Navigator.pop(context);
              if (code.isNotEmpty) {
                _processCode(code);
              }
            },
            child: const Text('Buscar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Escanear QR Code',
            style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(_flashOn ? Icons.flash_on : Icons.flash_off),
            color: Colors.white,
            onPressed: _toggleFlash,
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: (capture) {
              final barcode = capture.barcodes.firstOrNull;
              if (barcode?.rawValue != null) {
                _processCode(barcode!.rawValue!);
              }
            },
          ),

          // Overlay com cantos azuis
          const ScannerOverlay(),

          // Caixa de instruções
          Positioned(
            bottom: 100,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    // ignore: deprecated_member_use
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isProcessing ? Icons.hourglass_empty : Icons.qr_code_scanner,
                    size: 48,
                    color: const Color(0xFF3B82F6),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _isProcessing
                        ? 'Processando código...'
                        : 'QR Code na área marcada',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isProcessing
                        ? 'Buscando informações do ativo'
                        : 'A leitura é feita automaticamente',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                  ),
                  if (_isProcessing) ...[
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(
                      backgroundColor: Colors.grey,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Botão entrada manual
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: Center(
              child: TextButton.icon(
                onPressed: _showManualInputDialog,
                icon: const Icon(Icons.keyboard, color: Colors.white),
                label: const Text(
                  'Digitar Código',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.black54,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Overlay bonito com cantos azuis (separado para ficar limpo)
class ScannerOverlay extends StatelessWidget {
  const ScannerOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: ScannerOverlayPainter(),
      child: Container(),
    );
  }
}

class ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      // ignore: deprecated_member_use
      ..color = Colors.black.withOpacity(0.7)
      ..style = PaintingStyle.fill;

    final scanAreaSize = size.width * 0.7;
    final left = (size.width - scanAreaSize) / 2;
    final top = (size.height - scanAreaSize) / 2;

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, scanAreaSize, scanAreaSize),
          const Radius.circular(20),
        ),
      )
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);

    // Cantos azuis
    final cornerPaint = Paint()
      ..color = const Color(0xFF3B82F6)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cornerLength = 35.0;

    // Top-left
    canvas.drawLine(
        Offset(left + cornerLength, top), Offset(left, top), cornerPaint);
    canvas.drawLine(
        Offset(left, top), Offset(left, top + cornerLength), cornerPaint);

    // Top-right
    canvas.drawLine(Offset(left + scanAreaSize - cornerLength, top),
        Offset(left + scanAreaSize, top), cornerPaint);
    canvas.drawLine(Offset(left + scanAreaSize, top),
        Offset(left + scanAreaSize, top + cornerLength), cornerPaint);

    // Bottom-left
    canvas.drawLine(Offset(left, top + scanAreaSize - cornerLength),
        Offset(left, top + scanAreaSize), cornerPaint);
    canvas.drawLine(Offset(left + cornerLength, top + scanAreaSize),
        Offset(left, top + scanAreaSize), cornerPaint);

    // Bottom-right
    canvas.drawLine(Offset(left + scanAreaSize - cornerLength, top + scanAreaSize),
        Offset(left + scanAreaSize, top + scanAreaSize), cornerPaint);
    canvas.drawLine(Offset(left + scanAreaSize, top + scanAreaSize - cornerLength),
        Offset(left + scanAreaSize, top + scanAreaSize), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}