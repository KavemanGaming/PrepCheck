
// Helper to guess contentType from file path
String guessContentType(String path, {String fallback = 'application/octet-stream'}) {
  final p = path.toLowerCase();
  if (p.endsWith('.jpg') || p.endsWith('.jpeg')) return 'image/jpeg';
  if (p.endsWith('.png')) return 'image/png';
  if (p.endsWith('.gif')) return 'image/gif';
  if (p.endsWith('.webp')) return 'image/webp';
  if (p.endsWith('.mp4')) return 'video/mp4';
  if (p.endsWith('.mov')) return 'video/quicktime';
  if (p.endsWith('.avi')) return 'video/x-msvideo';
  if (p.endsWith('.mkv')) return 'video/x-matroska';
  if (p.endsWith('.pdf')) return 'application/pdf';
  return fallback;
}
