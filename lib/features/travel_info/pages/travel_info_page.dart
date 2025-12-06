import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:travel_memoir/core/widgets/search_dropdown.dart';

class Country {
  final String name;
  final String iso2;

  Country({required this.name, required this.iso2});
}

class CityResult {
  final String name;
  final String country;
  final double lat;
  final double lng;

  CityResult({
    required this.name,
    required this.country,
    required this.lat,
    required this.lng,
  });
}

class TravelInfoPage extends StatefulWidget {
  const TravelInfoPage({super.key});

  @override
  State<TravelInfoPage> createState() => _TravelInfoPageState();
}

class _TravelInfoPageState extends State<TravelInfoPage> {
  List<Country> _countries = [];
  List<CityResult> _cities = [];

  Country? _selectedCountry;
  CityResult? _selectedCity;

  DateTimeRange? _dateRange;

  bool _loadingCountries = true;
  bool _loadingCities = false;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadCountries();
  }

  Future<void> _loadCountries() async {
    final url = Uri.parse(
      "https://countriesnow.space/api/v0.1/countries/positions",
    );

    try {
      final res = await http.get(url);
      final json = jsonDecode(res.body);

      final data = json["data"] as List;

      _countries = data
          .map((e) => Country(name: e["name"], iso2: e["iso2"]))
          .toList();
    } catch (e) {
      print("국가 로드 실패: $e");
    }

    setState(() => _loadingCountries = false);
  }

  // ------------------------------
  // 도시 검색 (Open-Meteo)
  // ------------------------------
  void _onCityQueryChanged(String query) {
    if (_selectedCountry == null) return;

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      _searchCities(query);
    });
  }

  Future<void> _searchCities(String query) async {
    if (query.trim().isEmpty) return;

    // 첫 글자 자동 대문자
    String normalized = query.trim();
    if (normalized.isNotEmpty) {
      normalized = normalized[0].toUpperCase() + normalized.substring(1);
    }

    setState(() {
      _loadingCities = true;
      _cities = [];
    });

    final url = Uri.parse(
      "https://geocoding-api.open-meteo.com/v1/search"
      "?name=${Uri.encodeComponent(normalized)}"
      "&count=30"
      "&language=en",
    );

    try {
      final res = await http.get(url);
      final json = jsonDecode(res.body);

      List results = json["results"] ?? [];

      // 🔥 여기서 우리가 직접 대한민국(KR) 데이터만 필터링!
      _cities = results
          .where(
            (e) =>
                (e["country_code"] ?? "").toString().toUpperCase() ==
                _selectedCountry!.iso2.toUpperCase(),
          )
          .map(
            (e) => CityResult(
              name: e["name"],
              country: e["country"],
              lat: (e["latitude"] as num).toDouble(),
              lng: (e["longitude"] as num).toDouble(),
            ),
          )
          .toList();

      print("도시 필터링 결과: ${_cities.length}");
    } catch (e) {
      print("도시 검색 실패: $e");
    }

    setState(() => _loadingCities = false);
  }

  // 여행 날짜 선택
  void _pickDate() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );

    if (range != null) {
      setState(() => _dateRange = range);
    }
  }

  void _createTravel() {
    if (_selectedCountry == null ||
        _selectedCity == null ||
        _dateRange == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("모든 정보를 입력해주세요.")));
      return;
    }

    print("🔥 여행 생성 완료!");
    print("나라: ${_selectedCountry!.name}");
    print("도시: ${_selectedCity!.name}");
    print("시작일: ${_dateRange!.start}");
    print("종료일: ${_dateRange!.end}");
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingCountries) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("여행 정보 입력"), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // -------- 나라 --------
            SearchDropdown<Country>(
              label: "나라",
              hintText: "나라 검색",
              items: _countries,
              displayString: (c) => "${c.name} (${c.iso2})",
              onSelected: (c) {
                setState(() {
                  _selectedCountry = c;
                  _selectedCity = null;
                  _cities = [];
                });
              },
              mode: SearchMode.local,
            ),

            const SizedBox(height: 24),

            // -------- 도시 --------
            SearchDropdown<CityResult>(
              label: "도시",
              hintText: _selectedCountry == null
                  ? "먼저 나라를 선택하세요"
                  : "도시 검색 (예: Seoul)",
              enabled: _selectedCountry != null,
              items: _cities,
              loading: _loadingCities,
              displayString: (c) => "${c.name}, ${c.country}",
              onSelected: (c) {
                setState(() => _selectedCity = c);
              },
              mode: SearchMode.remote,
              onQueryChanged: _onCityQueryChanged,
            ),

            const SizedBox(height: 32),

            // -------- 날짜 선택 --------
            Row(
              children: [
                const Text(
                  "여행 날짜",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade400),
                ),
                child: Text(
                  _dateRange == null
                      ? "날짜 선택"
                      : "${_dateRange!.start.toString().split(' ')[0]}  ~  ${_dateRange!.end.toString().split(' ')[0]}",
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),

            const SizedBox(height: 40),

            // -------- 여행 생성 버튼 --------
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _createTravel,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text("여행 생성하기", style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
