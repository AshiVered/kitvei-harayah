import 'dart:io';

import 'package:file_selector/file_selector.dart';

const isWeb = false;

/// Decompresses a gzip file (native zlib).
List<int> gunzipBytes(List<int> bytes) => gzip.decode(bytes);

/// Environment variable, or null.
String? envVar(String name) => Platform.environment[name];

/// Asks where to save and writes [content]. Returns false if the user cancelled.
Future<bool> saveTextFile(String suggestedName, String content, XTypeGroup type) async {
  final loc = await getSaveLocation(suggestedName: suggestedName, acceptedTypeGroups: [type]);
  if (loc == null) return false;
  final ext = '.${type.extensions!.first}';
  final path = loc.path.toLowerCase().endsWith(ext) ? loc.path : '${loc.path}$ext';
  await File(path).writeAsString(content);
  return true;
}
