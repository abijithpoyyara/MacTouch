import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/pairing_controller.dart';
import '../core/theme/app_theme.dart';
import 'widgets/mt_scaffold.dart';

class PairingView extends StatelessWidget {
  const PairingView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = MtColors.of(context);
    final pairing = Get.find<PairingController>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) pairing.cancel();
      },
      child: MtScaffold(
        showHeader: false,
        child: Obx(() {
          final phase = pairing.phase.value;
          if (phase == PairingPhase.failed) return _Failure(pairing: pairing);
          if (phase == PairingPhase.success) return _Success(name: pairing.serverName);

          final name = pairing.serverName;
          final steps = ['Connecting to $name', 'Checking the code', 'Waiting for approval on your Mac'];
          final active = switch (phase) {
            PairingPhase.verifying => 1,
            PairingPhase.awaitingApproval => 2,
            _ => 0,
          };
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Text('Pairing with $name',
                  style: TextStyle(fontSize: 30, height: 1.1, fontWeight: FontWeight.w700, letterSpacing: -0.7, color: c.text)),
              const SizedBox(height: 10),
              Text(active == 2 ? 'Confirm the request on your Mac to finish.' : 'This takes a few seconds.',
                  style: TextStyle(fontSize: 16, color: c.textDim)),
              const SizedBox(height: 28),
              MtCard(
                child: Column(
                  children: [
                    for (var i = 0; i < steps.length; i++) ...[
                      _StepRow(label: steps[i], state: i < active ? _Step.done : (i == active ? _Step.active : _Step.waiting)),
                      if (i < steps.length - 1) const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
              const Spacer(flex: 2),
              OutlinedButton(onPressed: pairing.cancel, child: const Text('Cancel')),
            ],
          );
        }),
      ),
    );
  }
}

enum _Step { done, active, waiting }

class _StepRow extends StatelessWidget {
  const _StepRow({required this.label, required this.state});
  final String label;
  final _Step state;

  @override
  Widget build(BuildContext context) {
    final c = MtColors.of(context);
    final Widget leading = switch (state) {
      _Step.done => Icon(Icons.check_circle_rounded, color: c.success, size: 24),
      _Step.active => const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
      _Step.waiting => Icon(Icons.circle_outlined, color: c.outline, size: 24),
    };
    return Row(
      children: [
        SizedBox(width: 24, height: 24, child: Center(child: leading)),
        const SizedBox(width: 14),
        Expanded(
          child: Text(label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: state == _Step.active ? FontWeight.w600 : FontWeight.w400,
                color: state == _Step.waiting ? c.textDim : c.text,
              )),
        ),
      ],
    );
  }
}

class _Success extends StatelessWidget {
  const _Success({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final c = MtColors.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.6, end: 1),
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutBack,
          builder: (_, v, child) => Transform.scale(scale: v, child: child),
          child: Icon(Icons.check_circle_rounded, size: 96, color: c.success),
        ),
        const SizedBox(height: 20),
        Text('Paired with $name', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: c.text)),
      ],
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({required this.pairing});
  final PairingController pairing;

  @override
  Widget build(BuildContext context) {
    final c = MtColors.of(context);
    final failure = pairing.failure.value;
    final canRetry = failure?.canRetrySameCode ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        Icon(Icons.error_outline_rounded, size: 56, color: c.danger),
        const SizedBox(height: 18),
        Text('Couldn\u2019t pair', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -0.7, color: c.text)),
        const SizedBox(height: 10),
        Text(failure?.message ?? 'Something went wrong.', style: TextStyle(fontSize: 16, height: 1.45, color: c.textDim)),
        const Spacer(flex: 2),
        if (canRetry) ...[
          FilledButton(onPressed: pairing.retrySameCode, child: const Text('Try again')),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: pairing.scanAgain, child: const Text('Scan a new code')),
        ] else
          FilledButton(onPressed: pairing.scanAgain, child: const Text('Scan a new code')),
        const SizedBox(height: 10),
        TextButton(onPressed: pairing.cancel, child: const Text('Back to start')),
      ],
    );
  }
}
