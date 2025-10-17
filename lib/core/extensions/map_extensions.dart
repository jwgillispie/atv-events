/// Extension methods for cleaner map building, especially for Firestore updates
extension MapBuilder on Map<String, dynamic> {
  /// Adds a key-value pair only if the value is not null
  void addIfNotNull(String key, dynamic value) {
    if (value != null) {
      this[key] = value;
    }
  }

  /// Adds multiple key-value pairs only if values are not null
  void addAllIfNotNull(Map<String, dynamic?> entries) {
    entries.forEach((key, value) {
      if (value != null) {
        this[key] = value;
      }
    });
  }

  /// Adds a key-value pair only if the value is not null and not empty
  void addIfNotEmpty(String key, dynamic value) {
    if (value != null) {
      if (value is String && value.isNotEmpty) {
        this[key] = value;
      } else if (value is Iterable && value.isNotEmpty) {
        this[key] = value;
      } else if (value is Map && value.isNotEmpty) {
        this[key] = value;
      } else if (value is! String && value is! Iterable && value is! Map) {
        this[key] = value;
      }
    }
  }

  /// Creates a Firestore-compatible update map
  Map<String, dynamic> toFirestoreUpdate() {
    final result = <String, dynamic>{};
    forEach((key, value) {
      if (value != null) {
        result[key] = value;
      }
    });
    return result;
  }
}