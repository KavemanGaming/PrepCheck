import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';

FirebaseStorage storageForAppBucket() {
  final bucket = Firebase.app().options.storageBucket;
  if (bucket != null && bucket.isNotEmpty) {
    return FirebaseStorage.instanceFor(bucket: bucket);
  }
  return FirebaseStorage.instance;
}
