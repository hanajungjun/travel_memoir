import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:travel_memoir/models/country_model.dart';
import 'package:travel_memoir/services/travel_create_service.dart';
import 'package:travel_memoir/core/widgets/range_calendar_page.dart';
import 'package:travel_memoir/features/travel_diary/pages/travel_diary_list_page.dart';

class USTravelDatePage extends StatefulWidget {
  const USTravelDatePage({super.key});

  @override
  State<USTravelDatePage> createState() => _USTravelDatePageState();
}

class _USTravelDatePageState extends State<USTravelDatePage> {
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedState; // 🎯 여기서 선택된 주 이름이 저장됩니다.

  final CountryModel _usa = CountryModel(
    code: 'US',
    nameEn: 'United States',
    nameKo: '미국',
    lat: 37.0902,
    lng: -95.7129,
    continent: 'North America',
    flagUrl: 'https://flagcdn.com/w320/us.png',
  );

  bool get _canCreate =>
      _startDate != null && _endDate != null && _selectedState != null;

  Future<void> _pickState() async {
    try {
      final String response = await rootBundle.loadString(
        'assets/geo/processed/usa_states_standard.json',
      );
      final dynamic decodedData = json.decode(response);
      List<dynamic> stateFeatures =
          (decodedData is Map && decodedData.containsKey('features'))
          ? decodedData['features']
          : decodedData;

      if (!mounted) return;

      final String? result = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        useSafeArea: false,
        backgroundColor: Colors.transparent,
        builder: (context) => _StateSearchBottomSheet(features: stateFeatures),
      );

      if (result != null) setState(() => _selectedState = result);
    } catch (e) {
      debugPrint("❌ Error loading states: $e");
    }
  }

  Future<void> _pickDateRange() async {
    final DateTimeRange? range = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CustomRangeCalendarPage(),
        fullscreenDialog: true,
      ),
    );
    if (range != null) {
      setState(() {
        _startDate = range.start;
        _endDate = range.end;
      });
    }
  }

  Future<void> _createTravel() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    // 🎯 [핵심 수정] widget.stateName 대신 로컬 변수 _selectedState를 사용합니다.
    final travel = await TravelCreateService.createUSATravel(
      userId: user.id,
      country: _usa,
      regionKey: _selectedState!, // 👈 선택된 주 이름 (예: Arizona)
      stateName: _selectedState!, // 👈 화면 표시용 이름
      startDate: _startDate!,
      endDate: _endDate!,
    );

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => TravelDiaryListPage(travel: travel)),
    );
  }

  @override
  Widget build(BuildContext context) {
    const themeColor = Color(0xFFE74C3C);
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.flag_rounded,
                        color: themeColor,
                        size: 32,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'us_travel'.tr(),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: themeColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('when_is_trip'.tr()),
                        _buildInputField(
                          text: _startDate == null
                              ? 'select_date_hint'.tr()
                              : '${DateFormat('yyyy.MM.dd').format(_startDate!)} - ${DateFormat('yyyy.MM.dd').format(_endDate!)}',
                          isSelected: _startDate != null,
                          onTap: _pickDateRange,
                        ),
                        const SizedBox(height: 24),
                        _buildLabel('select_state'.tr()),
                        _buildInputField(
                          text: _selectedState ?? 'select_state_hint'.tr(),
                          isSelected: _selectedState != null,
                          onTap: _pickState,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildSubmitButton(themeColor),
        ],
      ),
    );
  }

  Widget _buildLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      label,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    ),
  );

  Widget _buildInputField({
    required String text,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xFFEEEEEE), width: 1.5),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 15,
            color: isSelected ? Colors.black87 : Colors.black26,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton(Color color) {
    return GestureDetector(
      onTap: _canCreate ? _createTravel : null,
      child: Container(
        width: double.infinity,
        height: 70,
        color: _canCreate ? color : color.withOpacity(0.4),
        child: Center(
          child: Text(
            'save_as_memory'.tr(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class _StateSearchBottomSheet extends StatefulWidget {
  final List<dynamic> features;
  const _StateSearchBottomSheet({required this.features});
  @override
  State<_StateSearchBottomSheet> createState() =>
      _StateSearchBottomSheetState();
}

class _StateSearchBottomSheetState extends State<_StateSearchBottomSheet> {
  late List<dynamic> _filteredFeatures;
  final TextEditingController _searchController = TextEditingController();
  @override
  void initState() {
    super.initState();
    _filteredFeatures = widget.features;
  }

  void _runFilter(String query) {
    setState(
      () => _filteredFeatures = query.isEmpty
          ? widget.features
          : widget.features
                .where(
                  (f) =>
                      f['properties']?['NAME']
                          ?.toString()
                          .toLowerCase()
                          .contains(query.toLowerCase()) ??
                      false,
                )
                .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close,
                        color: Colors.black87,
                        size: 28,
                      ),
                    ),
                  ),
                  Text(
                    'select_state'.tr(),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: TextField(
                controller: _searchController,
                onChanged: _runFilter,
                decoration: InputDecoration(
                  hintText: 'search_state_hint'.tr(),
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: const Color(0xFFF1F3F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _filteredFeatures.length,
                separatorBuilder: (context, index) =>
                    Divider(color: Colors.grey[100]),
                itemBuilder: (context, index) {
                  final String name =
                      _filteredFeatures[index]['properties']?['NAME'] ??
                      'Unknown';
                  return ListTile(
                    title: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () => Navigator.pop(context, name),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
