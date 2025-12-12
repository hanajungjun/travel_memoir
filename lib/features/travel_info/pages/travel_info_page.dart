import 'package:flutter/material.dart';

import '../../../services/travel_list_service.dart';
import '../../travel_day/pages/travel_day_page.dart';
import '../../travel_info/pages/travel_type_select_page.dart';

class TravelInfoPage extends StatefulWidget {
  const TravelInfoPage({super.key});

  @override
  State<TravelInfoPage> createState() => _TravelInfoPageState();
}

class _TravelInfoPageState extends State<TravelInfoPage> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = TravelListService.getTravels();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('내 여행'), elevation: 0),

      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text('아직 여행이 없어요', style: TextStyle(color: Colors.grey)),
            );
          }

          final travels = snapshot.data!;

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: travels.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final travel = travels[index];

              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  // ✅ travelId만 넘김 (day는 TravelDayPage에서 처리)
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TravelDayPage(
                        travelId: travel['id'],
                        city: travel['city'],
                        startDate: DateTime.parse(travel['start_date']),
                        endDate: DateTime.parse(travel['end_date']),
                        date: DateTime.parse(travel['start_date']), // 첫 날로 이동
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        travel['city'] ?? '',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${travel['start_date']} ~ ${travel['end_date']}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),

      // ⭐ 여행 추가 버튼 (없으면 UX 깨짐)
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TravelTypeSelectPage()),
          );

          // 🔄 돌아왔을 때 리스트 새로고침
          setState(() {
            _future = TravelListService.getTravels();
          });
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
