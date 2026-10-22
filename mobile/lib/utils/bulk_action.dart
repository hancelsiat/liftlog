/// Outcome of a bulk admin action (approve / reject / delete many items).
class BulkResult {
  const BulkResult(this.succeeded, this.errors);

  final int succeeded;

  /// One message per failed item.
  final List<String> errors;

  int get failed => errors.length;
  int get total => succeeded + failed;

  /// e.g. "Deleted 3 users." or "Deleted 2 of 3 users. 1 failed: Not found".
  String message({required String verb, required String noun}) {
    final plural = total == 1 ? noun : '${noun}s';
    if (failed == 0) return '$verb $succeeded $plural.';
    if (succeeded == 0) {
      return '$verb 0 of $total $plural. ${errors.first}';
    }
    return '$verb $succeeded of $total $plural. '
        '$failed failed: ${errors.first}';
  }
}

/// Runs [action] for every item, one after another (the backend sends an
/// email per item, so requests are not fired in parallel). A failure does
/// not stop the remaining items. [onProgress] is called after each item.
Future<BulkResult> runBulk<T>(
  List<T> items,
  Future<void> Function(T item) action, {
  void Function(int done, int total)? onProgress,
}) async {
  var succeeded = 0;
  final errors = <String>[];
  for (var i = 0; i < items.length; i++) {
    try {
      await action(items[i]);
      succeeded++;
    } catch (e) {
      errors.add(e.toString().replaceFirst('Exception: ', ''));
    }
    onProgress?.call(i + 1, items.length);
  }
  return BulkResult(succeeded, errors);
}
