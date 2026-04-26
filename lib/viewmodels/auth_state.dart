import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

/// 현재 로그인된 User? 를 실시간으로 제공하는 스트림 프로바이더
final authUserProvider = StreamProvider<User?>((ref) {
  return SupabaseService.userStream;
});

/// 동기화 중 여부 상태 (UI 로딩 표시용)
final syncLoadingProvider = StateProvider<bool>((ref) => false);