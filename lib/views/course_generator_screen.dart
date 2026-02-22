import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../viewmodels/karaoke_view_model.dart';
import '../../database/database.dart';

class CourseGeneratorScreen extends ConsumerStatefulWidget {
  const CourseGeneratorScreen({super.key});

  @override
  ConsumerState<CourseGeneratorScreen> createState() => _CourseGeneratorScreenState();
}

class _CourseGeneratorScreenState extends ConsumerState<CourseGeneratorScreen> {
  final _countController = TextEditingController(text: '');
  String _selectedBrand = 'TJ';
  List<LibrarySong> _generatedCourse = [];

  Color _getNoteColor(String note) {
    if (note.contains('~2옥타브 솔#')) return Colors.green;
    if (note.contains('2옥타브 라~시')) return Colors.blue;
    if (note.contains('3옥타브 도~')) return Colors.red;
    return Colors.black;
  }

  Color _getBrandColor(String brand) {
    return brand == 'TJ' ? Colors.purple : Colors.orange;
  }

  void _generateCourse(List<LibrarySong> songs) {
    final filtered = songs.where((s) => s.machineBrand == _selectedBrand).toList();
    final count = int.tryParse(_countController.text) ?? 0;

    if (count <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('곡 수는 1곡 이상이어야 해!'))
      );
      return;
    }

    if (filtered.length < count) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('생성 실패', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          content: Text('라이브러리에 $_selectedBrand 노래가 ${filtered.length}곡밖에 없어!\n$count곡을 뽑을 수는 없잖아?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('알았어...')),
          ],
        ),
      );
      return;
    }

    final List<LibrarySong> result = List.from(filtered);
    result.shuffle();

    setState(() {
      _generatedCourse = result.take(count).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final libraryAsync = ref.watch(libraryViewModelProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('랜덤 노래 코스 생성기'), centerTitle: true),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('반주기 선택: '),
                    const SizedBox(width: 10),
                    const Text('TJ', style: TextStyle(fontSize: 12)),
                    Checkbox(
                      visualDensity: VisualDensity.compact,
                      value: _selectedBrand == 'TJ',
                      onChanged: (v) { if (v == true) setState(() => _selectedBrand = 'TJ'); },
                    ),
                    const SizedBox(width: 15),
                    const Text('금영', style: TextStyle(fontSize: 12)),
                    Checkbox(
                      visualDensity: VisualDensity.compact,
                      value: _selectedBrand == 'KY',
                      onChanged: (v) { if (v == true) setState(() => _selectedBrand = 'KY'); },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _countController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '몇 곡을 부를 거야?',
                    hintText: '숫자만 입력해!',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 45,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      libraryAsync.whenData((songs) => _generateCourse(songs));
                    },
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('코스 생성하기!'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _generatedCourse.isEmpty
                ? const Center(child: Text('아직 생성된 코스가 없어.\n버튼을 눌러봐!'))
                : ListView.builder(
              itemCount: _generatedCourse.length,
              itemBuilder: (context, index) {
                final song = _generatedCourse[index];
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
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
                              TextSpan(text: song.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                              TextSpan(text: " - ${song.originalSinger}", style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(song.highestNote, style: TextStyle(color: _getNoteColor(song.highestNote), fontSize: 10, fontWeight: FontWeight.bold)),
                          Text('${song.machineBrand} ${song.songNumber}', style: TextStyle(color: _getBrandColor(song.machineBrand), fontSize: 9, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}