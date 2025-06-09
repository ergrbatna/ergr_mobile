import 'package:get/get.dart';
import '../config/supabase_config.dart';

class HomeController extends GetxController {
  final String userId;
  final String userName;

  HomeController({required this.userId, required this.userName});

  final _selectedWilaya = RxnString();
  final _selectedDayra = RxnString();
  final _selectedBaladya = RxnString();
  final _selectedPlant = RxnString();
  final _isHA = true.obs;
  final _isLoading = false.obs;

  final _wilayas = <String>[].obs;
  final _dayras = <String>[].obs;
  final _baladyas = <String>[].obs;
  final _plants = <String>[].obs;

  String? get selectedWilaya => _selectedWilaya.value;
  String? get selectedDayra => _selectedDayra.value;
  String? get selectedBaladya => _selectedBaladya.value;
  String? get selectedPlant => _selectedPlant.value;
  bool get isHA => _isHA.value;
  bool get isLoading => _isLoading.value;

  List<String> get wilayas => _wilayas;
  List<String> get dayras => _dayras;
  List<String> get baladyas => _baladyas;
  List<String> get plants => _plants;

  @override
  void onInit() {
    super.onInit();
    loadInitialData();
  }

  Future<void> loadInitialData() async {
    try {
      final wilayaResponse =
          await SupabaseConfig.client.from('place').select('wilaya');
      final plantResponse =
          await SupabaseConfig.client.from('plants').select('name');

      _wilayas.value =
          (wilayaResponse as List).map((e) => e['wilaya'] as String).toList();
      _plants.value =
          (plantResponse as List).map((e) => e['name'] as String).toList();
    } catch (e) {
      print('Error loading initial data: $e');
    }
  }

  Future<void> loadDayras(String wilaya) async {
    try {
      _selectedWilaya.value = wilaya;
      _selectedDayra.value = null;
      _selectedBaladya.value = null;

      final response = await SupabaseConfig.client
          .from('place')
          .select('dayra')
          .eq('wilaya', wilaya);

      _dayras.value =
          (response as List).map((e) => e['dayra'] as String).toList();
    } catch (e) {
      print('Error loading dayras: $e');
    }
  }

  Future<void> loadBaladyas(String dayra) async {
    try {
      _selectedDayra.value = dayra;
      _selectedBaladya.value = null;

      final response = await SupabaseConfig.client
          .from('place')
          .select('baladya')
          .eq('dayra', dayra);

      _baladyas.value =
          (response as List).map((e) => e['baladya'] as String).toList();
    } catch (e) {
      print('Error loading baladyas: $e');
    }
  }

  void setSelectedBaladya(String baladya) {
    _selectedBaladya.value = baladya;
  }

  void setSelectedPlant(String plant) {
    _selectedPlant.value = plant;
  }

  void toggleHA() {
    _isHA.value = !_isHA.value;
  }

  Future<bool> submitForm({
    required String quantity,
    String? space,
    String? note,
  }) async {
    try {
      _isLoading.value = true;

      final spaceValue =
          space?.isEmpty == true ? null : '${space} ${isHA ? "HA" : "KM"}';

      // Check if similar history entry exists
      final existingHistory = await SupabaseConfig.client
          .from('history')
          .select()
          .eq('plant_name', selectedPlant!)
          .eq('wilaya', selectedWilaya!)
          .eq('dayra', selectedDayra!)
          .eq('baladya', selectedBaladya!)
          .eq('quantity', quantity)
          .eq('space', spaceValue as Object)
          .eq('created_by', userId)
          .maybeSingle();

      if (existingHistory != null) {
        return false;
      }

      // Insert new history entry
      await SupabaseConfig.client.from('history').insert({
        'plant_name': selectedPlant,
        'quantity': quantity,
        'space': spaceValue,
        'wilaya': selectedWilaya,
        'dayra': selectedDayra,
        'baladya': selectedBaladya,
        'created_by': userId,
      });

      // Create and send message to all admins
      final formattedMessage = '''
📝 @$userName added new information:

🌱 Plant: $selectedPlant
📍 Location: $selectedWilaya, $selectedDayra, $selectedBaladya
📊 Quantity: $quantity
${spaceValue != null ? '📐 Space: $spaceValue' : ''}
${note?.isNotEmpty == true ? '\n💬 Note: $note' : ''}
''';

      final adminsResponse = await SupabaseConfig.client
          .from('users')
          .select('id')
          .eq('is_admin', true);

      final admins = List<Map<String, dynamic>>.from(adminsResponse);

      for (final admin in admins) {
        try {
          await SupabaseConfig.client.from('messages').upsert(
            {
              'content': formattedMessage,
              'mobile_id': userId,
              'admin_id': admin['id'],
              'from_admin': false,
              'created_at': DateTime.now().toIso8601String(),
            },
            onConflict: 'mobile_id,admin_id,content',
          );
        } catch (e) {
          if (!e.toString().toLowerCase().contains('duplicate')) {
            print('Error sending message to admin: $e');
          }
        }
      }

      return true;
    } catch (e) {
      print('Error submitting form: $e');
      return false;
    } finally {
      _isLoading.value = false;
    }
  }
}
