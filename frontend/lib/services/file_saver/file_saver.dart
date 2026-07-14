import 'file_saver_stub.dart'
    if (dart.library.html) 'file_saver_web.dart'
    if (dart.library.io) 'file_saver_io.dart';

class FileSaver {
  static Future<void> saveAndLaunchFile(List<int> bytes, String fileName) =>
      saveAndLaunchFileImpl(bytes, fileName);
}
