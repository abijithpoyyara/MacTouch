import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../app/routes.dart';
import '../controllers/pairing_controller.dart';
import '../core/theme/app_theme.dart';

class ScannerView extends StatefulWidget {
  const ScannerView({super.key});

  @override
  State<ScannerView> createState() => _ScannerViewState();
}

class _ScannerViewState extends State<ScannerView> {
  final _scanner = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );
  final _pairing = Get.find<PairingController>();
  bool _torchOn = false;

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = MtColors.of(context);
    final size = MediaQuery.of(context).size;
    final frame = size.width * 0.72;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _scanner,
            onDetect: (capture) => _pairing.onScan(capture.barcodes.firstOrNull?.rawValue),
            errorBuilder: (context, error, child) => _CameraProblem(onBack: () => Get.offAllNamed(Routes.welcome)),
          ),
          IgnorePointer(child: CustomPaint(painter: _FramePainter(frame: frame, accent: c.accent))),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  IconButton.filledTonal(
                    tooltip: 'Back',
                    onPressed: () => Get.offAllNamed(Routes.welcome),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const Spacer(),
                  IconButton.filledTonal(
                    tooltip: _torchOn ? 'Turn flashlight off' : 'Turn flashlight on',
                    onPressed: () async {
                      await _scanner.toggleTorch();
                      setState(() => _torchOn = !_torchOn);
                    },
                    icon: Icon(_torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Obx(() {
                      final error = _pairing.scanError.value;
                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: error == null
                            ? const SizedBox(key: ValueKey('none'), height: 0)
                            : Container(
                                key: ValueKey(error),
                                margin: const EdgeInsets.only(bottom: 14),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(color: c.danger, borderRadius: BorderRadius.circular(14)),
                                child: Text(error, textAlign: TextAlign.center, style: TextStyle(color: c.bg, fontWeight: FontWeight.w600)),
                              ),
                      );
                    }),
                    const Text('Point the camera at the code on your Mac',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FramePainter extends CustomPainter {
  _FramePainter({required this.frame, required this.accent});
  final double frame;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: size.center(const Offset(0, -20)), width: frame, height: frame),
      const Radius.circular(28),
    );
    final dim = Path.combine(PathOperation.difference, Path()..addRect(Offset.zero & size), Path()..addRRect(rect));
    canvas.drawPath(dim, Paint()..color = Colors.black.withValues(alpha: 0.55));
    canvas.drawRRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = accent,
    );
  }

  @override
  bool shouldRepaint(_FramePainter old) => old.frame != frame || old.accent != accent;
}

class _CameraProblem extends StatelessWidget {
  const _CameraProblem({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final c = MtColors.of(context);
    return Container(
      color: c.bg,
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.no_photography_rounded, size: 48, color: c.warning),
          const SizedBox(height: 16),
          Text('Camera isn\u2019t available', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: c.text)),
          const SizedBox(height: 8),
          Text('Allow camera access for MacTouch in Android Settings, then try again.',
              textAlign: TextAlign.center, style: TextStyle(color: c.textDim, height: 1.4)),
          const SizedBox(height: 24),
          OutlinedButton(onPressed: onBack, child: const Text('Back')),
        ],
      ),
    );
  }
}
