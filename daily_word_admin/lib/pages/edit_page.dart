import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../models/daily_word.dart';
import '../services/daily_word_service.dart';
import '../services/storage_service.dart';

class EditPage extends StatefulWidget {
  final DailyWord word;

  const EditPage({super.key, required this.word});

  @override
  State<EditPage> createState() => _EditPageState();
}

class _EditPageState extends State<EditPage> {
  late TextEditingController _titleController;
  late TextEditingController _descController;

  Uint8List? _newImageBytes;
  String? _newImageName;

  final dailyWordService = DailyWordService();
  final storageService = StorageService();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.word.title);
    _descController = TextEditingController(text: widget.word.description);
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _newImageBytes = result.files.single.bytes;
        _newImageName = result.files.single.name;
      });
    }
  }

  Future<void> _save() async {
    String imageUrl = widget.word.imageUrl;

    // 🔥 이미지 바꾼 경우 → Storage 재업로드
    if (_newImageBytes != null) {
      imageUrl = await storageService.uploadImage(
        dateKey: widget.word.date,
        bytes: _newImageBytes!,
      );
    }

    await dailyWordService.updateWord(widget.word.id, {
      'title': _titleController.text.trim(),
      'description': _descController.text.trim(),
      'image_url': imageUrl,
      'updated_at': DateTime.now().toIso8601String(),
    });

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("수정하기"),
        actions: [IconButton(icon: const Icon(Icons.save), onPressed: _save)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("제목", style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            TextField(controller: _titleController),

            const SizedBox(height: 24),
            const Text("내용", style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            TextField(controller: _descController, maxLines: 10),

            const SizedBox(height: 24),
            const Text("이미지", style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),

            if (_newImageBytes != null)
              Image.memory(_newImageBytes!, fit: BoxFit.contain)
            else
              Image.network(widget.word.imageUrl, fit: BoxFit.contain),

            const SizedBox(height: 16),

            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.image),
              label: Text(_newImageName ?? "이미지 변경"),
            ),
          ],
        ),
      ),
    );
  }
}
