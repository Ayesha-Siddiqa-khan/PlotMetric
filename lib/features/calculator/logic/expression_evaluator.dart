class EvaluationResult {
  final double? value;
  final String? error;

  const EvaluationResult.success(double this.value) : error = null;
  const EvaluationResult.failure(String this.error) : value = null;

  bool get isSuccess => error == null;
}

class ExpressionEvaluator {
  const ExpressionEvaluator._();

  /// Evaluates arithmetic expressions with +, -, ×, ÷ respecting operator precedence.
  /// Does not use dynamic or unrestricted code evaluation.
  static EvaluationResult evaluate(List<String> tokens) {
    if (tokens.isEmpty) {
      return const EvaluationResult.failure('Empty expression');
    }

    try {
      // 1. Shunting-yard algorithm to convert infix tokens to postfix (RPN)
      final outputQueue = <String>[];
      final operatorStack = <String>[];

      for (int i = 0; i < tokens.length; i++) {
        final token = tokens[i];

        if (_isNumber(token)) {
          outputQueue.add(token);
        } else if (_isOperator(token)) {
          while (operatorStack.isNotEmpty &&
              _isOperator(operatorStack.last) &&
              _precedence(operatorStack.last) >= _precedence(token)) {
            outputQueue.add(operatorStack.removeLast());
          }
          operatorStack.add(token);
        } else {
          return EvaluationResult.failure('Invalid token: $token');
        }
      }

      while (operatorStack.isNotEmpty) {
        outputQueue.add(operatorStack.removeLast());
      }

      // 2. Evaluate RPN
      final evalStack = <double>[];
      for (final token in outputQueue) {
        if (_isNumber(token)) {
          final val = double.tryParse(token);
          if (val == null) {
            return EvaluationResult.failure('Malformed number: $token');
          }
          evalStack.add(val);
        } else if (_isOperator(token)) {
          if (evalStack.length < 2) {
            return const EvaluationResult.failure('Malformed expression');
          }
          final right = evalStack.removeLast();
          final left = evalStack.removeLast();

          switch (token) {
            case '+':
              evalStack.add(left + right);
              break;
            case '-':
            case '−':
              evalStack.add(left - right);
              break;
            case '×':
            case '*':
              evalStack.add(left * right);
              break;
            case '÷':
            case '/':
              if (right == 0.0) {
                return const EvaluationResult.failure('Cannot divide by zero');
              }
              evalStack.add(left / right);
              break;
            default:
              return EvaluationResult.failure('Unknown operator: $token');
          }
        }
      }

      if (evalStack.length != 1) {
        return const EvaluationResult.failure('Invalid expression format');
      }

      final finalValue = evalStack.first;
      if (finalValue.isInfinite || finalValue.isNaN) {
        return const EvaluationResult.failure('Cannot divide by zero');
      }

      return EvaluationResult.success(finalValue);
    } catch (e) {
      return EvaluationResult.failure('Calculation error: $e');
    }
  }

  static bool _isNumber(String token) {
    return double.tryParse(token) != null;
  }

  static bool _isOperator(String token) {
    return token == '+' ||
        token == '-' ||
        token == '−' ||
        token == '×' ||
        token == '*' ||
        token == '÷' ||
        token == '/';
  }

  static int _precedence(String op) {
    if (op == '×' || op == '*' || op == '÷' || op == '/') {
      return 2;
    }
    if (op == '+' || op == '-' || op == '−') {
      return 1;
    }
    return 0;
  }
}
