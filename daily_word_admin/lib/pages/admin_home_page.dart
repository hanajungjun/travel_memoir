import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../services/daily_word_service.dart';
import '../services/storage_service.dart';
import '../widgets/date_picker_row.dart';
import '../widgets/image_preview.dart';
import '../widgets/html_preview.dart';
import 'history_page.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  DateTime _selectedDate = DateTime.now();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  Uint8List? _imageBytes;
  String? _imageName;

  bool _isSaving = false;

  final dailyWordService = DailyWordService();
  final storageService = StorageService();

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  String _dateKey(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}${two(d.month)}${two(d.day)}';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.single;
      if (file.bytes == null) return;

      setState(() {
        _imageBytes = file.bytes;
        _imageName = file.name;
      });
    }
  }

  Future<void> _save() async {
    if (_imageBytes == null) return _showSnack('이미지를 선택해 주세요.');
    if (_titleController.text.trim().isEmpty) {
      return _showSnack('제목을 입력해 주세요.');
    }
    if (_descController.text.trim().isEmpty) {
      return _showSnack('내용을 입력해 주세요.');
    }

    setState(() => _isSaving = true);

    try {
      final dateKey = _dateKey(_selectedDate);

      // 1) 🔥 Storage 업로드 (고유 파일명 생성됨)
      final imageUrl = await storageService.uploadImage(
        dateKey: dateKey, // <= 여기가 핵심!
        bytes: _imageBytes!,
      );

      // 2) DB 저장
      await dailyWordService.saveDailyWord(
        date: dateKey,
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        imageUrl: imageUrl,
      );

      _showSnack('저장 완료! ($dateKey)');

      _titleController.clear();
      _descController.clear();
      setState(() {
        _imageBytes = null;
        _imageName = null;
      });
    } catch (e) {
      _showSnack('저장 실패: $e');
      print('🔥 ERROR: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = _dateKey(_selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Word Admin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HistoryPage()),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DatePickerRow(
                  dateLabel: dateLabel,
                  onPickDate: _pickDate,
                  onPickImage: _pickImage,
                  imageName: _imageName,
                ),

                const SizedBox(height: 16),
                ImagePreview(bytes: _imageBytes),

                const SizedBox(height: 24),
                const Text(
                  '제목',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(hintText: '제목 입력'),
                ),

                const SizedBox(height: 24),
                const Text(
                  '내용',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _descController,
                  maxLines: 10,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'HTML 사용 가능 (<pink>텍스트</pink>)',
                  ),
                ),

                const SizedBox(height: 24),
                const Text(
                  '미리보기 (HTML)',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                const SizedBox(height: 12),
                HtmlPreview(text: _descController.text),

                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_upload_outlined),
                    label: Text(_isSaving ? '저장 중...' : '업로드 / 저장'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
