import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_html/flutter_html.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://rjevhsseixukhghfkozl.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJqZXZoc3NlaXh1a2hnaGZrb3psIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM3MDQ0NzQsImV4cCI6MjA3OTI4MDQ3NH0.pMPLn9QYg2RARl20FFiisUcKojOUOdY1_PS0kvxVx8Q',
  );

  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Daily Word Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF111111),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF63A9E6),
          brightness: Brightness.dark,
        ),
      ),
      home: const AdminHomePage(),
    );
  }
}

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
      final key = _dateKey(_selectedDate);
      final fileName = '$key.png';

      final storage = Supabase.instance.client.storage;

      await storage
          .from('daily_images')
          .uploadBinary(
            fileName,
            _imageBytes!,
            fileOptions: const FileOptions(
              contentType: 'image/png',
              upsert: true,
            ),
          );

      final imageUrl = storage.from('daily_images').getPublicUrl(fileName);

      final supabase = Supabase.instance.client;

      await supabase.from('daily_words').upsert({
        'date': key,
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'image_url': imageUrl,
        'updated_at': DateTime.now().toIso8601String(),
      });

      _showSnack('저장 완료! ($key)');

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
      appBar: AppBar(title: const Text('Daily Word Admin')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: const EdgeInsets.all(24),

            // 🔥 전체 스크롤 적용
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 날짜 + 이미지 선택
                  Row(
                    children: [
                      Text(
                        '날짜: $dateLabel',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: _pickDate,
                        child: const Text('날짜 선택'),
                      ),
                      const Spacer(),
                      OutlinedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.image_outlined),
                        label: Text(_imageName ?? '이미지 선택'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // 이미지 미리보기
                  if (_imageBytes != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        height: 220, // 🔥 박스 높이 고정
                        width: double.infinity,
                        color: const Color(0xFF181818),
                        child: Image.memory(
                          _imageBytes!,
                          fit: BoxFit.contain, // 🔥 이미지만 안짤리게 축소해서 보여줌
                        ),
                      ),
                    )
                  else
                    Container(
                      height: 220,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white24),
                        color: const Color(0xFF181818),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        '이미지 미리보기',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // 제목
                  const Text(
                    '제목',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  const SizedBox(height: 8),

                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(hintText: '예) 종노플예'),
                  ),

                  const SizedBox(height: 24),

                  // 내용
                  const Text(
                    '내용',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  const SizedBox(height: 8),

                  TextField(
                    controller: _descController,
                    maxLines: 10, // 🔥 maxLines 적용
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: '설명을 입력하세요...',
                      alignLabelWithHint: true,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // HTML 미리보기
                  const Text(
                    '미리보기 (HTML 렌더링)',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                      color: const Color(0xFF1B1B1B),
                    ),
                    child: Html(
                      data: _descController.text
                          .replaceAll(
                            '<pink>',
                            '<span style="color:#FF5FA2; font-weight:bold;">',
                          )
                          .replaceAll('</pink>', '</span>'),
                      style: {
                        "body": Style(
                          color: Colors.white,
                          fontSize: FontSize(18),
                          lineHeight: const LineHeight(1.6),
                        ),
                      },
                    ),
                  ),

                  const SizedBox(height: 32),

                  // 저장 버튼
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
      ),
    );
  }
}
