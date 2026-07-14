import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';

Future<void> saveAndLaunchFileImpl(List<int> bytes, String fileName) async {
  if (Platform.isAndroid) {
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      status = await Permission.storage.request();
      if (!status.isGranted && await Permission.manageExternalStorage.status.isDenied) {
        await Permission.manageExternalStorage.request();
      }
    }
  }
  final dir = await getExternalStorageDirectory();
  String path = "${dir?.path ?? ''}/$fileName";
  final file = File(path);
  await file.writeAsBytes(bytes);
  await OpenFilex.open(path);
}
