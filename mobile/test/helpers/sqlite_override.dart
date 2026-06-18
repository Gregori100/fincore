import 'dart:ffi';
import 'dart:io';

import 'package:sqlite3/open.dart';

/// Override del loader de sqlite3 en tests de VM Linux.
///
/// Sin esto, el runtime de Dart NO encuentra el binding nativo de sqlite3 al
/// correr `flutter test` (los binarios de sqlite3_flutter_libs solo se enlazan
/// en builds de app, no en el VM target de tests). Gotcha histórico de dogear.
///
/// Llamar UNA vez desde `setUpAll` de cualquier test que abra drift en memoria:
///
///   setUpAll(initSqliteOverride);
void initSqliteOverride() {
  if (Platform.isLinux) {
    open.overrideFor(
      OperatingSystem.linux,
      () => DynamicLibrary.open('libsqlite3.so.0'),
    );
  }
}
