import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Photos : 800 px max, ~100 Ko, JPEG, dossier de l'app.
abstract class PhotoService {
  /// Galerie (ou appareil photo). Chemin de la photo réduite, ou null si annulé.
  Future<String?> pick({bool camera = false});

  Future<void> delete(String path);
}

class DevicePhotoService implements PhotoService {
  DevicePhotoService([ImagePicker? picker]) : _picker = picker ?? ImagePicker();
  final ImagePicker _picker;

  static Future<Directory> folder() async {
    final dir = Directory(
      '${(await getApplicationDocumentsDirectory()).path}/photos',
    );
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  @override
  Future<String?> pick({bool camera = false}) async {
    final picked = await _picker.pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      requestFullMetadata: false,
    );
    if (picked == null) return null;
    final target = '${(await folder()).path}/${const Uuid().v4()}.jpg';
    final out = await FlutterImageCompress.compressAndGetFile(
      picked.path,
      target,
      minWidth: 800,
      minHeight: 800,
      quality: 70,
    );
    if (out == null) {
      await File(picked.path).copy(target);
    }
    return target;
  }

  @override
  Future<void> delete(String path) async {
    final f = File(path);
    if (f.existsSync()) await f.delete();
  }
}
