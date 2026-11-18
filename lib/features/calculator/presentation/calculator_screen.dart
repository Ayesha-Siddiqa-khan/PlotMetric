import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../logic/expression_evaluator.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  final List<String> _tokens = [];
  String _currentOperand = '';
  String _displayResult = '0';
  String? _errorMessage;
  bool _justCalculated = false;

  final NumberFormat _formatter = NumberFormat('#,##0.########', 'en_US');

  void _onDigit(String digit) {
    setState(() {
      if (_justCalculated) {
        _tokens.clear();
        _currentOperand = digit;
        _errorMessage = null;
        _justCalculated = false;
        _displayResult = digit;
        return;
      }

      if (_currentOperand == '0' && digit == '0') return;
      if (_currentOperand == '0' && digit != '.') {
        _currentOperand = digit;
      } else {
        _currentOperand += digit;
      }
      _errorMessage = null;
      _displayResult = _currentOperand;
    });
  }

  void _onDecimal() {
    setState(() {
      if (_justCalculated) {
        _tokens.clear();
        _currentOperand = '0.';
        _errorMessage = null;
        _justCalculated = false;
        _displayResult = _currentOperand;
        return;
      }

      if (_currentOperand.isEmpty) {
        _currentOperand = '0.';
      } else if (!_currentOperand.contains('.')) {
        _currentOperand += '.';
      }
      _errorMessage = null;
      _displayResult = _currentOperand;
    });
  }

  void _onOperator(String op) {
    setState(() {
      _errorMessage = null;
      if (_currentOperand.isNotEmpty) {
        _tokens.add(_currentOperand);
        _tokens.add(op);
        _currentOperand = '';
        _justCalculated = false;
      } else if (_tokens.isNotEmpty) {
        final last = _tokens.last;
        if (last == '+' || last == '−' || last == '-' || last == '×' || last == '*' || last == '÷' || last == '/') {
          // Replace operator
          _tokens[_tokens.length - 1] = op;
        } else {
          _tokens.add(op);
        }
        _justCalculated = false;
      }
    });
  }

  void _onToggleSign() {
    setState(() {
      if (_currentOperand.isNotEmpty) {
        if (_currentOperand.startsWith('-')) {
          _currentOperand = _currentOperand.substring(1);
        } else {
          _currentOperand = '-$_currentOperand';
        }
        _displayResult = _currentOperand;
      } else if (_justCalculated && _displayResult != '0' && _errorMessage == null) {
        if (_displayResult.startsWith('-')) {
          _displayResult = _displayResult.substring(1);
        } else {
          _displayResult = '-$_displayResult';
        }
        _currentOperand = _displayResult;
        _tokens.clear();
        _justCalculated = false;
      }
    });
  }

  void _onPercentage() {
    setState(() {
      if (_currentOperand.isNotEmpty) {
        final val = double.tryParse(_currentOperand);
        if (val != null) {
          final res = val / 100.0;
          _currentOperand = _formatter.format(res);
          _displayResult = _currentOperand;
        }
      } else if (_justCalculated && _errorMessage == null) {
        final val = double.tryParse(_displayResult.replaceAll(',', ''));
        if (val != null) {
          final res = val / 100.0;
          _displayResult = _formatter.format(res);
          _currentOperand = _displayResult;
          _tokens.clear();
          _justCalculated = false;
        }
      }
    });
  }

  void _onBackspace() {
    setState(() {
      if (_justCalculated) {
        _tokens.clear();
        _currentOperand = '';
        _displayResult = '0';
        _justCalculated = false;
        return;
      }

      if (_currentOperand.isNotEmpty) {
        _currentOperand = _currentOperand.substring(0, _currentOperand.length - 1);
        _displayResult = _currentOperand.isEmpty ? '0' : _currentOperand;
      } else if (_tokens.isNotEmpty) {
        _tokens.removeLast();
      }
    });
  }

  void _onClear() {
    setState(() {
      _tokens.clear();
      _currentOperand = '';
      _displayResult = '0';
      _errorMessage = null;
      _justCalculated = false;
    });
  }

  void _onEquals() {
    setState(() {
      final expressionTokens = List<String>.from(_tokens);
      if (_currentOperand.isNotEmpty) {
        expressionTokens.add(_currentOperand);
      }

      if (expressionTokens.isEmpty) return;

      // Drop trailing operator if any
      final last = expressionTokens.last;
      if (last == '+' || last == '−' || last == '-' || last == '×' || last == '*' || last == '÷' || last == '/') {
        expressionTokens.removeLast();
      }

      if (expressionTokens.isEmpty) return;

      final result = ExpressionEvaluator.evaluate(expressionTokens);
      if (result.isSuccess) {
        final val = result.value!;
        // Format nicely
        if (val.abs() == (val.abs().floorToDouble())) {
          _displayResult = NumberFormat('#,##0', 'en_US').format(val.toInt());
        } else {
          _displayResult = _formatter.format(val);
        }
        _errorMessage = null;
        _tokens.clear();
        _currentOperand = val.toString();
        _justCalculated = true;
      } else {
        _errorMessage = result.error;
        _displayResult = 'Error';
        _justCalculated = true;
      }
    });
  }

  void _copyResult() {
    final textToCopy = _errorMessage ?? _displayResult;
    Clipboard.setData(ClipboardData(text: textToCopy));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied "$textToCopy" to clipboard'),
        duration: const Duration(seconds: 2),
        backgroundColor: AppTheme.primaryNavy,
      ),
    );
  }

  String get _expressionDisplay {
    final buffer = StringBuffer();
    for (final t in _tokens) {
      buffer.write('$t ');
    }
    if (_currentOperand.isNotEmpty) {
      buffer.write(_currentOperand);
    }
    return buffer.toString().trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Everyday Calculator'),
        actions: [
          Tooltip(
            message: '% divides active number by 100.\n± flips sign.\nMultiplication and division precede addition and subtraction.',
            child: IconButton(
              icon: const Icon(Icons.help_outline),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Calculator Help'),
                    content: const Text(
                      '• Operator precedence: × and ÷ are evaluated before + and −.\n'
                      '• ± toggles positive/negative on current operand.\n'
                      '• % divides current operand by 100.\n'
                      '• Division by zero is safely caught and displayed.\n'
                      '• Use "Copy Result" to copy the current answer.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy Result',
            onPressed: _copyResult,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Display Area
            Expanded(
              flex: 2,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                color: Colors.white,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      reverse: true,
                      child: Text(
                        _expressionDisplay.isEmpty ? ' ' : _expressionDisplay,
                        style: const TextStyle(
                          fontSize: 18,
                          color: AppTheme.textMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      reverse: true,
                      child: Text(
                        _errorMessage ?? _displayResult,
                        style: TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.bold,
                          color: _errorMessage != null
                              ? AppTheme.dangerRed
                              : AppTheme.primaryNavy,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: AppTheme.dividerColor),
            // Keypad
            Expanded(
              flex: 5,
              child: Container(
                padding: const EdgeInsets.all(8),
                color: AppTheme.paleBackground,
                child: Column(
                  children: [
                    _buildButtonRow(['AC', '±', '%', '÷']),
                    _buildButtonRow(['7', '8', '9', '×']),
                    _buildButtonRow(['4', '5', '6', '−']),
                    _buildButtonRow(['1', '2', '3', '+']),
                    _buildButtonRow(['0', '.', '⌫', '=']),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButtonRow(List<String> labels) {
    return Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: labels.map((label) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: _buildButton(label),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildButton(String label) {
    final isOperator = label == '+' || label == '−' || label == '×' || label == '÷';
    final isAction = label == 'AC' || label == '±' || label == '%' || label == '⌫';
    final isEquals = label == '=';

    Color bgColor = Colors.white;
    Color fgColor = AppTheme.primaryNavy;

    if (isEquals) {
      bgColor = AppTheme.accentTeal;
      fgColor = Colors.white;
    } else if (isOperator) {
      bgColor = const Color(0xFFE8EEF5);
      fgColor = AppTheme.accentTeal;
    } else if (isAction) {
      bgColor = const Color(0xFFE8EEF5);
      fgColor = AppTheme.primaryNavy;
    }

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: bgColor,
        foregroundColor: fgColor,
        elevation: 0.5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppTheme.dividerColor, width: 0.5),
        ),
        padding: EdgeInsets.zero,
      ),
      onPressed: () {
        if (label == 'AC') {
          _onClear();
        } else if (label == '±') {
          _onToggleSign();
        } else if (label == '%') {
          _onPercentage();
        } else if (label == '⌫') {
          _onBackspace();
        } else if (label == '=') {
          _onEquals();
        } else if (label == '.') {
          _onDecimal();
        } else if (isOperator) {
          _onOperator(label);
        } else {
          _onDigit(label);
        }
      },
      child: Text(
        label,
        style: TextStyle(
          fontSize: isAction || isOperator || isEquals ? 22 : 24,
          fontWeight: isEquals ? FontWeight.bold : FontWeight.w500,
        ),
      ),
    );
  }
}
