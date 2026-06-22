import 'dart:async';

import 'package:drift/drift.dart';
import 'package:fincore/data/database.dart';

/// Calcula saldos derivados (BO, DE, CR, saldo por cuenta) sobre la marcha.
/// Usa drift streams: el StreamBuilder solo recibe nuevos valores cuando
/// cambia el contenido de accounts o journal_entries (drift detecta el `readsFrom`).
///
/// Índices en journal_entries (account_origin_id, account_destination_id, deleted_at)
/// garantizan que las SUM agregadas corren en milisegundos incluso con 50k+ entries.
class FinancialStateService {
  final FincoreDatabase _db;
  FinancialStateService(this._db);

  /// Cache de streams por cuenta (RF-012 del sprint flutter-local-hardening).
  ///
  /// El Dashboard rendera un `_BalanceLabel` por cada cuenta activa. Sin cache,
  /// cada `_BalanceLabel` crea un `customSelect(...).watchSingle()` nuevo:
  /// con 10 cuentas son 10 streams idénticos suscritos al mismo `readsFrom`.
  /// El cache hace que múltiples suscriptores compartan el mismo Stream y
  /// drift coalesces la query subyacente.
  ///
  /// Key formato: `'$accountId:$accountType'`. Se invalida en dos eventos:
  /// - `archive(id)` de una cuenta → `invalidateAccount(id)` borra las keys.
  /// - `wipeAll()` → `invalidateAll()` vacía el Map.
  ///
  /// Convención (L2-H4 quality review v3): la key incluye `accountType` y
  /// `invalidateAccount` asume que el `type` de una cuenta es inmutable
  /// post-creación. Hoy `AccountsDao.updateAccount` no permite cambiar el
  /// `type` (campo protected), así que el invariante se cumple. Si en el
  /// futuro se habilita el cambio de tipo, agregar lógica explícita de
  /// invalidación cruzada de keys.
  final Map<String, _ReplayBalanceStream> _balanceCache = {};

  /// Caches lazy para los streams agregados (BO/DE/CR). RF-007 del sprint
  /// flutter-local-hardening-v4 + L2-H1 del quality review v3: `watchBo`,
  /// `watchDe`, `watchCr` también necesitan replay-1 para no caer en el
  /// patrón "Skeleton eterno" si el Dashboard se desmonta con un evento del
  /// stream en vuelo (escenario típico: `context.go('/dashboard')` que
  /// resetea el stack desde una pantalla de reportes futura).
  _ReplayBalanceStream? _boCache;
  _ReplayBalanceStream? _deCache;
  _ReplayBalanceStream? _crCache;

  /// Saldo derivado de una cuenta específica.
  ///
  /// - cash/debit: saldo = Σ destination − Σ origin (intuitivo: ingreso suma, gasto resta).
  /// - credit:     saldo = Σ origin − Σ destination (deuda actual; cargos suben, pagos bajan).
  Stream<double> watchAccountBalance(String accountId, String accountType) {
    final key = '$accountId:$accountType';
    final cached = _balanceCache[key];
    if (cached != null) return cached.stream;
    final isCredit = accountType == 'credit';
    final sql = isCredit
        ? 'SELECT COALESCE(SUM(CASE WHEN account_origin_id = ? THEN amount ELSE 0 END), 0) '
            '- COALESCE(SUM(CASE WHEN account_destination_id = ? THEN amount ELSE 0 END), 0) AS balance '
            'FROM journal_entries WHERE deleted_at IS NULL'
        : 'SELECT COALESCE(SUM(CASE WHEN account_destination_id = ? THEN amount ELSE 0 END), 0) '
            '- COALESCE(SUM(CASE WHEN account_origin_id = ? THEN amount ELSE 0 END), 0) AS balance '
            'FROM journal_entries WHERE deleted_at IS NULL';
    // Hotfix post-smoke (bug "vista en gris" al volver al Dashboard tras
    // cancelar un movimiento): `.asBroadcastStream()` simple NO replay el
    // último valor a un listener nuevo. Al desmontar el Dashboard durante
    // el `entry_form_screen`, el evento del cancel se emite con cero
    // listeners; al volver, el `StreamBuilder` se re-suscribe pero el
    // broadcast no le entrega el valor más reciente y queda en `Skeleton`
    // hasta el próximo cambio en `journal_entries`. `_ReplayBalanceStream`
    // implementa replay-1 con `StreamController.broadcast` propio: guarda
    // el último valor emitido por drift y lo re-emite en `onListen`.
    final source = _db
        .customSelect(
          sql,
          variables: [Variable.withString(accountId), Variable.withString(accountId)],
          readsFrom: {_db.journalEntries},
        )
        .map((row) => row.read<double>('balance'))
        .watchSingle();
    final entry = _ReplayBalanceStream(source);
    _balanceCache[key] = entry;
    return entry.stream;
  }

