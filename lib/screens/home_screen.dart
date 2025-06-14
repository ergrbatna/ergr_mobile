import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../config/supabase_config.dart';
import '../controllers/messages_controller.dart';
import 'messages_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  final String userName;
  final String userId;

  const HomeScreen({
    super.key,
    required this.userName,
    required this.userId,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _formKey = GlobalKey<FormState>();
  String? selectedWilaya;
  String? selectedDayra;
  String? selectedBaladya;
  String? selectedPlant;
  final _quantityController = TextEditingController();
  final _spaceController = TextEditingController();
  final _noteController = TextEditingController();
  bool isHA = true;
  bool _isLoading = false;
  int _selectedIndex = 0;

  List<String> wilayas = [];
  List<String> dayras = [];
  List<String> baladyas = [];
  List<String> plants = [];

  late final MessagesController _messagesController;

  @override
  void initState() {
    super.initState();
    _loadData();
    // Initialize MessagesController
    _messagesController = Get.put(MessagesController(
      userId: widget.userId,
      userName: widget.userName,
    ));
  }

  Future<void> _loadData() async {
    try {
      final wilayaResponse =
          await SupabaseConfig.client.from('place').select('wilaya');
      final plantResponse =
          await SupabaseConfig.client.from('plants').select('name');

      if (mounted) {
        setState(() {
          wilayas = (wilayaResponse as List)
              .map((e) => e['wilaya'] as String)
              .toList();
          plants =
              (plantResponse as List).map((e) => e['name'] as String).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadDayras(String wilaya) async {
    try {
      final response = await SupabaseConfig.client
          .from('place')
          .select('dayra')
          .eq('wilaya', wilaya);

      if (mounted) {
        setState(() {
          dayras = (response as List).map((e) => e['dayra'] as String).toList();
          selectedDayra = null;
          selectedBaladya = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading dayras: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadBaladyas(String dayra) async {
    try {
      final response = await SupabaseConfig.client
          .from('place')
          .select('baladya')
          .eq('dayra', dayra);

      if (mounted) {
        setState(() {
          baladyas =
              (response as List).map((e) => e['baladya'] as String).toList();
          selectedBaladya = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading baladyas: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    // Show confirmation dialog
    final bool? shouldProceed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Réalisation',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Êtes-vous sûr de vouloir envoyer ceci :',
                  style: TextStyle(
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• Wilaya : $selectedWilaya'),
                    Text('• Dayra : $selectedDayra'),
                    Text('• Baladya : $selectedBaladya'),
                    const SizedBox(height: 10),
                    Text('• Plant : $selectedPlant'),
                    Text('• Quantité : ${_quantityController.text}'),
                    Text(
                        '• Espace : ${_spaceController.text} ${isHA ? "HA" : "KM"}'),
                    if (_noteController.text.isNotEmpty)
                      Text('• Note : ${_noteController.text}'),
                  ],
                ),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(100, 40),
                      ),
                      child: const Text('Yes'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(100, 40),
                      ),
                      child: const Text('No'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (shouldProceed != true) return;

    setState(() => _isLoading = true);

    try {
      final space = _spaceController.text.isEmpty
          ? 'N/A'
          : '${_spaceController.text} ${isHA ? "HA" : "KM"}';

      // Check if similar history entry exists
      final existingHistory = await SupabaseConfig.client
          .from('history')
          .select()
          .eq('plant_name', selectedPlant!)
          .eq('wilaya', selectedWilaya!)
          .eq('dayra', selectedDayra!)
          .eq('baladya', selectedBaladya!)
          .eq('quantity', _quantityController.text)
          .eq('space', space)
          .eq('created_by', widget.userId)
          .maybeSingle();

      // Only insert if no similar history exists
      if (existingHistory == null) {
        await SupabaseConfig.client.from('history').insert({
          'plant_name': selectedPlant,
          'quantity': _quantityController.text,
          'space': space,  // This will now be 'N/A' if space is not provided
          'wilaya': selectedWilaya,
          'dayra': selectedDayra,
          'baladya': selectedBaladya,
          'created_by': widget.userId,
        });

        // Create a formatted message with all information
        final formattedMessage = '''
📝 @${widget.userName} added new information:

🌱 Plant: $selectedPlant
📍 Location: $selectedWilaya, $selectedDayra, $selectedBaladya
📊 Quantity: ${_quantityController.text}
📐 Space: $space
${_noteController.text.isNotEmpty ? '\n💬 Note: ${_noteController.text}' : ''}
''';

        // Get all admins
        final adminsResponse = await SupabaseConfig.client
            .from('users')
            .select('id')
            .eq('is_admin', true);

        final admins = List<Map<String, dynamic>>.from(adminsResponse);

        // Check for existing messages for each admin
        for (final admin in admins) {
          // Check if this exact message already exists for this admin
          final existingMessages = await SupabaseConfig.client
              .from('messages')
              .select()
              .eq('mobile_id', widget.userId)
              .eq('admin_id', admin['id'])
              .eq('content', formattedMessage)
              .limit(1);

          // Only send if no identical message exists
          if ((existingMessages as List).isEmpty) {
            await SupabaseConfig.client.from('messages').insert({
              'content': formattedMessage,
              'mobile_id': widget.userId,
              'admin_id': admin['id'],
              'from_admin': false,
              'created_at': DateTime.now().toIso8601String(),
            });
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Data submitted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _formKey.currentState!.reset();
          setState(() {
            selectedWilaya = null;
            selectedDayra = null;
            selectedBaladya = null;
            selectedPlant = null;
            _quantityController.clear();
            _spaceController.clear();
            _noteController.clear();
            isHA = true;
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This information has already been submitted'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildHomeContent() {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.purple,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Bienvenue ${widget.userName}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.purple.withOpacity(0.1),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Détails de l\'emplacement',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple,
                          ),
                        ),
                        const SizedBox(height: 20),
                        DropdownButtonFormField<String>(
                          value: selectedWilaya,
                          decoration: InputDecoration(
                            labelText: 'Wilaya',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Colors.purple),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.purple.withOpacity(0.5)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Colors.purple, width: 2),
                            ),
                          ),
                          items: wilayas.map((wilaya) {
                            return DropdownMenuItem(
                              value: wilaya,
                              child: Text(wilaya),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() => selectedWilaya = value);
                            if (value != null) {
                              _loadDayras(value);
                            }
                          },
                          validator: (value) =>
                              value == null ? 'Please select a wilaya' : null,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: selectedDayra,
                          decoration: InputDecoration(
                            labelText: 'Dayra',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Colors.purple),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.purple.withOpacity(0.5)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Colors.purple, width: 2),
                            ),
                          ),
                          items: dayras.map((dayra) {
                            return DropdownMenuItem(
                              value: dayra,
                              child: Text(dayra),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() => selectedDayra = value);
                            if (value != null) {
                              _loadBaladyas(value);
                            }
                          },
                          validator: (value) =>
                              value == null ? 'Please select a dayra' : null,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: selectedBaladya,
                          decoration: InputDecoration(
                            labelText: 'Baladya',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Colors.purple),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.purple.withOpacity(0.5)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Colors.purple, width: 2),
                            ),
                          ),
                          items: baladyas.map((baladya) {
                            return DropdownMenuItem(
                              value: baladya,
                              child: Text(baladya),
                            );
                          }).toList(),
                          onChanged: (value) =>
                              setState(() => selectedBaladya = value),
                          validator: (value) =>
                              value == null ? 'Please select a baladya' : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.purple.withOpacity(0.1),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Informations sur la plante',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple,
                          ),
                        ),
                        const SizedBox(height: 20),
                        DropdownButtonFormField<String>(
                          value: selectedPlant,
                          decoration: InputDecoration(
                            labelText: 'Nom de la plante',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Colors.purple),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.purple.withOpacity(0.5)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Colors.purple, width: 2),
                            ),
                          ),
                          items: plants.map((plant) {
                            return DropdownMenuItem(
                              value: plant,
                              child: Text(plant),
                            );
                          }).toList(),
                          onChanged: (value) =>
                              setState(() => selectedPlant = value),
                          validator: (value) =>
                              value == null ? 'Please select a plant' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _quantityController,
                          decoration: InputDecoration(
                            labelText: 'Quantité',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.purple.withOpacity(0.5)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Colors.purple, width: 2),
                            ),
                            prefixIcon: const Icon(Icons.numbers, color: Colors.purple),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value?.isEmpty == true) {
                              return 'Please enter quantity';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _spaceController,
                                decoration: InputDecoration(
                                  labelText: 'Espace (Optionnel)',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(color: Colors.purple.withOpacity(0.5)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: Colors.purple, width: 2),
                                  ),
                                  prefixIcon: const Icon(Icons.space_bar, color: Colors.purple),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.purple.withOpacity(0.5)),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                    child: Row(
                                      children: [
                                        Radio<bool>(
                                          value: true,
                                          groupValue: isHA,
                                          onChanged: (value) =>
                                              setState(() => isHA = value!),
                                          activeColor: Colors.purple,
                                        ),
                                        const Text('HA'),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                    child: Row(
                                      children: [
                                        Radio<bool>(
                                          value: false,
                                          groupValue: isHA,
                                          onChanged: (value) =>
                                              setState(() => isHA = value!),
                                          activeColor: Colors.purple,
                                        ),
                                        const Text('KM'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.purple.withOpacity(0.1),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Informations supplémentaires',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple,
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _noteController,
                          decoration: InputDecoration(
                            labelText: 'Note',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.purple.withOpacity(0.5)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Colors.purple, width: 2),
                            ),
                            prefixIcon: const Icon(Icons.note, color: Colors.purple),
                          ),
                          maxLines: 4,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 5,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Soumettre',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(Icons.send),
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedIndex == 0 ? 'Société ERGR' : 'Messages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Get.offAll(() => const LoginScreen()),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildHomeContent(),
          MessagesScreen(userId: widget.userId, userName: widget.userName),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: Icon(Icons.message_outlined),
            selectedIcon: Icon(Icons.message),
            label: 'Messages',
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _spaceController.dispose();
    _noteController.dispose();
    super.dispose();
  }
}
