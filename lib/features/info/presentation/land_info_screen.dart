import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class LandInfoScreen extends StatefulWidget {
  const LandInfoScreen({super.key});

  @override
  State<LandInfoScreen> createState() => _LandInfoScreenState();
}

class _LandInfoScreenState extends State<LandInfoScreen> {
  final TextEditingController _inputController = TextEditingController(text: '1');
  String _selectedUnit = 'Kanal';
  bool _use225Standard = true; // true = 225 sq ft (Societies), false = 272.25 sq ft (Govt Revenue)

  final List<String> _units = [
    'Sarsai',
    'Marla',
    'Kanal',
    'Acre / Qila',
    'Murabba',
    'Square Feet',
    'Square Yard (Gaz)',
  ];

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  double _getMarlaSqFt() => _use225Standard ? 225.0 : 272.25;
  double _getSarsaiSqFt() => _getMarlaSqFt() / 9.0;

  // Calculates all equivalent units from the input value
  Map<String, String> _calculateConversions() {
    final inputVal = double.tryParse(_inputController.text) ?? 0.0;
    if (inputVal <= 0) {
      return {for (var u in _units) u: '0'};
    }

    final marlaSqFt = _getMarlaSqFt();
    final sarsaiSqFt = _getSarsaiSqFt();

    // Convert input to total square feet first
    double totalSqFt = 0.0;
    switch (_selectedUnit) {
      case 'Sarsai':
        totalSqFt = inputVal * sarsaiSqFt;
        break;
      case 'Marla':
        totalSqFt = inputVal * marlaSqFt;
        break;
      case 'Kanal':
        totalSqFt = inputVal * (marlaSqFt * 20);
        break;
      case 'Acre / Qila':
        totalSqFt = inputVal * (marlaSqFt * 160);
        break;
      case 'Murabba':
        totalSqFt = inputVal * (marlaSqFt * 4000);
        break;
      case 'Square Feet':
        totalSqFt = inputVal;
        break;
      case 'Square Yard (Gaz)':
        totalSqFt = inputVal * 9.0;
        break;
    }

    String fmt(double val) {
      if (val == val.roundToDouble()) {
        return val.toInt().toString();
      }
      return val.toStringAsFixed(2);
    }

    return {
      'Square Feet': fmt(totalSqFt),
      'Square Yard (Gaz)': fmt(totalSqFt / 9.0),
      'Sarsai': fmt(totalSqFt / sarsaiSqFt),
      'Marla': fmt(totalSqFt / marlaSqFt),
      'Kanal': fmt(totalSqFt / (marlaSqFt * 20)),
      'Acre / Qila': fmt(totalSqFt / (marlaSqFt * 160)),
      'Murabba': fmt(totalSqFt / (marlaSqFt * 4000)),
    };
  }