  /// Limpia todas las entradas del cache asociadas a una cuenta específica.
  /// Llamada desde `AccountsDao.archive(id)` para liberar referencias al stream
  /// de una cuenta que dejó de aparecer en el listado activo.
  void invalidateAccount(String accountId) {
    final keysToRemove = _balanceCache.keys
        .where((key) => key.startsWith('$accountId:'))
        .toList();
    for (final key in keysToRemove) {
      _balanceCache.remove(key)?.dispose();
    }
  }

  /// Limpia todo el cache. Llamada desde `BackupService.wipeAll()` cuando se
  /// resetea la cuenta del usuario o se importa un respaldo (reemplazo total).
  void invalidateAll() {
    for (final entry in _balanceCache.values) {
      entry.dispose();
    }
    _balanceCache.clear();
    // RF-008 v4: liberar también los caches agregados (BO/DE/CR). Tras un
    // wipeAll/import, los datos del usuario cambian completamente: el
    // próximo `watchBo()` etc. arma streams nuevos sin valores residuales.
    _boCache?.dispose();
    _boCache = null;
    _deCache?.dispose();
    _deCache = null;
    _crCache?.dispose();
    _crCache = null;
  }

  /// Versión sincrónica para validaciones (ej. archive con saldo != 0).
  /// Wrapper del helper top-level [accountBalanceAtomic] preservado por
  /// compatibilidad de API: los tests existentes y otros callers siguen
  /// usando `state.accountBalanceNow(id)` sin cambios.
  Future<double> accountBalanceNow(String accountId) =>
      accountBalanceAtomic(_db, accountId);

  /// BO = Σ saldo de cuentas (cash + debit) activas.
  /// Wrappeado en `_ReplayBalanceStream` (RF-007 v4) para replay-1.
  Stream<double> watchBo() {
    return (_boCache ??= _ReplayBalanceStream(_buildBoSource())).stream;
  }

  Stream<double> _buildBoSource() {
    const sql = '''
      SELECT COALESCE(SUM(saldo), 0) AS total FROM (
        SELECT a.id,
          (COALESCE((SELECT SUM(amount) FROM journal_entries
                     WHERE account_destination_id = a.id AND deleted_at IS NULL), 0)
          - COALESCE((SELECT SUM(amount) FROM journal_entries
                     WHERE account_origin_id = a.id AND deleted_at IS NULL), 0)) AS saldo
        FROM accounts a
        WHERE a.deleted_at IS NULL AND a.type IN ('cash', 'debit')
      )
    ''';
    return _db
        .customSelect(sql, readsFrom: {_db.accounts, _db.journalEntries})
        .map((row) => row.read<double>('total'))
        .watchSingle();
  }

  /// DE = Σ deuda de cuentas credit activas.
  Stream<double> watchDe() {
    return (_deCache ??= _ReplayBalanceStream(_buildDeSource())).stream;
  }

