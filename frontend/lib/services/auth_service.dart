import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';

class AuthService {
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  static Future<void> deleteToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  static Future<bool> login(String email, String password) async {
    final url = Uri.parse('$apiBaseUrl/login');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'}, // <-- Kein Token hier!
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await saveToken(data['access_token']);
        return true;
      }
    } catch (e) {
      print('Login Fehler: $e');
    }
    return false;
  }

  static Future<Map<String, String>> getHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<bool> register(
    String name,
    String email,
    String password,
  ) async {
    final url = Uri.parse('$apiBaseUrl/register');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
          'password_confirmation': password,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        await saveToken(data['access_token']);
        return true;
      }
    } catch (e) {
      print('Registrierungs Fehler: $e');
    }
    return false;
  }
}
