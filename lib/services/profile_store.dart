import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

class UserProfile {
  final String name;
  final String text;
  final String cvName;
  final String cvUrl;

  const UserProfile({
    required this.name,
    required this.text,
    this.cvName = '',
    this.cvUrl = '',
  });

  bool get isEmpty => text.trim().isEmpty;
}

class ProfileStore {
  static Future<UserProfile> load() async {
    final prefs = await SharedPreferences.getInstance();
    return UserProfile(
      name: prefs.getString('myName') ?? defaultName,
      text: prefs.getString('myProfile') ?? defaultProfile,
      cvName: prefs.getString('cvName') ?? '',
      cvUrl: prefs.getString('cvUrl') ?? '',
    );
  }

  static Future<void> save(UserProfile p) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('myName', p.name);
    await prefs.setString('myProfile', p.text);
    await prefs.setString('cvName', p.cvName);
    await prefs.setString('cvUrl', p.cvUrl);
  }

  static Future<String> loadGeminiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('geminiKey') ?? '';
  }

  static Future<void> saveGeminiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('geminiKey', key.trim());
  }
}