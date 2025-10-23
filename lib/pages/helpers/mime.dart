// lib/pages/helpers/mime.dart
String guessContentType(String path, {String fallback = 'application/octet-stream'}) {
  final p = path.toLowerCase();
  if (p.endsWith('.jpg') || p.endsWith('.jpeg')) return 'image/jpeg';
  if (p.endsWith('.png')) return 'image/png';
  if (p.endsWith('.gif')) return 'image/gif';
  if (p.endsWith('.webp')) return 'image/webp';
  if (p.endsWith('.heic')) return 'image/heic';
  if (p.endsWith('.mp4')) return 'video/mp4';
  if (p.endsWith('.mov')) return 'video/quicktime';
  if (p.endsWith('.avi')) return 'video/x-msvideo';
  if (p.endsWith('.mkv')) return 'video/x-matroska';
  if (p.endsWith('.webm')) return 'video/webm';
  if (p.endsWith('.3gp')) return 'video/3gpp';
  if (p.endsWith('.pdf')) return 'application/pdf';
  if (p.endsWith('.txt')) return 'text/plain';
  return fallback;
}
