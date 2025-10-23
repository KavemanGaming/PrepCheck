import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Simple US-style timestamp formatting.
/// Accepts Firestore [Timestamp], [DateTime], or null.
class TimeHelper {
  static String usTime(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    return DateFormat.yMd().add_jm().format(local); // e.g. 10/21/2025 3:05 PM
  }
}

/// Backwards-compat wrapper for code that calls `formatETFromTimestamp(...)`.
/// Usage: final when = formatETFromTimestamp(doc['completedAt']);
String formatETFromTimestamp(dynamic ts) {
  DateTime? dt;
  if (ts == null) return '';
  if (ts is Timestamp) {
    dt = ts.toDate();
  } else if (ts is DateTime) {
    dt = ts;
  } else {
    return '';
  }
  return TimeHelper.usTime(dt);
}
