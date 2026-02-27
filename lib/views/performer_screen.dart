import '../main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../viewmodels/karaoke_view_model.dart';
import '../database/database.dart';

class PerformerScreen extends ConsumerWidget {
  const PerformerScreen({super.key});

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text('인원 추가'),
      content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: '이름을 입력해!'), autofocus: true),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        ElevatedButton(onPressed: () { if (ctrl.text.isNotEmpty) ref.read(performerViewModelProvider.notifier).addPerformer(ctrl.text); Navigator.pop(context); }, child: const Text('등록')),
      ],
    ));
  }

  void _showDeleteWarning(BuildContext context, WidgetRef ref, Performer p) {
    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text('정말 삭제할 거야?', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
      content: Text('"${p.name}"님을 삭제하면 이미 기록된 모든 노래에서 이 이름이 사라져 버릴 거야. 진짜 지울 거야?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        TextButton(
          onPressed: () {
            ref.read(performerViewModelProvider.notifier).removePerformer(p);
            Navigator.pop(context);
          },
          child: const Text('응, 지워줘', style: TextStyle(color: Colors.red)),
        ),
      ],
    ));
  }

  Future<void> _showSessionDates(BuildContext context, Performer p) async {
    final dates = await database.getSessionDatesByPerformer(p.name);
    if (dates.isEmpty) return;  // 날짜 없으면 아무 동작 없음

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${p.name}이(가) 노래한 날'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: dates.length,
            itemBuilder: (context, i) => ListTile(
              dense: true,
              leading: const Icon(Icons.calendar_month, size: 18, color: Colors.indigo),
              title: Text(
                '${dates[i].year}년 ${dates[i].month}월 ${dates[i].day}일',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('닫기')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final performersAsync = ref.watch(performerViewModelProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('함께한 사람들')),
      body: performersAsync.when(
        data: (list) => ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, index) {
            final p = list[index];
            return ListTile(
              title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              onTap: () => _showSessionDates(context, p),  // ← 추가
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                onPressed: () => _showDeleteWarning(context, ref, p),
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('에러: $e')),
      ),
      floatingActionButton: FloatingActionButton(onPressed: () => _showAddDialog(context, ref), child: const Icon(Icons.person_add)),
    );
  }
}