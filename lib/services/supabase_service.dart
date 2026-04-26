import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:drift/drift.dart' as drift;
import '../database/database.dart' as db;
import '../main.dart';

/// Supabase 클라이언트의 싱글턴 참조
final _sb = Supabase.instance.client;

class SupabaseService {
  // ── Auth ─────────────────────────────────────────────────

  static User? get currentUser => _sb.auth.currentUser;
  static bool get isLoggedIn => currentUser != null;

  /// Auth 상태 변경 스트림 (User? 형태로 emit)
  static Stream<User?> get userStream =>
      _sb.auth.onAuthStateChange.map((e) => e.session?.user);

  /// Google 로그인
  static Future<bool> signInWithGoogle() async {
    try {
      final googleSignIn = GoogleSignIn(
        serverClientId: '272114756088-4j0rm5a830nmjq17i8ss62c8iufpg7am.apps.googleusercontent.com',
        scopes: ['email', 'profile'],
      );
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        print('❌ googleUser is null (사용자가 취소했거나 계정 선택 실패)');
        return false;
      }

      final googleAuth = await googleUser.authentication;
      print('✅ idToken: ${googleAuth.idToken}');
      print('✅ accessToken: ${googleAuth.accessToken}');

      if (googleAuth.idToken == null) {
        print('❌ idToken is null - serverClientId 확인 필요');
        return false;
      }

      await _sb.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: googleAuth.idToken!,
        accessToken: googleAuth.accessToken,
      );
      return true;
    } catch (e, stack) {
      print('❌ signInWithGoogle 에러: $e');
      print(stack);
      return false; // ← 여기서 에러 메시지를 위로 던져야 함
    }
  }

  /// 로그아웃
  static Future<void> signOut() async {
    await GoogleSignIn().signOut();
    await _sb.auth.signOut();
  }

  // ── Incremental Sync: Local → Cloud ──────────────────────

  static Future<void> upsertSong(db.LibrarySong song) async {
    if (!isLoggedIn) return;
    try {
      await _sb.from('library_songs').upsert({
        'id': song.id,
        'user_id': currentUser!.id,
        'title': song.title,
        'original_singer': song.originalSinger,
        'song_number': song.songNumber,
        'machine_brand': song.machineBrand,
        'highest_note': song.highestNote,
        'is_highlighted': song.isHighlighted,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  static Future<void> deleteSong(String id) async {
    if (!isLoggedIn) return;
    try {
      await _sb.from('library_songs').delete()
          .eq('id', id)
          .eq('user_id', currentUser!.id);
    } catch (_) {}
  }

  static Future<void> updateSongHighlight(String id, bool isHighlighted) async {
    if (!isLoggedIn) return;
    try {
      await _sb.from('library_songs').update({
        'is_highlighted': isHighlighted,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id).eq('user_id', currentUser!.id);
    } catch (_) {}
  }

  static Future<void> upsertSession(db.Session session) async {
    if (!isLoggedIn) return;
    try {
      await _sb.from('sessions').upsert({
        'id': session.id,
        'user_id': currentUser!.id,
        'date': session.date.toIso8601String(),
        'title': session.title,
        'rating': session.rating,
        'memo': session.memo,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  static Future<void> deleteSessionAndEntries(String sessionId) async {
    if (!isLoggedIn) return;
    try {
      await _sb.from('session_entries').delete()
          .eq('session_id', sessionId)
          .eq('user_id', currentUser!.id);
      await _sb.from('sessions').delete()
          .eq('id', sessionId)
          .eq('user_id', currentUser!.id);
    } catch (_) {}
  }

  static Future<void> upsertSessionEntry(db.SessionEntry entry) async {
    if (!isLoggedIn) return;
    try {
      await _sb.from('session_entries').upsert({
        'id': entry.id,
        'user_id': currentUser!.id,
        'session_id': entry.sessionId,
        'library_song_id': entry.librarySongId,
        'performer': entry.performer,
        'sort_order': entry.sortOrder,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  static Future<void> deleteSessionEntry(String id) async {
    if (!isLoggedIn) return;
    try {
      await _sb.from('session_entries').delete()
          .eq('id', id)
          .eq('user_id', currentUser!.id);
    } catch (_) {}
  }

  static Future<void> updateEntryPerformer(String id, String performer) async {
    if (!isLoggedIn) return;
    try {
      await _sb.from('session_entries').update({
        'performer': performer,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id).eq('user_id', currentUser!.id);
    } catch (_) {}
  }

  static Future<void> updateEntryOrder(String id, int sortOrder) async {
    if (!isLoggedIn) return;
    try {
      await _sb.from('session_entries').update({
        'sort_order': sortOrder,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id).eq('user_id', currentUser!.id);
    } catch (_) {}
  }

  static Future<void> upsertPerformer(db.Performer performer) async {
    if (!isLoggedIn) return;
    try {
      await _sb.from('performers').upsert({
        'id': performer.id,
        'user_id': currentUser!.id,
        'name': performer.name,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  static Future<void> deletePerformer(String id) async {
    if (!isLoggedIn) return;
    try {
      await _sb.from('performers').delete()
          .eq('id', id)
          .eq('user_id', currentUser!.id);
    } catch (_) {}
  }

  static Future<void> clearPerformerNameFromEntries(String name) async {
    if (!isLoggedIn) return;
    try {
      await _sb.from('session_entries').update({
        'performer': '',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('performer', name).eq('user_id', currentUser!.id);
    } catch (_) {}
  }

  // ── Full Sync: Cloud → Local (로그인 시 호출) ─────────────

  /// 클라우드 데이터를 로컬로 완전히 덮어씀.
  /// 로컬에 데이터가 있고 클라우드가 비어있으면 로컬을 올림.
  static Future<void> syncOnLogin() async {
    if (!isLoggedIn) return;
    final uid = currentUser!.id;

    // 클라우드에 데이터가 있는지 확인
    final cloudSongsCount = await _sb
        .from('library_songs')
        .select('id')
        .eq('user_id', uid);

    if ((cloudSongsCount as List).isNotEmpty) {
      // 클라우드 → 로컬
      await pullFromCloud();
    } else {
      // 로컬 → 클라우드 (첫 연동)
      await pushAllToCloud();
    }
  }

  /// 클라우드의 모든 데이터를 로컬 DB에 덮어씀
  static Future<void> pullFromCloud() async {
    if (!isLoggedIn) return;
    final uid = currentUser!.id;

    await database.clearAllData();

    // Songs
    final songs = await _sb.from('library_songs').select().eq('user_id', uid);
    for (final s in songs as List) {
      await database.insertLibrarySong(db.LibrarySongsCompanion.insert(
        id: s['id'] as String,
        title: s['title'] as String,
        originalSinger: s['original_singer'] as String,
        songNumber: s['song_number'] as String,
        machineBrand: s['machine_brand'] as String,
        highestNote: s['highest_note'] as String,
        isHighlighted: drift.Value(s['is_highlighted'] as bool? ?? false),
      ));
    }

    // Sessions
    final sessions = await _sb.from('sessions').select().eq('user_id', uid);
    for (final s in sessions as List) {
      await database.insertSession(db.SessionsCompanion.insert(
        id: s['id'] as String,
        date: DateTime.parse(s['date'] as String),
        title: drift.Value(s['title'] as String? ?? ''),
        rating: drift.Value(s['rating'] as int? ?? 0),
        memo: drift.Value(s['memo'] as String? ?? ''),
      ));
    }

    // Session Entries
    final entries = await _sb.from('session_entries').select().eq('user_id', uid);
    for (final e in entries as List) {
      await database.insertSessionEntry(db.SessionEntriesCompanion.insert(
        id: e['id'] as String,
        sessionId: e['session_id'] as String,
        librarySongId: e['library_song_id'] as String,
        performer: drift.Value(e['performer'] as String? ?? ''),
        sortOrder: drift.Value(e['sort_order'] as int? ?? 0),
      ));
    }

    // Performers
    final performers = await _sb.from('performers').select().eq('user_id', uid);
    for (final p in performers as List) {
      await database.insertPerformer(db.PerformersCompanion.insert(
        id: p['id'] as String,
        name: p['name'] as String,
      ));
    }
  }

  /// 로컬의 모든 데이터를 클라우드에 올림 (첫 연동 또는 강제 업로드)
  static Future<void> pushAllToCloud() async {
    if (!isLoggedIn) return;
    final uid = currentUser!.id;

    // 기존 클라우드 데이터 삭제 후 재업로드
    await _sb.from('session_entries').delete().eq('user_id', uid);
    await _sb.from('sessions').delete().eq('user_id', uid);
    await _sb.from('library_songs').delete().eq('user_id', uid);
    await _sb.from('performers').delete().eq('user_id', uid);

    final now = DateTime.now().toIso8601String();

    final songs = await database.getAllLibrarySongs();
    if (songs.isNotEmpty) {
      await _sb.from('library_songs').insert(songs.map((s) => {
        'id': s.id,
        'user_id': uid,
        'title': s.title,
        'original_singer': s.originalSinger,
        'song_number': s.songNumber,
        'machine_brand': s.machineBrand,
        'highest_note': s.highestNote,
        'is_highlighted': s.isHighlighted,
        'updated_at': now,
      }).toList());
    }

    final sessions = await database.getAllSessions();
    if (sessions.isNotEmpty) {
      await _sb.from('sessions').insert(sessions.map((s) => {
        'id': s.id,
        'user_id': uid,
        'date': s.date.toIso8601String(),
        'title': s.title,
        'rating': s.rating,
        'memo': s.memo,
        'updated_at': now,
      }).toList());
    }

    final entries = await database.getAllSessionEntries();
    if (entries.isNotEmpty) {
      await _sb.from('session_entries').insert(entries.map((e) => {
        'id': e.id,
        'user_id': uid,
        'session_id': e.sessionId,
        'library_song_id': e.librarySongId,
        'performer': e.performer,
        'sort_order': e.sortOrder,
        'updated_at': now,
      }).toList());
    }

    final performers = await database.getAllPerformers();
    if (performers.isNotEmpty) {
      await _sb.from('performers').insert(performers.map((p) => {
        'id': p.id,
        'user_id': uid,
        'name': p.name,
        'updated_at': now,
      }).toList());
    }
  }
}