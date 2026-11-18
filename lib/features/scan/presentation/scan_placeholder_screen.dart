import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class ScanPlaceholderScreen extends StatelessWidget {
  const ScanPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OCR Scanner'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Status Badge
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3CD),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFFEEBA)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info_outline, size: 20, color: Color(0xFF856404)),
                      SizedBox(width: 8),
                      Text(
                        'Coming Soon — Not available in v1.0',
                        style: TextStyle(
                          color: Color(0xFF856404),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Explanatory Icon and Title
              const Center(
                child: Icon(
                  Icons.document_scanner_outlined,
                  size: 72,
                  color: AppTheme.primaryNavy,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Land Record Document OCR',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryNavy,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Future releases will allow scanning or importing land ownership records and mutation sheets. '
                'Extracted values will require mandatory review and verification before transferring into the Land Calculator.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textMuted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Planned Workflow (Preview)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryNavy,
                ),
              ),
              const SizedBox(height: 12),
              // Planned Actions (Strictly Disabled)
              _buildPlannedStep(
                icon: Icons.camera_alt_outlined,
                title: 'Take Photo',
                description: 'Capture document via device camera with auto edge detection.',
              ),
              _buildPlannedStep(
                icon: Icons.photo_library_outlined,
                title: 'Choose Image',
                description: 'Import existing land plan or mutation document from gallery.',
              ),
              _buildPlannedStep(
                icon: Icons.rate_review_outlined,
                title: 'Review Extraction',
                description: 'Mandatory human verification and manual correction screen.',
              ),
              _buildPlannedStep(
                icon: Icons.send_outlined,
                title: 'Send to Land Calculator',
                description: 'Transfer confirmed measurements into active worksheet.',
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.dividerColor),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield_outlined, color: AppTheme.accentTeal),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Privacy & Offline Guarantee: In compliance with project security rules, v1 contains zero OCR runtimes and requests no camera or media permissions.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlannedStep({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.dividerColor),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.grey.shade600, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Disabled',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
