import 'dart:convert';
import 'package:http/http.dart' as http;

class StableDiffusionService {
  final String apiUrl = "http://192.168.0.10:7861/sdapi/v1/txt2img";

  Future<String> generateImage(String prompt) async {
    final res = await http.post(
      Uri.parse(apiUrl),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"prompt": prompt, "steps": 25}),
    );

    final data = jsonDecode(res.body);
    return data["images"][0]; // base64 ONLY
  }
}
