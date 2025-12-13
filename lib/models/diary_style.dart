class DiaryStyle {
  final String id;
  final String title;
  final String description;
  final String prompt;

  const DiaryStyle({
    required this.id,
    required this.title,
    required this.description,
    required this.prompt,
  });
}

const diaryStyles = [
  DiaryStyle(
    id: 'kids',
    title: '초등학교 일기',
    description: '크레용 느낌의 귀여운 그림일기',
    prompt:
        'korean elementary school diary, crayon drawing, simple, cute, NO TEXT',
  ),
  DiaryStyle(
    id: 'simpsons',
    title: '심슨 스타일',
    description: '심슨 만화풍',
    prompt: 'simpsons cartoon style, bold lines, flat colors, NO TEXT',
  ),
  DiaryStyle(
    id: 'watercolor',
    title: '수채화 감성',
    description: '잔잔한 수채화 느낌',
    prompt: 'soft watercolor painting, emotional, warm colors, NO TEXT',
  ),
];
