import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../db/database.dart';
import 'cahier_file.dart';

/// Copie manuelle : fichier .cahier (zip : data.json + dossier photos).
class ManualBackup {
  ManualBackup(this.db, {required this.photosDir, required this.tempDir});

  final AppDatabase db;
  final Future<Directory> Function() photosDir;
  final Future<Directory> Function() tempDir;

  /// Crée le fichier .cahier et renvoie son chemin.
  Future<String> export() async {
    final file = await CahierFile.export(db);
    final archive = Archive()
      ..add(ArchiveFile.bytes('data.json', utf8.encode(file.json)));
    final data = jsonDecode(file.json) as Map<String, dynamic>;
    final seen = <String>{};
    for (final rows in (data['tables'] as Map).values) {
      for (final r in rows as List) {
        final path = (r as Map)['photoPath'] as String?;
        if (path == null || !seen.add(path)) continue;
        final f = File(path);
        if (f.existsSync()) {
          archive.add(
            ArchiveFile.bytes('photos/${_base(path)}', f.readAsBytesSync()),
          );
        }
      }
    }
    final now = DateTime.now();
    final name =
        'cahier-${now.year}-${_two(now.month)}-${_two(now.day)}.cahier';
    final out = File('${(await tempDir()).path}/$name');
    await out.writeAsBytes(ZipEncoder().encodeBytes(archive), flush: true);
    return out.path;
  }

  /// Remplace tout le cahier par ce fichier (version vérifiée, transaction, photos restaurées).
  /// Lève FormatException si le fichier n'est pas une copie valable.
  Future<void> import(String path) async {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(await File(path).readAsBytes());
    } catch (_) {
      throw const FormatException("Ce fichier n'est pas une copie de cahier.");
    }
    final dataEntry = archive.findFile('data.json');
    if (dataEntry == null) {
      throw const FormatException("Ce fichier n'est pas une copie de cahier.");
    }
    final data =
        jsonDecode(utf8.decode(dataEntry.readBytes()!)) as Map<String, dynamic>;
    if ((data['format_version'] as int? ?? 99) > CahierFile.formatVersion) {
      throw const FormatException(
        "Cette copie vient d'une version plus récente de l'app.",
      );
    }

    final dir = await photosDir();
    final moved = <String, String>{};
    for (final entry in archive.files) {
      if (!entry.isFile || !entry.name.startsWith('photos/')) continue;
      final base = _base(entry.name);
      final target = File('${dir.path}/$base');
      await target.writeAsBytes(entry.readBytes()!, flush: true);
      moved[base] = target.path;
    }
    for (final rows in (data['tables'] as Map).values) {
      for (final r in rows as List) {
        final row = r as Map;
        final path = row['photoPath'] as String?;
        if (path != null) row['photoPath'] = moved[_base(path)];
      }
    }
    await CahierFile(jsonEncode(data), const {}).importInto(db);
  }

  static String _base(String path) => path.split('/').last;
  static String _two(int v) => v.toString().padLeft(2, '0');
}

/// Choix du fichier à remettre. Remplacé dans les tests.
abstract class CahierFilePicker {
  Future<String?> pick();
}

class SystemFilePicker implements CahierFilePicker {
  const SystemFilePicker();

  @override
  Future<String?> pick() async {
    final files = await FilePicker.pickFiles(type: FileType.any);
    return files.isEmpty ? null : files.first.path;
  }
}

Future<Directory> defaultTempDir() => getTemporaryDirectory();
