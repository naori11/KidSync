// Conditional import for HTML functionality
// Uses real dart:html on web, stub implementation on other platforms
export 'html_stub.dart' if (dart.library.html) 'html_real.dart';