import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../viewmodels/karaoke_view_model.dart';
import '../../viewmodels/ui_state.dart';
import '../../database/database.dart';
import '../performer_screen.dart';
import '../song_ranking_screen.dart';
import '../course_generator_screen.dart';

class ExtraTab extends ConsumerStatefulWidget {
  const ExtraTab({super.key});
  @override
  ConsumerState<ExtraTab> createState() => _ExtraTabState();
}

class _ExtraTabState extends ConsumerState<ExtraTab> {
  LibrarySong? _recommendedSong;

  void _recommendSong(List<LibrarySong> songs, String targetBrand) {
    List<LibrarySong> filteredSongs = songs.where((s) => s.machineBrand == targetBrand).toList();
    if (filteredSongs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$targetBrand 노래가 하나도 없잖아! 좀 등록하고 눌러!'))
      );
      return;
    }
    filteredSongs.shuffle();
    setState(() {
      _recommendedSong = filteredSongs.first;
    });
  }

  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final current = ref.read(appThemeModeProvider);
        return AlertDialog(
          title: const Text('테마 설정'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<ThemeMode>(
                title: const Text('라이트 모드'),
                secondary: const Icon(Icons.light_mode),
                value: ThemeMode.light,
                groupValue: current,
                onChanged: (v) {
                  ref.read(appThemeModeProvider.notifier).setTheme(v!);
                  Navigator.pop(context);
                },
              ),
              RadioListTile<ThemeMode>(
                title: const Text('다크 모드'),
                secondary: const Icon(Icons.dark_mode),
                value: ThemeMode.dark,
                groupValue: current,
                onChanged: (v) {
                  ref.read(appThemeModeProvider.notifier).setTheme(v!);
                  Navigator.pop(context);
                },
              ),
              RadioListTile<ThemeMode>(
                title: const Text('시스템 설정 따르기'),
                secondary: const Icon(Icons.settings_suggest),
                value: ThemeMode.system,
                groupValue: current,
                onChanged: (v) {
                  ref.read(appThemeModeProvider.notifier).setTheme(v!);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final libraryAsync = ref.watch(libraryViewModelProvider);
    final recommendBrand = ref.watch(recommendBrandProvider);
    final themeMode = ref.watch(appThemeModeProvider);

    String themeModeLabel() {
      switch (themeMode) {
        case ThemeMode.light: return '라이트 모드';
        case ThemeMode.dark: return '다크 모드';
        case ThemeMode.system: return '시스템 설정';
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('부가 정보'), centerTitle: true),
      body: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text('노래를 부른 사람 관리'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PerformerScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.leaderboard),
            title: const Text('가장 많이 부른 노래 순위'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SongRankingScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.auto_awesome),
            title: const Text('랜덤 노래 코스 생성기'),
            subtitle: const Text('오늘 부를 노래 리스트를 한꺼번에 짜줄게!'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CourseGeneratorScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.palette),
            title: const Text('테마 설정'),
            subtitle: Text(themeModeLabel()),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showThemeDialog,
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(child: ElevatedButton.icon(onPressed: () => ref.read(dataManagementViewModelProvider.notifier).exportData(), icon: const Icon(Icons.upload_file), label: const Text('백업 파일 만들기'))),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton.icon(onPressed: () async {
                  bool success = await ref.read(dataManagementViewModelProvider.notifier).importData();
                  if (success && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('데이터 복원 성공!')));
                }, icon: const Icon(Icons.file_open), label: const Text('백업 불러오기'))),
              ],
            ),
          ),
          const Spacer(),
          if (_recommendedSong != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('추천 노래', style: TextStyle(fontSize: 12, color: Colors.indigo, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(_recommendedSong!.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      Text(_recommendedSong!.originalSinger, style: const TextStyle(fontSize: 14, color: Colors.blueGrey)),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('번호: ${_recommendedSong!.songNumber} (${_recommendedSong!.machineBrand})', style: const TextStyle(fontSize: 13)),
                          Text(_recommendedSong!.highestNote, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('TJ', style: TextStyle(fontSize: 12)),
                  Checkbox(
                    visualDensity: VisualDensity.compact,
                    value: recommendBrand == 'TJ',
                    onChanged: (v) { if (v == true) ref.read(recommendBrandProvider.notifier).setBrand('TJ'); },
                  ),
                  const SizedBox(width: 8),
                  const Text('금영', style: TextStyle(fontSize: 12)),
                  Checkbox(
                    visualDensity: VisualDensity.compact,
                    value: recommendBrand == 'KY',
                    onChanged: (v) { if (v == true) ref.read(recommendBrandProvider.notifier).setBrand('KY'); },
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  libraryAsync.whenData((songs) => _recommendSong(songs, recommendBrand));
                },
                icon: const Icon(Icons.casino),
                label: const Text('오늘 뭐 부르지? 랜덤 추천!'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}