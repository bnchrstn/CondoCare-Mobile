import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

class SessionManager {
  // Save the JWT token to SharedPreferences
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
  }

  // Retrieve the JWT token from SharedPreferences
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  // Decode the JWT token and return the decoded data
  static Future<Map<String, dynamic>?> getDecodedToken() async {
    final token = await getToken();
    if (token != null) {
      return JwtDecoder.decode(token);
    }
    return null;
  }

  // Clear the JWT token from SharedPreferences
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
  }
}
