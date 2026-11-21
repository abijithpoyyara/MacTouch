import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app/routes.dart';
import '../controllers/settings_controller.dart';
import '../core/haptics.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/tokens.dart';

class _Page {
  const _Page(this.icon, this.title, this.body, this.points);
  final IconData icon;
  final String title;
  final String body;
  final List<String> points;
}

const _pages = <_Page>[
  _Page(
    Icons.touch_app_rounded,
    'Your phone is the trackpad',
    'Control your Mac from the couch or the other side of the desk. No cable, no account.',
    ['Works over your home Wi-Fi', 'Nothing leaves your network'],
  ),
  _Page(
    Icons.qr_code_scanner_rounded,
    'Pair once with a QR code',
    'Open MacTouch on your Mac, then scan the code it shows. Your Mac asks you to confirm.',
    ['The phone and the Mac must be on the same Wi-Fi', 'After pairing it reconnects by itself'],
  ),
  _Page(
    Icons.lock_open_rounded,
    'Allow control on your Mac',
    'macOS only lets an app move the pointer after you allow it. This is a one-time step on the Mac.',
    ['System Settings > Privacy & Security > Accessibility', 'MacTouch shows you when this is missing'],
  ),
  _Page(
    Icons.gesture_rounded,
    'Gestures and shortcuts',
    'Tap to click, two fingers to scroll, three fingers to swipe between desktops. Add your own shortcuts.',
    ['Change every gesture in Settings', 'Pin favorite shortcuts to the touchpad'],
  ),
];

class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  final _controller = PageController();
  int _index = 0;

  bool get _last => _index == _pages.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish() {
    Get.find<SettingsController>().completeOnboarding();
    Get.offAllNamed<void>(Routes.welcome);
  }

  void _next() {
    Haptics.tap();
    if (_last) {
      _finish();
    } else {
      _controller.nextPage(duration: Tk.normal, curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = MtColors.of(context);
    final landscape = MediaQuery.orientationOf(context) == Orientation.landscape;
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: MtGradients.hero(c)),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: Tk.maxContentWidth),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(onPressed: _finish, child: const Text('Skip')),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _controller,
                      itemCount: _pages.length,
                      onPageChanged: (i) => setState(() => _index = i),
                      itemBuilder: (_, i) => _PageBody(page: _pages[i], compact: landscape),
                    ),
                  ),
                  Semantics(
                    label: 'Page ${_index + 1} of ${_pages.length}',
                    excludeSemantics: true,
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      for (var i = 0; i < _pages.length; i++)
                        AnimatedContainer(
                          duration: Tk.fast,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: i == _index ? 22 : 8,
                          height: 8,
                          decoration: BoxDecoration(color: i == _index ? c.accent : c.outline, borderRadius: BorderRadius.circular(8)),
                        ),
                    ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(Tk.s5),
                    child: FilledButton(onPressed: _next, child: Text(_last ? 'Get started' : 'Next')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PageBody extends StatelessWidget {
  const _PageBody({required this.page, required this.compact});
  final _Page page;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = MtColors.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: Tk.s6),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: compact ? 0 : 420),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: compact ? 56 : 72,
              height: compact ? 56 : 72,
              decoration: BoxDecoration(gradient: MtGradients.accent(c), borderRadius: BorderRadius.circular(Tk.rLg)),
              child: Icon(page.icon, size: compact ? 28 : 36, color: c.onAccent),
            ),
            const SizedBox(height: Tk.s6),
            Semantics(
              header: true,
              child: Text(page.title, style: TextStyle(fontSize: compact ? 26 : 32, height: 1.1, fontWeight: FontWeight.w700, letterSpacing: -0.8, color: c.text)),
            ),
            const SizedBox(height: Tk.s3),
            Text(page.body, style: TextStyle(fontSize: 16, height: 1.45, color: c.textDim)),
            const SizedBox(height: Tk.s5),
            for (final p in page.points)
              Padding(
                padding: const EdgeInsets.only(bottom: Tk.s2),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.check_circle_rounded, size: 20, color: c.success),
                  const SizedBox(width: Tk.s3),
                  Expanded(child: Text(p, style: TextStyle(fontSize: 15, height: 1.35, color: c.text))),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}
