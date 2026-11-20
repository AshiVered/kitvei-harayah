import 'dart:convert';
import 'dart:js_interop';

import 'package:archive/archive.dart';
import 'package:file_selector/file_selector.dart';
import 'package:web/web.dart' as web;

const isWeb = true;

/// Decompresses a gzip file (pure Dart).
List<int> gunzipBytes(List<int> bytes) => const GZipDecoder().decodeBytes(bytes);

/// There are no environment variables in a browser.
String? envVar(String name) => null;

/// Browsers cannot pick a save location: the file is downloaded instead.
Future<bool> saveTextFile(String suggestedName, String content, XTypeGroup type) async {
  final bytes = utf8.encode(content);
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: 'application/json'));
  final url = web.URL.createObjectURL(blob);
  final a = web.HTMLAnchorElement()
    ..href = url
    ..download = suggestedName;
  web.document.body?.append(a);
  a.click();
  a.remove();
  web.URL.revokeObjectURL(url);
  return true;
}
