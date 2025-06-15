import 'package:get/get.dart';
import '../config/supabase_config.dart';

class AuthController extends GetxController {
  final _userId = ''.obs;
  final _userName = ''.obs;
  final _isLoading = false.obs;

  String get userId => _userId.value;
  String get userName => _userName.value;
  bool get isLoading => _isLoading.value;

  Future<bool> login(String identifier, String password) async {
    try {
      _isLoading.value = true;

      final response = await SupabaseConfig.client
          .from('users')
          .select()
          .or('full_name.ilike.${identifier},email.ilike.${identifier}')
          .eq('Active', true)
          .eq('password', password)
          .eq('is_admin', false)
          .limit(1);

      if (response.isNotEmpty) {
        final user = response.first;
        _userId.value = user['id'];
        _userName.value = user['full_name'];
        return true;
      }
      return false;
    } catch (e) {
      print('Login error: $e');
      return false;
    } finally {
      _isLoading.value = false;
    }
  }

  void logout() {
    _userId.value = '';
    _userName.value = '';
  }
}
