/// 폼 유효성 검사 유틸리티
///
/// 사용 예시:
/// ```dart
/// TextFormField(
///   validator: Validators.email,
/// )
///
/// // 여러 validator 조합
/// TextFormField(
///   validator: (value) => Validators.combine(value, [
///     Validators.required,
///     Validators.email,
///   ]),
/// )
/// ```
class Validators {
  Validators._();

  /// 필수 입력 검증
  static String? required(String? value, {String? fieldName}) {
    if (value == null || value.trim().isEmpty) {
      return '${fieldName ?? '이 항목'}을(를) 입력해 주세요';
    }
    return null;
  }

  /// 이메일 형식 검증
  static String? email(String? value) {
    if (value == null || value.isEmpty) return null;

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(value)) {
      return '올바른 이메일 주소를 입력해 주세요';
    }
    return null;
  }

  /// 최소 길이 검증
  static String? Function(String?) minLength(int min, {String? fieldName}) {
    return (String? value) {
      if (value == null || value.isEmpty) return null;

      if (value.length < min) {
        return '${fieldName ?? '입력값'}은(는) $min자 이상이어야 합니다';
      }
      return null;
    };
  }

  /// 최대 길이 검증
  static String? Function(String?) maxLength(int max, {String? fieldName}) {
    return (String? value) {
      if (value == null || value.isEmpty) return null;

      if (value.length > max) {
        return '${fieldName ?? '입력값'}은(는) $max자 이하여야 합니다';
      }
      return null;
    };
  }

  /// 길이 범위 검증
  static String? Function(String?) lengthBetween(
    int min,
    int max, {
    String? fieldName,
  }) {
    return (String? value) {
      if (value == null || value.isEmpty) return null;

      if (value.length < min || value.length > max) {
        return '${fieldName ?? '입력값'}은(는) $min자에서 $max자 사이여야 합니다';
      }
      return null;
    };
  }

  /// 전화번호 형식 검증
  static String? phone(String? value) {
    if (value == null || value.isEmpty) return null;

    // 숫자와 하이픈만 허용
    final phoneRegex = RegExp(r'^[\d\-+\s()]{10,}$');

    if (!phoneRegex.hasMatch(value)) {
      return '올바른 전화번호를 입력해 주세요';
    }
    return null;
  }

  /// 비밀번호 강도 검증
  static String? password(
    String? value, {
    int minLength = 8,
    bool requireUppercase = true,
    bool requireLowercase = true,
    bool requireNumber = true,
    bool requireSpecialChar = false,
  }) {
    if (value == null || value.isEmpty) {
      return '비밀번호를 입력해 주세요';
    }

    final errors = <String>[];

    if (value.length < minLength) {
      errors.add('$minLength자 이상');
    }

    if (requireUppercase && !value.contains(RegExp(r'[A-Z]'))) {
      errors.add('대문자');
    }

    if (requireLowercase && !value.contains(RegExp(r'[a-z]'))) {
      errors.add('소문자');
    }

    if (requireNumber && !value.contains(RegExp(r'[0-9]'))) {
      errors.add('숫자');
    }

    if (requireSpecialChar &&
        !value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      errors.add('특수문자');
    }

    if (errors.isNotEmpty) {
      return '비밀번호는 ${errors.join(', ')}를 포함해야 합니다';
    }

    return null;
  }

  /// 비밀번호 확인 검증
  static String? Function(String?) confirmPassword(String password) {
    return (String? value) {
      if (value == null || value.isEmpty) {
        return '비밀번호를 다시 입력해 주세요';
      }

      if (value != password) {
        return '비밀번호가 일치하지 않습니다';
      }

      return null;
    };
  }

  /// 숫자만 허용
  static String? numeric(String? value, {String? fieldName}) {
    if (value == null || value.isEmpty) return null;

    if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
      return '${fieldName ?? '입력값'}은(는) 숫자만 입력 가능합니다';
    }
    return null;
  }

  /// 숫자 범위 검증
  static String? Function(String?) numberRange(
    num min,
    num max, {
    String? fieldName,
  }) {
    return (String? value) {
      if (value == null || value.isEmpty) return null;

      final number = num.tryParse(value);
      if (number == null) {
        return '${fieldName ?? '입력값'}은(는) 숫자여야 합니다';
      }

      if (number < min || number > max) {
        return '${fieldName ?? '입력값'}은(는) $min에서 $max 사이여야 합니다';
      }

      return null;
    };
  }

  /// URL 형식 검증
  static String? url(String? value) {
    if (value == null || value.isEmpty) return null;

    final urlRegex = RegExp(
      r'^https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)$',
    );

    if (!urlRegex.hasMatch(value)) {
      return '올바른 URL을 입력해 주세요';
    }
    return null;
  }

  /// 정규식 패턴 검증
  static String? Function(String?) pattern(
    RegExp regex, {
    required String message,
  }) {
    return (String? value) {
      if (value == null || value.isEmpty) return null;

      if (!regex.hasMatch(value)) {
        return message;
      }
      return null;
    };
  }

  /// 여러 validator 조합
  ///
  /// 첫 번째로 실패한 validator의 에러 메시지를 반환합니다.
  ///
  /// 사용 예시:
  /// ```dart
  /// validator: (value) => Validators.combine(value, [
  ///   Validators.required,
  ///   Validators.email,
  /// ]),
  /// ```
  static String? combine(
    String? value,
    List<String? Function(String?)> validators,
  ) {
    for (final validator in validators) {
      final result = validator(value);
      if (result != null) return result;
    }
    return null;
  }

  /// 조건부 검증
  ///
  /// condition이 true일 때만 validator를 실행합니다.
  static String? Function(String?) when(
    bool condition,
    String? Function(String?) validator,
  ) {
    return (String? value) {
      if (!condition) return null;
      return validator(value);
    };
  }
}
