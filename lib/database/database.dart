import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

class LibrarySongs extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get originalSinger => text()();
  TextColumn get songNumber => text()();
  TextColumn get machineBrand => text()();
  TextColumn get highestNote => text()();
  BoolColumn get isHighlighted => boolean().withDefault(const Constant(false))();
  @override
  Set<Column> get primaryKey => {id};
}

class Sessions extends Table {
  TextColumn get id => text()();
  DateTimeColumn get date => dateTime()();
  TextColumn get title => text().withDefault(const Constant(''))();
  IntColumn get rating => integer().withDefault(const Constant(0))();
  TextColumn get memo => text().withDefault(const Constant(''))();
  @override
  Set<Column> get primaryKey => {id};
}

class SessionEntries extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId => text()();
  TextColumn get librarySongId => text()();
  TextColumn get performer => text().withDefault(const Constant(''))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  @override
  Set<Column> get primaryKey => {id};
}

class Performers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [LibrarySongs, Sessions, SessionEntries, Performers])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 8;

  // ── LibrarySongs ──────────────────────────────────────────
  Future<int> insertLibrarySong(LibrarySongsCompanion entry) =>
      into(librarySongs).insert(entry, mode: InsertMode.insertOrReplace);

  Future<List<LibrarySong>> getAllLibrarySongs() =>
      (select(librarySongs)..orderBy([(t) => OrderingTerm(expression: t.title)])).get();

  Future<bool> updateLibrarySong(LibrarySong song) =>
      update(librarySongs).replace(song);

  Future<int> deleteLibrarySong(String id) =>
      (delete(librarySongs)..where((t) => t.id.equals(id))).go();

  Future<void> updateSongHighlight(String id, bool value) =>
      (update(librarySongs)..where((t) => t.id.equals(id)))
          .write(LibrarySongsCompanion(isHighlighted: Value(value)));

  // ── Sessions ──────────────────────────────────────────────
  Future<int> insertSession(SessionsCompanion entry) =>
      into(sessions).insert(entry, mode: InsertMode.insertOrReplace);

  Future<List<Session>> getAllSessions() =>
      (select(sessions)..orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)])).get();

  Future<bool> updateSession(Session session) =>
      update(sessions).replace(session);

  /// 트랜잭션으로 세션 엔트리와 세션을 함께 삭제 (원자성 보장)
  Future<int> deleteSession(String sessionId) => transaction(() async {
    await (delete(sessionEntries)..where((t) => t.sessionId.equals(sessionId))).go();
    return (delete(sessions)..where((t) => t.id.equals(sessionId))).go();
  });

  // ── SessionEntries ────────────────────────────────────────
  Future<int> insertSessionEntry(SessionEntriesCompanion entry) =>
      into(sessionEntries).insert(entry, mode: InsertMode.insertOrReplace);

  Future<List<SessionEntry>> getAllSessionEntries() =>
      select(sessionEntries).get();

  Future<int> deleteSessionEntry(String id) =>
      (delete(sessionEntries)..where((t) => t.id.equals(id))).go();

  Future<void> updateEntryOrder(String id, int order) =>
      (update(sessionEntries)..where((t) => t.id.equals(id)))
          .write(SessionEntriesCompanion(sortOrder: Value(order)));

  Future<void> updateEntryPerformer(String id, String name) =>
      (update(sessionEntries)..where((t) => t.id.equals(id)))
          .write(SessionEntriesCompanion(performer: Value(name)));

  Future<void> clearPerformerNameFromEntries(String name) =>
      (update(sessionEntries)..where((t) => t.performer.equals(name)))
          .write(const SessionEntriesCompanion(performer: Value('')));

  // ── Performers ────────────────────────────────────────────
  Future<int> insertPerformer(PerformersCompanion entry) =>
      into(performers).insert(entry, mode: InsertMode.insertOrReplace);

  Future<List<Performer>> getAllPerformers() =>
      (select(performers)..orderBy([(t) => OrderingTerm(expression: t.name)])).get();

  Future<int> deletePerformer(String id) =>
      (delete(performers)..where((t) => t.id.equals(id))).go();

  // ── 전체 초기화 ───────────────────────────────────────────
  /// 트랜잭션으로 모든 테이블을 한꺼번에 초기화 (원자성 보장)
  Future<void> clearAllData() => transaction(() async {
    await delete(sessionEntries).go();
    await delete(sessions).go();
    await delete(librarySongs).go();
    await delete(performers).go();
  });

  // ── 조인 쿼리 ─────────────────────────────────────────────
  Selectable<TypedResult> getSessionWithSongs(String sId) {
    return (select(sessionEntries).join([
      innerJoin(librarySongs, librarySongs.id.equalsExp(sessionEntries.librarySongId)),
    ]))
      ..where(sessionEntries.sessionId.equals(sId))
      ..orderBy([OrderingTerm.asc(sessionEntries.sortOrder)]);
  }

  Selectable<TypedResult> getAllEntriesWithSongs() {
    return select(sessionEntries).join([
      innerJoin(librarySongs, librarySongs.id.equalsExp(sessionEntries.librarySongId)),
    ]);
  }

  /// 특정 performer가 노래한 세션 날짜 목록 (중복 제거, 최신순)
  Future<List<DateTime>> getSessionDatesByPerformer(String name) async {
    final query = selectOnly(sessions).join([
      innerJoin(sessionEntries, sessionEntries.sessionId.equalsExp(sessions.id)),
    ])
      ..where(sessionEntries.performer.equals(name))
      ..addColumns([sessions.date])
      ..groupBy([sessions.id])
      ..orderBy([OrderingTerm.desc(sessions.date)]);

    final results = await query.get();
    return results.map((row) => row.read(sessions.date)!).toList();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'db.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}