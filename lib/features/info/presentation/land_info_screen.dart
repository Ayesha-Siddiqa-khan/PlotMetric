import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';

enum InfoLanguage { english, urdu, both }

class LandInfoScreen extends StatefulWidget {
  const LandInfoScreen({super.key});

  @override
  State<LandInfoScreen> createState() => _LandInfoScreenState();
}

class _LandInfoScreenState extends State<LandInfoScreen> {
  final TextEditingController _inputController = TextEditingController(text: '1');
  String _selectedUnit = 'Kanal';
  bool _use225Standard = false; // false = 272.25 sq ft (Govt Revenue / Regional Default), true = 225 sq ft (Societies)
  InfoLanguage _language = InfoLanguage.english;

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

  Map<String, String> _calculateConversions() {
    final inputVal = double.tryParse(_inputController.text) ?? 0.0;
    if (inputVal <= 0) {
      return {for (var u in _units) u: '0'};
    }

    final marlaSqFt = _getMarlaSqFt();
    final sarsaiSqFt = _getSarsaiSqFt();

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

  String _t(String en, String ur, [String? both]) {
    switch (_language) {
      case InfoLanguage.english:
        return en;
      case InfoLanguage.urdu:
        return ur;
      case InfoLanguage.both:
        return both ?? '$en ($ur)';
    }
  }

  @override
  Widget build(BuildContext context) {
    final conversions = _calculateConversions();
    final isUrdu = _language == InfoLanguage.urdu;

    return Directionality(
      textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_t('Land Units & Revenue Guide', 'اراضی کی پیمائش اور ریونیو گائیڈ', 'Land Units & Revenue Guide (رہنمائے پیمائش)')),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: _t('Reset to 1', 'دوبارہ ترتیب دیں'),
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
                  // Language Selector Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.dividerColor),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.translate, size: 20, color: AppTheme.primaryNavy),
                            const SizedBox(width: 8),
                            Text(
                              _t('Language / زبان:', 'زبان منتخب کریں:', 'Language / زبان:'),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                        SegmentedButton<InfoLanguage>(
                          segments: const [
                            ButtonSegment(
                              value: InfoLanguage.english,
                              label: Text('English', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                            ButtonSegment(
                              value: InfoLanguage.urdu,
                              label: Text('اردو', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                            ButtonSegment(
                              value: InfoLanguage.both,
                              label: Text('Both', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                          selected: {_language},
                          onSelectionChanged: (set) {
                            if (set.isNotEmpty) {
                              setState(() => _language = set.first);
                            }
                          },
                          style: SegmentedButton.styleFrom(
                            selectedBackgroundColor: AppTheme.accentTeal,
                            selectedForegroundColor: Colors.white,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

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
                              Expanded(
                                child: Text(
                                  _t('Live Land Unit Converter', 'فوری پیمائش کیلکولیٹر', 'Live Land Unit Converter (فوری پیمائش کیلکولیٹر)'),
                                  style: const TextStyle(
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
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                _t('Marla Standard:', 'مرلہ معیار:', 'Marla Standard:'),
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              ChoiceChip(
                                label: Text(_t('225 Sq Ft (Housing Schemes)', '225 اسکوائر فٹ (ہاؤسنگ سکیمیں)')),
                                selected: _use225Standard,
                                onSelected: (val) => setState(() => _use225Standard = true),
                                selectedColor: AppTheme.accentTeal,
                                labelStyle: TextStyle(
                                  color: _use225Standard ? Colors.white : AppTheme.charcoalText,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              ChoiceChip(
                                label: Text(_t('272.25 Sq Ft (Govt Patwar/Fard)', '272.25 اسکوائر فٹ (سرکاری پٹوار / فرد)')),
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
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                                  ],
                                  onChanged: (_) => setState(() {}),
                                  decoration: InputDecoration(
                                    labelText: _t('Enter Quantity', 'مقدار درج کریں'),
                                    hintText: '1',
                                    border: const OutlineInputBorder(),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  onTap: () {
                                    if (_inputController.text == '1' || _inputController.text.isEmpty) {
                                      _inputController.clear();
                                    } else {
                                      _inputController.selection = TextSelection(
                                        baseOffset: 0,
                                        extentOffset: _inputController.text.length,
                                      );
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 4,
                                child: DropdownButtonFormField<String>(
                                  initialValue: _selectedUnit,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    labelText: _t('Select Unit', 'اکائی منتخب کریں'),
                                    border: const OutlineInputBorder(),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  ),
                                  items: _units.map((u) {
                                    final label = _unitDisplay(u);
                                    return DropdownMenuItem(
                                      value: u,
                                      child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
                                      _unitDisplay(entry.key),
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
                    title: _t('Core Land Area Hierarchy', 'اراضی کی بنیادی اکائیاں', 'Core Land Area Hierarchy (اراضی کی بنیادی اکائیاں)'),
                    icon: Icons.view_compact_outlined,
                    children: [
                      _buildTable(
                        _language == InfoLanguage.english
                            ? [
                                ['Unit', 'Equivalent Area', 'Square Feet (225 Std)', 'Square Yards (Gaz)'],
                                ['1 Sarsai', '1 Karam x 1 Karam', '25.00 sq ft', '2.78 sq yds'],
                                ['1 Marla', '9 Sarsais', '225.00 sq ft', '25.00 sq yds'],
                                ['1 Kanal', '20 Marlas (180 Sarsais)', '4,500.00 sq ft', '500.00 sq yds'],
                                ['1 Acre / Qila', '8 Kanals (160 Marlas)', '36,000.00 sq ft', '4,000.00 sq yds'],
                                ['1 Murabba', '25 Acres (200 Kanals)', '900,000.00 sq ft', '100,000.00 sq yds'],
                              ]
                            : _language == InfoLanguage.urdu
                                ? [
                                    ['اکائی', 'مساوی رقبہ', 'اسکوائر فٹ (225 مرلہ)', 'اسکوائر گز'],
                                    ['1 سرسائی', '1 کرم × 1 کرم', '25.00 اسکوائر فٹ', '2.78 گز'],
                                    ['1 مرلہ', '9 سرسائیاں', '225.00 اسکوائر فٹ', '25.00 گز'],
                                    ['1 کنال', '20 مرلے (180 سرسائیاں)', '4,500.00 اسکوائر فٹ', '500.00 گز'],
                                    ['1 ایکڑ / قلعہ', '8 کنال (160 مرلے)', '36,000.00 اسکوائر فٹ', '4,000.00 گز'],
                                    ['1 مربع', '25 ایکڑ (200 کنال)', '900,000.00 اسکوائر فٹ', '100,000.00 گز'],
                                  ]
                                : [
                                    ['اکائی (Unit)', 'مساوی رقبہ (Equivalent)', 'اسکوائر فٹ (225 مرلہ)', 'اسکوائر گز (Gaz)'],
                                    ['1 Sarsai (سرسائی)', '1 کرم × 1 کرم', '25.00 sq ft', '2.78 sq yds'],
                                    ['1 Marla (مرلہ)', '9 سرسائیاں (Sarsais)', '225.00 sq ft', '25.00 sq yds'],
                                    ['1 Kanal (کنال)', '20 مرلے (180 سرسائیاں)', '4,500.00 sq ft', '500.00 sq yds'],
                                    ['1 Acre / Qila (ایکڑ)', '8 کنال (160 مرلے)', '36,000.00 sq ft', '4,000.00 sq yds'],
                                    ['1 Murabba (مربع)', '25 ایکڑ (200 کنال)', '900,000.00 sq ft', '100,000.00 sq yds'],
                                  ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Comparison: 225 vs 272.25 vs 250
                  _buildInfoCard(
                    title: _t('225 vs 272.25 Sq Ft Marla (Housing Society vs Govt Revenue Patwar)', 'ہاؤسنگ سوسائٹی بمقابلہ سرکاری پٹوار (225 بمقابلہ 272.25 اسکوائر فٹ)', '225 vs 272.25 Sq Ft Marla (ہاؤسنگ سوسائٹی بمقابلہ سرکاری پٹوار)'),
                    icon: Icons.compare_arrows,
                    children: [
                      Text(
                        _t('Two distinct Marla measurements are practiced across Pakistan:', 'پاکستان میں مرلے کی دو مختلف پیمائشیں مستعمل ہیں:'),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      _buildBullet(
                        _t('225 Sq Ft Marla (Modern Housing Societies):', '225 اسکوائر فٹ مرلہ (جدید ہاؤسنگ سوسائٹیاں):'),
                        _t(
                          'Used by Lahore Development Authority (LDA), Bahria Town, DHA, and private housing societies where 1 Marla = 225 sq ft (25 sq yards). Hence, 1 Kanal = 4,500 sq ft and 1 Sarsai = 25 sq ft.',
                          'لاہور ڈویلپمنٹ اتھارٹی (LDA)، بحریہ ٹاؤن، ڈی ایچ اے، اور تمام پرائیویٹ کالونیوں میں 1 مرلہ = 225 فٹ (25 گز) استعمال ہوتا ہے۔ اس حساب سے 1 کنال = 4,500 اسکوائر فٹ اور 1 سرسائی = 25 اسکوائر فٹ بنتی ہے۔',
                        ),
                      ),
                      const SizedBox(height: 6),
                      _buildBullet(
                        _t('272.25 Sq Ft Marla (Govt Revenue / Patwarkhana):', '272.25 اسکوائر فٹ مرلہ (سرکاری پٹوار خانہ / فرد ریونیو):'),
                        _t(
                          'Standard for Punjab Board of Revenue and agricultural Fard deeds where 1 Karam = 5.5 ft. Under this standard, 1 Sarsai = 30.25 sq ft and 1 Marla = 9 x 30.25 = 272.25 sq ft (30.25 sq yards). 1 Kanal = 5,445 sq ft and 1 Acre = 43,560 sq ft.',
                          'پنجاب بورڈ آف ریونیو اور زرعی اراضی کے فرد میں 1 کرم = 5.5 فٹ مانا جاتا ہے۔ اس لحاظ سے 1 سرسائی = 30.25 فٹ اور 1 مرلہ = 9 × 30.25 = 272.25 اسکوائر فٹ (30.25 گز) بنتا ہے۔ 1 کنال = 5,445 اسکوائر فٹ اور 1 ایکڑ = 43,560 اسکوائر فٹ ہوتا ہے۔',
                        ),
                      ),
                      const SizedBox(height: 6),
                      _buildBullet(
                        _t('250 Sq Ft Marla:', '250 اسکوائر فٹ مرلہ:'),
                        _t(
                          'Used historically in older urban areas of Lahore and historical municipal bylaws (1 Kanal = 5,000 sq ft).',
                          'لاہور کے بعض پرانے علاقوں اور تاریخی بائی لاز میں 250 فٹ کا مرلہ بھی استعمال ہوتا تھا (1 کنال = 5,000 فٹ)۔',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Linear Measurements (Karam & Jareeb)
                  _buildInfoCard(
                    title: _t('Linear Units: Karam & Jareeb', 'پیمائشِ لمبائی: کرم و جریب', 'Linear Units: Karam & Jareeb (پیمائشِ لمبائی: کرم و جریب)'),
                    icon: Icons.straighten,
                    children: [
                      _buildDetailRow(_t('1 Karam (Patwar Standard)', '1 کرم (پٹوار معیار)'), _t('5.5 Feet (66 Inches = 1.676 Meters)', '5.5 فٹ (66 انچ = 1.676 میٹر)')),
                      _buildDetailRow(_t('1 Karam (225 Standard)', '1 کرم (225 معیار)'), _t('5.0 Feet (60 Inches)', '5.0 فٹ (60 انچ)')),
                      _buildDetailRow(_t('1 Jareeb', '1 جریب'), _t('10 Karams = 55 Feet (660 Inches)', '10 کرم = 55 فٹ (660 انچ)')),
                      _buildDetailRow(_t('1 Square Jareeb', '1 مربع جریب'), _t('4 Kanals (1/2 Acre) = 80 Marlas', '4 کنال (نصف ایکڑ) = 80 مرلے')),
                      _buildDetailRow(_t('1 Gaz / Yard', '1 گز'), _t('3 Feet (36 Inches) = 0.9144 Meters', '3 فٹ (36 انچ) = 0.9144 میٹر')),
                      _buildDetailRow(_t('1 Square Yard', '1 مربع گز'), _t('9 Square Feet (3 ft x 3 ft)', '9 اسکوائر فٹ (3 فٹ × 3 فٹ)')),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Standard Colony Plot Sizes
                  _buildInfoCard(
                    title: _t('Standard Plot Sizes in Housing Schemes', 'پلاٹوں کے معیاری سائز', 'Standard Plot Sizes in Housing Schemes (پلاٹوں کے معیاری سائز)'),
                    icon: Icons.architecture,
                    children: [
                      _buildTable(
                        _language == InfoLanguage.english
                            ? [
                                ['Plot Size', 'Dimensions (W x L)', 'Square Feet (225 Std)', 'Marla / Kanal'],
                                ['3 Marla', '20 ft x 33.75 ft', '675 sq ft', '3 Marla'],
                                ['5 Marla', '25 ft x 45 ft', '1,125 sq ft', '5 Marla'],
                                ['7 Marla', '30 ft x 52.5 ft', '1,575 sq ft', '7 Marla'],
                                ['10 Marla', '35 ft x 65 ft', '2,275 sq ft (~10M)', '10 Marla'],
                                ['1 Kanal', '50 ft x 90 ft', '4,500 sq ft', '1 Kanal (20 Marla)'],
                                ['2 Kanal', '75 ft x 120 ft', '9,000 sq ft', '2 Kanal (40 Marla)'],
                              ]
                            : _language == InfoLanguage.urdu
                                ? [
                                    ['پلاٹ سائز', 'پیمائش فٹ میں (W × L)', 'اسکوائر فٹ (225 معیار)', 'مرلہ / کنال'],
                                    ['3 مرلہ', '20 ft × 33.75 ft', '675 اسکوائر فٹ', '3 مرلہ'],
                                    ['5 مرلہ', '25 ft × 45 ft', '1,125 اسکوائر فٹ', '5 مرلہ'],
                                    ['7 مرلہ', '30 ft × 52.5 ft', '1,575 اسکوائر فٹ', '7 مرلہ'],
                                    ['10 مرلہ', '35 ft × 65 ft', '2,275 اسکوائر فٹ', '10 مرلہ'],
                                    ['1 کنال', '50 ft × 90 ft', '4,500 اسکوائر فٹ', '1 کنال (20 مرلہ)'],
                                    ['2 کنال', '75 ft × 120 ft', '9,000 اسکوائر فٹ', '2 کنال (40 مرلہ)'],
                                  ]
                                : [
                                    ['پلاٹ سائز (Plot)', 'پیمائش فٹ میں (W × L)', 'اسکوائر فٹ (225 معیار)', 'مرلہ / کنال'],
                                    ['3 Marla', '20 ft × 33.75 ft', '675 sq ft', '3 مرلہ'],
                                    ['5 Marla', '25 ft × 45 ft', '1,125 sq ft', '5 مرلہ'],
                                    ['7 Marla', '30 ft × 52.5 ft', '1,575 sq ft', '7 مرلہ'],
                                    ['10 Marla', '35 ft × 65 ft', '2,275 sq ft (~10M)', '10 مرلہ'],
                                    ['1 Kanal', '50 ft × 90 ft', '4,500 sq ft', '1 کنال (20 مرلہ)'],
                                    ['2 Kanal', '75 ft × 120 ft', '9,000 sq ft', '2 کنال (40 مرلہ)'],
                                  ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Colony Planning & Deduction Percentages
                  _buildInfoCard(
                    title: _t('Town Planning & Colony Deduction Rules', 'کالونی پلاننگ اور کٹوتی کے قواعد', 'Town Planning & Deduction Rules (کالونی پلاننگ رولز)'),
                    icon: Icons.maps_home_work_outlined,
                    children: [
                      Text(
                        _t(
                          'Development authorities and district councils guidelines for colony land apportionment:',
                          'کسی بھی کالونی کے کل رقبے کی تقسیم کے لیے ضلعی کونسل اور ڈویلپمنٹ اتھارٹیز کے رہنما اصول:',
                        ),
                        style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 8),
                      _buildDetailRow(
                        _t('Roads & Streets', 'سڑکیں اور گلیاں'),
                        _t('20% to 30% Area (Main road 40 to 80 ft, streets 30 to 40 ft)', '20% تا 30% رقبہ (مین روڈ 40 تا 80 فٹ، گلیاں 30 تا 40 فٹ)'),
                      ),
                      _buildDetailRow(
                        _t('Parks & Playgrounds', 'پارک و کھیل کا میدان'),
                        _t('7% to 10% Area', '7% تا 10% رقبہ'),
                      ),
                      _buildDetailRow(
                        _t('Public Amenities (Mosque, School, Clinic)', 'عوامی سہولیات (جامع مسجد، اسکول، ڈسپنسری)'),
                        _t('5% to 8% Area', '5% تا 8% رقبہ'),
                      ),
                      _buildDetailRow(
                        _t('Graveyard & Sewerage Plant', 'قبرستان اور سیوریج پلانٹ'),
                        _t('2% to 3% Area', '2% تا 3% رقبہ'),
                      ),
                      _buildDetailRow(
                        _t('Commercial Market & Shops', 'کمرشل مارکیٹ و دکانیں'),
                        _t('4% to 5% Area', '4% تا 5% رقبہ'),
                      ),
                      _buildDetailRow(
                        _t('Remaining Residential Plots', 'بقایا رہائشی پلاٹ'),
                        _t('50% to 60% Area', '50% تا 60% رقبہ'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _unitDisplay(String unit) {
    if (_language == InfoLanguage.english) {
      return unit;
    }
    if (_language == InfoLanguage.urdu) {
      switch (unit) {
        case 'Sarsai': return 'سرسائی';
        case 'Marla': return 'مرلہ';
        case 'Kanal': return 'کنال';
        case 'Acre / Qila': return 'ایکڑ / قلعہ';
        case 'Murabba': return 'مربع';
        case 'Square Feet': return 'اسکوائر فٹ';
        case 'Square Yard (Gaz)': return 'اسکوائر گز';
        default: return unit;
      }
    }
    switch (unit) {
      case 'Sarsai': return 'Sarsai (سرسائی)';
      case 'Marla': return 'Marla (مرلہ)';
      case 'Kanal': return 'Kanal (کنال)';
      case 'Acre / Qila': return 'Acre / Qila (ایکڑ)';
      case 'Murabba': return 'Murabba (مربع)';
      case 'Square Feet': return 'Sq Ft (اسکوائر فٹ)';
      case 'Square Yard (Gaz)': return 'Gaz (اسکوائر گز)';
      default: return unit;
    }
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
                Icon(icon, color: AppTheme.primaryNavy, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryNavy,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: AppTheme.dividerColor),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTable(List<List<String>> data) {
    return Table(
      border: TableBorder.all(color: AppTheme.dividerColor),
      columnWidths: const {
        0: FlexColumnWidth(1.4),
        1: FlexColumnWidth(1.6),
        2: FlexColumnWidth(1.3),
        3: FlexColumnWidth(1.2),
      },
      children: data.asMap().entries.map((entry) {
        final index = entry.key;
        final row = entry.value;
        final isHeader = index == 0;

        return TableRow(
          decoration: BoxDecoration(
            color: isHeader ? const Color(0xFFF1F5F9) : Colors.white,
          ),
          children: row.map((cell) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Text(
                cell,
                textAlign: isHeader ? TextAlign.center : TextAlign.left,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
                  color: isHeader ? AppTheme.charcoalText : AppTheme.charcoalText.withValues(alpha: 0.9),
                ),
              ),
            );
          }).toList(),
        );
      }).toList(),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, color: AppTheme.charcoalText),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBullet(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 12, color: AppTheme.charcoalText, height: 1.4),
          children: [
            TextSpan(text: '• $title ', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryNavy)),
            TextSpan(text: body),
          ],
        ),
      ),
    );
  }
}
