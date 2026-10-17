import 'package:flutter/material.dart';

const policyPaper = Color(0xFFF5F5EF);

class PolicyLoading extends StatelessWidget {
  const PolicyLoading({super.key});
  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: policyPaper,
    child: Center(
      child: SizedBox.square(
        dimension: 28,
        child: CircularProgressIndicator(
          semanticsLabel: '正在加载',
          strokeWidth: 2,
          color: Color(0xFF65812C),
        ),
      ),
    ),
  );
}

class PolicyText extends StatelessWidget {
  const PolicyText({super.key, required this.html});
  final String html;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: policyPaper,
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: SelectableText(
        html
            .replaceAll(RegExp(r'<style>[\s\S]*?</style>'), '')
            .replaceAll(
              RegExp(r'</(p|h1|h2|h3|li|tr|section)>|<br\s*/?>'),
              '\n\n',
            )
            .replaceAll(RegExp(r'<[^>]+>'), ''),
        style: const TextStyle(color: Color(0xFF172019), height: 1.85),
      ),
    ),
  );
}
