import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../viewmodels/karaoke_view_model.dart';
import '../../viewmodels/ui_state.dart';
import '../../database/database.dart';

class AddSongTab extends ConsumerStatefulWidget {
  const AddSongTab({super.key});
  @override
  ConsumerState<AddSongTab> createState() => _AddSongTabState();
}

bool _showOnlyHighlighted = false;
class _AddSongTabState extends ConsumerState<AddSongTab> {
  final List<String> _notes = ['~2옥타브 솔#', '2옥타브 라~시', '3옥타브 도~'];

  Color _getNoteColor(String note) {
    if (note == _notes[0]) return Colors.green;
    if (note == _notes[1]) return Colors.blue;
    if (note == _notes[2]) return Colors.red;
    return Colors.black;
  }

  Color _getBrandColor(String brand) {
    return brand == 'TJ' ? Colors.purple : Colors.orange;
  }

  int _compareTitles(String a, String b) {
    bool isAHangul = RegExp(r'^[가-힣]').hasMatch(a);
    bool isBHangul = RegExp(r'^[가-힣]').hasMatch(b);

    if (isAHangul && !isBHangul) return -1;
    if (!isAHangul && isBHangul) return 1;
    return a.toLowerCase().compareTo(b.toLowerCase());
  }

  void _showAddDialog() {
    final tCtrl = TextEditingController();
    final sCtrl = TextEditingController();
    final nCtrl = TextEditingController();
    String bVal = ref.read(selectedBrandProvider);
    String noteVal = _notes[0];
    String? tErr, sErr;
    bool isDup = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setST) {
          void validate() {
            final songs = ref.read(libraryViewModelProvider).value ?? [];
            final dup = songs.any((s) =>
            s.title == tCtrl.text &&
                s.originalSinger == sCtrl.text &&
                s.songNumber == nCtrl.text &&
                s.machineBrand == bVal &&
                s.highestNote == noteVal);
            setST(() {
              isDup = dup;
              tErr = null;
              sErr = null;
            });
          }

          return AlertDialog(
            title: const Text('새 노래 등록', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('TJ', style: TextStyle(color: _getBrandColor('TJ'), fontWeight: FontWeight.bold)),
                      Checkbox(value: bVal == 'TJ', onChanged: (v) { setST(() => bVal = 'TJ'); validate(); }),
                      const SizedBox(width: 15),
                      Text('금영', style: TextStyle(color: _getBrandColor('KY'), fontWeight: FontWeight.bold)),
                      Checkbox(value: bVal == 'KY', onChanged: (v) { setST(() => bVal = 'KY'); validate(); }),
                    ],
                  ),
                  TextField(
                    controller: tCtrl,
                    onChanged: (_) => validate(),
                    decoration: InputDecoration(labelText: '노래 제목 *', isDense: true, errorText: tErr),
                  ),
                  TextField(
                    controller: sCtrl,
                    onChanged: (_) => validate(),
                    decoration: InputDecoration(labelText: '가수 *', isDense: true, errorText: sErr),
                  ),
                  TextField(controller: nCtrl, onChanged: (_) => validate(), decoration: const InputDecoration(labelText: '번호', isDense: true)),
                  DropdownButtonFormField<String>(
                    value: noteVal,
                    items: _notes.map((n) => DropdownMenuItem(value: n, child: Text(n, style: TextStyle(color: _getNoteColor(n))))).toList(),
                    onChanged: (v) { setST(() => noteVal = v!); validate(); },
                    decoration: const InputDecoration(labelText: '최고음 영역', isDense: true),
                  ),
                  if (isDup)
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Text('이미 똑같은 노래가 라이브러리에 있어!', style: TextStyle(color: Colors.red, fontSize: 12)),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
              ElevatedButton(
                onPressed: isDup ? null : () async {
                  if (tCtrl.text.isEmpty) { setST(() => tErr = '제목을 입력해!'); return; }
                  if (sCtrl.text.isEmpty) { setST(() => sErr = '가수를 입력해!'); return; }
                  await ref.read(libraryViewModelProvider.notifier).addSong(
                    title: tCtrl.text,
                    originalSinger: sCtrl.text,
                    songNumber: nCtrl.text,
                    machineBrand: bVal,
                    highestNote: noteVal,
                  );
                  if (mounted) Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: isDup ? Colors.red : null),
                child: Text(isDup ? '중복 불가' : '저장'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDelete(LibrarySong song) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('정말 삭제할 거야?', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Text('"${song.title}"을(를) 삭제하면 이 노래가 포함된 모든 세션의 기록도 함께 사라져! 진짜 지울 거야?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          TextButton(
            onPressed: () {
              ref.read(libraryViewModelProvider.notifier).deleteSongWithUndo(context, song);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('응, 다 지워줘', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(LibrarySong song) {
    final tCtrl = TextEditingController(text: song.title);
    final sCtrl = TextEditingController(text: song.originalSinger);
    final nCtrl = TextEditingController(text: song.songNumber);
    String bVal = song.machineBrand;
    String noteVal = _notes.contains(song.highestNote) ? song.highestNote : _notes[0];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setST) => AlertDialog(
          title: const Text('노래 정보 수정'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: tCtrl, decoration: const InputDecoration(labelText: '제목', isDense: true)),
                TextField(controller: sCtrl, decoration: const InputDecoration(labelText: '가수', isDense: true)),
                TextField(controller: nCtrl, decoration: const InputDecoration(labelText: '번호', isDense: true)),
                DropdownButtonFormField<String>(
                  value: noteVal,
                  items: _notes.map((n) => DropdownMenuItem(value: n, child: Text(n, style: TextStyle(color: _getNoteColor(n))))).toList(),
                  onChanged: (v) => setST(() => noteVal = v!),
                  decoration: const InputDecoration(labelText: '최고음 영역', isDense: true),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('TJ', style: TextStyle(color: _getBrandColor('TJ'), fontWeight: FontWeight.bold)),
                    Checkbox(value: bVal == 'TJ', onChanged: (v) => setST(() => bVal = 'TJ')),
                    const SizedBox(width: 10),
                    Text('금영', style: TextStyle(color: _getBrandColor('KY'), fontWeight: FontWeight.bold)),
                    Checkbox(value: bVal == 'KY', onChanged: (v) => setST(() => bVal = 'KY')),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => _confirmDelete(song), child: const Text('삭제', style: TextStyle(color: Colors.red))),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
            ElevatedButton(
              onPressed: () {
                if (tCtrl.text.isEmpty || sCtrl.text.isEmpty) return;
                ref.read(libraryViewModelProvider.notifier).updateSong(song.copyWith(
                  title: tCtrl.text,
                  originalSinger: sCtrl.text,
                  songNumber: nCtrl.text,
                  machineBrand: bVal,
                  highestNote: noteVal,
                ));
                Navigator.pop(context);
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final libraryAsync = ref.watch(libraryViewModelProvider);
    final isSortByNote = ref.watch(isSortByNoteProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('노래 라이브러리', style: TextStyle(fontSize: 18)),
        actions: [
          Row(
            children: [
              const Text('⭐', style: TextStyle(fontSize: 12)),
              Checkbox(
                visualDensity: VisualDensity.compact,
                value: _showOnlyHighlighted,
                onChanged: (_) => setState(() => _showOnlyHighlighted = !_showOnlyHighlighted),
              ),
              const SizedBox(width: 4),
              const Text('음역대로 분류', style: TextStyle(fontSize: 12)),
              Checkbox(
                visualDensity: VisualDensity.compact,
                value: isSortByNote,
                onChanged: (_) => ref.read(isSortByNoteProvider.notifier).toggle(),
              ),
              const SizedBox(width: 8),
            ],
          )
        ],
      ),
      body: libraryAsync.when(
        data: (songs) {
          final sortedSongs = List<LibrarySong>.from(songs);
          if (isSortByNote) {
            sortedSongs.sort((a, b) {
              int cmp = _notes.indexOf(a.highestNote).compareTo(_notes.indexOf(b.highestNote));
              if (cmp != 0) return cmp;
              return _compareTitles(a.title, b.title);
            });
          } else {
            sortedSongs.sort((a, b) => _compareTitles(a.title, b.title));
          }
          final displaySongs = _showOnlyHighlighted
              ? sortedSongs.where((s) => s.isHighlighted).toList()
              : sortedSongs;
          return ListView.builder(
            itemCount: displaySongs.length + 1,  // ← +1 (하단 여백용)
            itemBuilder: (context, index) {
              // ← 마지막 아이템은 빈 여백
              if (index == displaySongs.length) {
                return const SizedBox(height: 80);
              }
              final song = displaySongs[index];
              return InkWell(
                onTap: () => ref.read(libraryViewModelProvider.notifier).toggleHighlight(song),
                onLongPress: () => _showEditDialog(song),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: song.isHighlighted ? Colors.yellow.withOpacity(0.3) : Colors.transparent,
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey.shade400,  // shade200 → shade400
                        width: 1.0,                   // 0.5 → 1.0
                      ),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 24,
                        child: Text('${index + 1}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ),
                      Expanded(
                        child: RichText(
                          overflow: TextOverflow.ellipsis,
                          text: TextSpan(
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                            children: [
                              TextSpan(text: song.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              TextSpan(text: " - ${song.originalSinger}", style: const TextStyle(fontSize: 13, color: Colors.blueGrey, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(song.highestNote, style: TextStyle(color: _getNoteColor(song.highestNote), fontWeight: FontWeight.bold, fontSize: 11)),
                          Text('${song.machineBrand} ${song.songNumber}', style: TextStyle(fontSize: 10, color: _getBrandColor(song.machineBrand), fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('에러 발생: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}