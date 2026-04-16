import 'download_helper_stub.dart'
    if (dart.library.html) 'download_helper_web.dart';

Future<void> triggerFileDownload(String url) => triggerBrowserDownload(url);