  Stream<double> _buildDeSource() {
    const sql = '''
      SELECT COALESCE(SUM(deuda), 0) AS total FROM (
        SELECT a.id,
          (COALESCE((SELECT SUM(amount) FROM journal_entries
                     WHERE account_origin_id = a.id AND deleted_at IS NULL), 0)
          - COALESCE((SELECT SUM(amount) FROM journal_entries
                     WHERE account_destination_id = a.id AND deleted_at IS NULL), 0)) AS deuda
        FROM accounts a
        WHERE a.deleted_at IS NULL AND a.type = 'credit'
      )
    ''';
    return _db
        .customSelect(sql, readsFrom: {_db.accounts, _db.journalEntries})
        .map((row) => row.read<double>('total'))
        .watchSingle();
  }

  /// CR = Σ (credit_limit − deuda) para cuentas credit activas con credit_limit set.
  Stream<double> watchCr() {
    return (_crCache ??= _ReplayBalanceStream(_buildCrSource())).stream;
  }

  Stream<double> _buildCrSource() {
    const sql = '''
      SELECT COALESCE(SUM(libre), 0) AS total FROM (
        SELECT a.id,
          (a.credit_limit
          - (COALESCE((SELECT SUM(amount) FROM journal_entries
                       WHERE account_origin_id = a.id AND deleted_at IS NULL), 0)
            - COALESCE((SELECT SUM(amount) FROM journal_entries
                       WHERE account_destination_id = a.id AND deleted_at IS NULL), 0))) AS libre
        FROM accounts a
        WHERE a.deleted_at IS NULL AND a.type = 'credit' AND a.credit_limit IS NOT NULL
      )
    ''';
    return _db
        .customSelect(sql, readsFrom: {_db.accounts, _db.journalEntries})
        .map((row) => row.read<double>('total'))
        .watchSingle();
  }
}

/// Calcula el balance de una cuenta de forma sincrónica, sin tocar el cache
/// de streams. Pura sobre el database: dos callers la usan sin compartir estado:
///
/// 1. [FinancialStateService.accountBalanceNow] — wrapper para callers que ya
///    tienen el `state` inyectado (Settings, archive, tests).
/// 2. [EntriesDao.registerDebtPayment] — chequea OverpayDebt dentro de la
///    transacción del insert. Necesitaba `FinancialStateService` solo para
///    esto; extraer la función permitió quitar el field `_state` del DAO
///    (RF-001 a RF-003 del sprint flutter-local-hardening-v4) y registrarlo
///    en `@DriftDatabase(daos: [...])`.
///
/// Reglas idénticas a `watchAccountBalance`:
/// - cuenta no encontrada o archivada → 0.
/// - cash/debit: Σ destination − Σ origin.
/// - credit: Σ origin − Σ destination (deuda).
Future<double> accountBalanceAtomic(
  GeneratedDatabase db,
  String accountId,
) async {
  // B1 quality review v4: filtrar `deleted_at IS NULL` para que una cuenta
  // archivada retorne 0 (consistente con `watchAccountBalance` y la decisión
  // del MVP: cuentas archivadas no aparecen en balance). Hoy no hay caller
  // que ataque cuentas archivadas (EntriesDao valida tipo antes), pero el
  // guard preventivo blinda futuras integraciones.
  final accountRow = await db
      .customSelect(
        'SELECT type FROM accounts WHERE id = ? AND deleted_at IS NULL LIMIT 1',
        variables: [Variable.withString(accountId)],
      )
      .getSingleOrNull();
  if (accountRow == null) return 0;
  final type = accountRow.read<String>('type');
  final isCredit = type == 'credit';
  final sql = isCredit
      ? 'SELECT COALESCE(SUM(CASE WHEN account_origin_id = ? THEN amount ELSE 0 END), 0) '
          '- COALESCE(SUM(CASE WHEN account_destination_id = ? THEN amount ELSE 0 END), 0) AS balance '
          'FROM journal_entries WHERE deleted_at IS NULL'
      : 'SELECT COALESCE(SUM(CASE WHEN account_destination_id = ? THEN amount ELSE 0 END), 0) '
          '- COALESCE(SUM(CASE WHEN account_origin_id = ? THEN amount ELSE 0 END), 0) AS balance '
          'FROM journal_entries WHERE deleted_at IS NULL';
  final row = await db
      .customSelect(
        sql,
        variables: [
          Variable.withString(accountId),
          Variable.withString(accountId),
        ],
      )
      .getSingle();
  return row.read<double>('balance');
}

