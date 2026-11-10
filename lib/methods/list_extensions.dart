extension SafeListExtension<T> on List<T> {
  /// Safely extracts a sublist without throwing [RangeError].
  /// Returns an empty list if [start] is out of bounds or list is empty.
  List<T> safeSublist(int start, [int? end]) {
    if (isEmpty || start >= length || start < 0) return [];
    final safeEnd = (end == null || end > length) ? length : (end < start ? start : end);
    if (start >= safeEnd) return [];
    return sublist(start, safeEnd);
  }
}
