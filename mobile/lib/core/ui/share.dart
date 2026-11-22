import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Partage Android d'une image (reçu) ou d'un fichier (copie manuelle). Remplacé dans les tests.
abstract class Sharer {
  Future<void> shareImage(Uint8List png, {required String name, String? text});
  Future<void> shareFile(String path, {String? text});
}

class SystemSharer implements Sharer {
  const SystemSharer();

  @override
  Future<void> shareImage(
    Uint8List png, {
    required String name,
    String? text,
  }) async {
    final file = File('${(await getTemporaryDirectory()).path}/$name.png');
    await file.writeAsBytes(png, flush: true);
    await shareFile(file.path, text: text);
  }

  @override
  Future<void> shareFile(String path, {String? text}) async {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(path)], text: text),
    );
  }
}
