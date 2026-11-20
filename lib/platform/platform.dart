/// Platform services that differ between desktop (dart:io) and web.
library;

export 'platform_io.dart' if (dart.library.js_interop) 'platform_web.dart';