  @override
  Widget build(BuildContext context) {
    final conversions = _calculateConversions();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Land Units & Revenue Guide'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset to 1',
            onPressed: () {
              setState(() {
                _inputController.text = '1';
                _selectedUnit = 'Kanal';
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: ListView(
              padding: const EdgeInsets.all(14),
              children: [
                // Quick Live Converter Card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: AppTheme.accentTeal, width: 1.5),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calculate, color: AppTheme.accentTeal, size: 24),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Live Land Unit Converter (فوری پیمائش کیلکولیٹر)',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryNavy,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Standard Toggle: 225 vs 272.25
                        Row(
                          children: [
                            const Text('Marla Standard:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('225 Sq Ft (Housing Schemes)'),
                              selected: _use225Standard,
                              onSelected: (val) => setState(() => _use225Standard = true),
                              selectedColor: AppTheme.accentTeal,
                              labelStyle: TextStyle(
                                color: _use225Standard ? Colors.white : AppTheme.charcoalText,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 6),
                            ChoiceChip(
                              label: const Text('272.25 Sq Ft (Govt Patwar/Fard)'),
                              selected: !_use225Standard,
                              onSelected: (val) => setState(() => _use225Standard = false),
                              selectedColor: AppTheme.primaryNavy,
                              labelStyle: TextStyle(
                                color: !_use225Standard ? Colors.white : AppTheme.charcoalText,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Input and Unit Selection
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: _inputController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                onChanged: (_) => setState(() {}),
                                decoration: const InputDecoration(
                                  labelText: 'Enter Quantity',
                                  hintText: 'e.g. 1, 5, 95',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 4,
                              child: DropdownButtonFormField<String>(
                                value: _selectedUnit,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Select Unit',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                ),
                                items: _units.map((u) {
                                  return DropdownMenuItem(
                                    value: u,
                                    child: Text(u, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedUnit = val);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(height: 1, color: AppTheme.dividerColor),
                        const SizedBox(height: 12),
                        // Conversion Results Grid
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: conversions.entries.map((entry) {
                            final isInput = entry.key == _selectedUnit;
                            return Container(
                              width: 190,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isInput ? AppTheme.accentTeal.withValues(alpha: 0.1) : AppTheme.paleBackground,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isInput ? AppTheme.accentTeal : AppTheme.dividerColor,
                                  width: isInput ? 1.5 : 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.key,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isInput ? AppTheme.accentTeal : AppTheme.textMuted,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    entry.value,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryNavy,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Core Reference: Sarsai, Marla, Kanal, Acre Table
                _buildInfoCard(
                  title: 'Core Land Area Hierarchy (اراضی کی بنیادی اکائیاں)',
                  icon: Icons.view_compact_outlined,
                  children: [
                    _buildTable([
                      ['اکائی (Unit)', 'مساوی رقبہ (Equivalent)', 'اسکوائر فٹ (225 مرلہ)', 'اسکوائر گز (Gaz)'],
                      ['1 Sarsai (سرسائی)', '1 کرم × 1 کرم', '25.00 sq ft', '2.78 sq yds'],
                      ['1 Marla (مرلہ)', '9 سرسائیاں (Sarsais)', '225.00 sq ft', '25.00 sq yds'],
                      ['1 Kanal (کنال)', '20 مرلے (180 سرسائیاں)', '4,500.00 sq ft', '500.00 sq yds'],
                      ['1 Acre / Qila (ایکڑ)', '8 کنال (160 مرلے)', '36,000.00 sq ft', '4,000.00 sq yds'],
                      ['1 Murabba (مربع)', '25 ایکڑ (200 کنال)', '900,000.00 sq ft', '100,000.00 sq yds'],
                    ]),
                  ],
                ),
                const SizedBox(height: 16),

                // Comparison: 225 vs 272.25 vs 250
                _buildInfoCard(
                  title: '225 vs 272.25 Sq Ft Marla (ہاؤسنگ سوسائٹی بمقابلہ سرکاری پٹوار)',
                  icon: Icons.compare_arrows,
                  children: [
                    const Text(
                      'پاکستان میں مرلے کی دو مختلف پیمائشیں مستعمل ہیں:',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    _buildBullet(
                      '225 اسکوائر فٹ مرلہ (Modern Housing Societies):',
                      'لاہور ڈویلپمنٹ اتھارٹی (LDA)، بحریہ ٹاؤن، ڈی ایچ اے، اور تمام پرائیویٹ کالونیوں میں 1 مرلہ = 225 فٹ (25 گز) استعمال ہوتا ہے۔ اس حساب سے 1 کنال = 4,500 اسکوائر فٹ اور 1 سرسائی = 25 اسکوائر فٹ بنتی ہے۔',
                    ),
                    const SizedBox(height: 6),
                    _buildBullet(
                      '272.25 اسکوائر فٹ مرلہ (Govt Revenue / Patwarkhana):',
                      'پنجاب بورڈ آف ریونیو اور زرعی اراضی کے فرد میں 1 کرم = 5.5 فٹ مانا جاتا ہے۔ اس لحاظ سے 1 سرسائی = 30.25 فٹ اور 1 مرلہ = 9 × 30.25 = 272.25 اسکوائر فٹ (30.25 گز) بنتا ہے۔ 1 کنال = 5,445 اسکوائر فٹ اور 1 ایکڑ = 43,560 اسکوائر فٹ ہوتا ہے۔',
                    ),
                    const SizedBox(height: 6),
                    _buildBullet(
                      '250 اسکوائر فٹ مرلہ:',
                      'لاہور کے بعض پرانے علاقوں اور تاریخی بائی لاز میں 250 فٹ کا مرلہ بھی استعمال ہوتا تھا (1 کنال = 5,000 فٹ)۔',
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Linear Measurements (Karam & Jareeb)
                _buildInfoCard(
                  title: 'Linear Units: Karam & Jareeb (پیمائشِ لمبائی: کرم و جریب)',
                  icon: Icons.straighten,
                  children: [
                    _buildDetailRow('1 Karam (کرم - پٹوار معیار)', '5.5 Feet (66 Inches = 1.676 Meters)'),
                    _buildDetailRow('1 Karam (کرم - 225 معیار)', '5.0 Feet (60 Inches)'),
                    _buildDetailRow('1 Jareeb (جریب)', '10 کرم = 55 Feet (660 Inches)'),
                    _buildDetailRow('1 Square Jareeb (مربع جریب)', '4 Kanals (1/2 Acre) = 80 Marlas'),
                    _buildDetailRow('1 Gaz / Yard (گز)', '3 Feet (36 Inches) = 0.9144 Meters'),
                    _buildDetailRow('1 Square Yard (مربع گز)', '9 Square Feet (3 ft × 3 ft)'),
                  ],
                ),
                const SizedBox(height: 16),

                // Standard Colony Plot Sizes
                _buildInfoCard(
                  title: 'Standard Plot Sizes in Housing Schemes (پلاٹوں کے معیاری سائز)',
                  icon: Icons.architecture,
                  children: [
                    _buildTable([
                      ['پلاٹ سائز (Plot)', 'پیمائش فٹ میں (W × L)', 'اسکوائر فٹ (225 معیار)', 'مرلہ / کنال'],
                      ['3 Marla', '20 ft × 33.75 ft', '675 sq ft', '3 مرلہ'],
                      ['5 Marla', '25 ft × 45 ft', '1,125 sq ft', '5 مرلہ'],
                      ['7 Marla', '30 ft × 52.5 ft', '1,575 sq ft', '7 مرلہ'],
                      ['10 Marla', '35 ft × 65 ft', '2,275 sq ft (~10M)', '10 مرلہ'],
                      ['1 Kanal', '50 ft × 90 ft', '4,500 sq ft', '1 کنال (20 مرلہ)'],
                      ['2 Kanal', '75 ft × 120 ft', '9,000 sq ft', '2 کنال (40 مرلہ)'],
                    ]),
                  ],
                ),
                const SizedBox(height: 16),

                // Colony Planning & Deduction Percentages
                _buildInfoCard(
                  title: 'Town Planning & Deduction Rules (کالونی پلاننگ رولز)',
                  icon: Icons.maps_home_work_outlined,
                  children: [
                    const Text(
                      'کسی بھی کالونی کے کل رقبے کی تقسیم کے لیے ضلعی کونسل اور ڈویلپمنٹ اتھارٹیز کے رہنما اصول:',
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 8),
                    _buildDetailRow('Roads & Streets (سڑکیں)', '20% تا 30% رقبہ (مین روڈ 40 تا 80 فٹ، گلیاں 30 تا 40 فٹ)'),
                    _buildDetailRow('Parks & Playgrounds (پارک و کھیل کا میدان)', '7% تا 10% رقبہ'),
                    _buildDetailRow('Public Amenities (جامع مسجد، اسکول، ڈسپنسری)', '5% تا 8% رقبہ'),
                    _buildDetailRow('Graveyard & Sewerage (قبرستان اور سیوریج پلانٹ)', '2% تا 3% رقبہ'),
                    _buildDetailRow('Commercial Area (کمرشل مارکیٹ و دکانیں)', '4% تا 5% رقبہ'),
                    _buildDetailRow('Residential Plots (بقایا رہائشی پلاٹ)', '50% تا 60% رقبہ'),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppTheme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: AppTheme.primaryNavy),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryNavy,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 18, color: AppTheme.dividerColor),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildBullet(String heading, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accentTeal)),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 12, color: AppTheme.charcoalText, height: 1.4),
              children: [
                TextSpan(text: '$heading ', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryNavy)),
                TextSpan(text: description),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 220,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, color: AppTheme.charcoalText),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(List<List<String>> data) {
    return Table(
      border: TableBorder.all(color: AppTheme.dividerColor, width: 1),
      children: data.asMap().entries.map((entry) {
        final isHeader = entry.key == 0;
        final row = entry.value;
        return TableRow(
          decoration: BoxDecoration(
            color: isHeader ? AppTheme.primaryNavy.withValues(alpha: 0.08) : Colors.white,
          ),
          children: row.map((cell) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Text(
                cell,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
                  color: isHeader ? AppTheme.primaryNavy : AppTheme.charcoalText,
                ),
              ),
            );
          }).toList(),
        );
      }).toList(),
    );
  }
}