/// Cache de stream replay-1: envuelve un `customSelect.watchSingle()` (single
/// listener) en un stream multi-suscriptor propio (`Stream.multi`) que
/// recuerda el último valor emitido por drift y se lo entrega de inmediato a
/// cada nuevo suscriptor, independientemente de cuántos otros listeners ya
/// estén activos.
///
/// Por qué `Stream.multi` y no `StreamController.broadcast`:
/// `StreamController.broadcast.onListen` solo se invoca cuando el primer
/// listener llega tras un período de cero listeners. Si el Dashboard ya está
/// suscrito y el `AccountBalanceHint` del form se suscribe encima, el callback
/// de replay nunca se ejecuta para el segundo listener y queda esperando el
/// próximo cambio en `journal_entries` (Skeleton eterno). `Stream.multi`
/// invoca su callback por cada `.listen()`, lo que permite hacer replay
/// individualizado.
///
/// Ciclo de vida:
/// - `_upstreamSub` lazy: se crea con la primera suscripción downstream y se
///   mantiene viva mientras la entrada del cache exista.
/// - `dispose()` cancela el upstream y cierra los `MultiStreamController` de
///   todos los listeners activos. Lo invocan `invalidateAccount(id)` y
///   `invalidateAll()` para liberar recursos.
/// - Por diseño NO se cierra al perder el último listener: el cache de
///   `FinancialStateService` mantiene la entrada viva hasta una invalidación
///   explícita, así que reutilizar `watchAccountBalance(...)` después sigue
///   retornando el último valor.
class _ReplayBalanceStream {
  final Stream<double> _source;
  // Cacheamos `stream` para preservar identidad referencial: los tests del
  // sprint anterior (cache de streams) se apoyan en `identical(s1, s2)`.
  late final Stream<double> stream;
  final Set<MultiStreamController<double>> _listeners = {};
  StreamSubscription<double>? _upstreamSub;
  double? _last;
  bool _disposed = false;

  _ReplayBalanceStream(this._source) {
    stream = Stream<double>.multi(_handleListen, isBroadcast: true);
  }

  void _handleListen(MultiStreamController<double> controller) {
    if (_disposed) {
      controller.closeSync();
      return;
    }
    _ensureUpstream();
    _listeners.add(controller);
    final last = _last;
    if (last != null) {
      controller.addSync(last);
    }
    controller.onCancel = () {
      _listeners.remove(controller);
    };
  }

  void _ensureUpstream() {
    _upstreamSub ??= _source.listen((value) {
      _last = value;
      // Forward del valor a todos los listeners activos. Iterar sobre una
      // copia por si algún listener cancela durante el dispatch.
      //
      // RF-014 v4 evaluado y descartado: agregar guard `if (!hasListener)`
      // causa que tests pumpAndSettle se cuelguen porque `hasListener`
      // retorna false transitivamente durante la inicialización del
      // controller en `Stream.multi`. El L2-H3 era riesgo teórico sin
      // reporte; el comportamiento actual con `onCancel` ya saca controllers
      // cancelados del Set. La protección queda diferida hasta que aparezca
      // un caso real reproducible.
      for (final controller in _listeners.toList()) {
        controller.addSync(value);
      }
    });
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _upstreamSub?.cancel();
    _upstreamSub = null;
    for (final controller in _listeners.toList()) {
      controller.closeSync();
    }
    _listeners.clear();
  }
}
