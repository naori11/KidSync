// Stub implementation for non-web platforms
// This prevents web-specific imports from causing errors on mobile

// Mock classes for web-specific functionality
class MockWindow {
  MockSessionStorage get sessionStorage => MockSessionStorage();
  MockLocation get location => MockLocation();
}

class MockSessionStorage {
  bool containsKey(String key) => false;
  String? operator [](String key) => null;
  void operator []=(String key, String value) {}
  void remove(String key) {}
}

class MockLocation {
  String get href => '';
}

class MockBlob {
  MockBlob(List<String> data, [String? type]);
}

class MockUrl {
  static String createObjectUrlFromBlob(MockBlob blob) => '';
  static void revokeObjectUrl(String url) {}
}

class MockAnchorElement {
  MockAnchorElement({String? href});
  void setAttribute(String name, String value) {}
  void click() {}
}

class MockDocument {
  MockBody? get body => MockBody();
}

class MockBody {
  MockChildren get children => MockChildren();
}

class MockChildren {
  void add(MockAnchorElement element) {}
  void remove(MockAnchorElement element) {}
}

// Export mock objects to match dart:html API
final window = MockWindow();
final document = MockDocument();

class Blob extends MockBlob {
  Blob(List<String> data, [String? type]) : super(data, type);
}

class Url extends MockUrl {}

class AnchorElement extends MockAnchorElement {
  AnchorElement({String? href}) : super(href: href);
}
