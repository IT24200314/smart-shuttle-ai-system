import 'dart:html' as html;

Future<void> triggerBrowserDownload(String url) async {
  final anchor = html.AnchorElement(href: url)
    ..style.display = 'none'
    ..download = '';
  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
}
