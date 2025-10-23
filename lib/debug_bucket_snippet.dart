// Temporary: print Storage bucket during app startup
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';

void printBucket() {
  try {
    debugPrint('Storage bucket: ${Firebase.app().options.storageBucket}');
  } catch (e) {
    debugPrint('Could not read storage bucket: $e');
  }
}
