import 'package:flutter/material.dart';

import '../../schemes/presentation/scheme_scan_screen.dart';

/// The Scan tab: scan or choose an area-schedule image, review, save and export, all on one page.
class ScanScreen extends StatelessWidget {
  final VoidCallback onNavigateToLand;

  const ScanScreen({super.key, required this.onNavigateToLand});

  @override
  Widget build(BuildContext context) => const SchemeScanScreen(tab: true);
}
