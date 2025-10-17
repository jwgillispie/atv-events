/// Utility functions for cleaner error handling
class ErrorUtils {
  /// Executes a function and returns null if it throws
  static T? tryOrNull<T>(T Function() fn) {
    try {
      return fn();
    } catch (_) {
      return null;
    }
  }

  /// Executes an async function and returns null if it throws
  static Future<T?> tryOrNullAsync<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } catch (_) {
      return null;
    }
  }

  /// Executes a function and returns a default value if it throws
  static T tryOrDefault<T>(T Function() fn, T defaultValue) {
    try {
      return fn();
    } catch (_) {
      return defaultValue;
    }
  }

  /// Executes an async function and returns a default value if it throws
  static Future<T> tryOrDefaultAsync<T>(
    Future<T> Function() fn,
    T defaultValue,
  ) async {
    try {
      return await fn();
    } catch (_) {
      return defaultValue;
    }
  }
}