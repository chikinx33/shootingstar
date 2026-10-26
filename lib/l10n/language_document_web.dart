import 'dart:js_interop';

@JS('document.documentElement.lang')
external set _documentLanguage(String value);
@JS('document.title')
external set _documentTitle(String value);

void updateLanguageDocument(String code) {
  _documentLanguage = code;
  _documentTitle = code == 'en' ? 'Purrtectors: Cat Sky Squad' : '수호묘 특공대';
}
