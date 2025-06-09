import 'package:get/get.dart';
import '../config/supabase_config.dart';
import 'dart:async';
import 'package:flutter/material.dart';

class MessagesController extends GetxController {
  final String userId;
  final String userName;
  final messageController = TextEditingController();

  MessagesController({required this.userId, required this.userName});

  final _messages = <Map<String, dynamic>>[].obs;
  final _admins = <Map<String, dynamic>>[].obs;
  final _selectedAdminId = RxnString();
  final _isLoading = false.obs;
  Timer? _timer;
  int? _lastMessageId;

  List<Map<String, dynamic>> get messages => _messages;
  List<Map<String, dynamic>> get admins => _admins;
  String? get selectedAdminId => _selectedAdminId.value;
  bool get isLoading => _isLoading.value;

  @override
  void onInit() {
    super.onInit();
    fetchAdmins();
    startPeriodicFetch();
  }

  @override
  void onClose() {
    _timer?.cancel();
    messageController.dispose();
    super.onClose();
  }

  void initialize(String userId) {
    // No need to do anything here since we already handle initialization in onInit
    // This method is just to satisfy the interface expected by the MessagesScreen
  }

  void startPeriodicFetch() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      checkForNewMessages();
    });
  }

  Future<void> checkForNewMessages() async {
    if (_selectedAdminId.value == null) return;

    try {
      // Query for messages with ID greater than our last known message ID
      final query = SupabaseConfig.client
          .from('messages')
          .select()
          .or('mobile_id.eq.$userId,admin_id.eq.$userId')
          .or('mobile_id.eq.${_selectedAdminId.value},admin_id.eq.${_selectedAdminId.value}');

      // If we have a last message ID, only check for newer ones
      if (_lastMessageId != null) {
        query.gt('id', _lastMessageId!);
      }

      final newMessages = await query;

      // If we found new messages, update our list
      if ((newMessages as List).isNotEmpty) {
        final typedMessages = List<Map<String, dynamic>>.from(newMessages);

        // If this is our first fetch, just set the messages
        if (_lastMessageId == null) {
          _messages.value = typedMessages;
        } else {
          // Otherwise, add only the new messages
          _messages.addAll(typedMessages);
        }

        // Update the last message ID
        if (typedMessages.isNotEmpty) {
          _lastMessageId = typedMessages.last['id'];
        }
      }
    } catch (e) {
      print('Error checking for new messages: $e');
    }
  }

  Future<void> fetchAdmins() async {
    try {
      final response = await SupabaseConfig.client
          .from('users')
          .select()
          .eq('is_admin', true);

      _admins.value = List<Map<String, dynamic>>.from(response);
      if (_admins.isNotEmpty && _selectedAdminId.value == null) {
        selectAdmin(_admins[0]['id'].toString());
      }
    } catch (e) {
      print('Error fetching admins: $e');
    }
  }

  void selectAdmin(String adminId) {
    _selectedAdminId.value = adminId;
    // Reset the last message ID when changing admin
    _lastMessageId = null;
    fetchMessages();
  }

  // Alias for selectAdmin to match the UI's expected method name
  void setSelectedAdmin(String? adminId) {
    if (adminId != null) {
      selectAdmin(adminId);
    }
  }

  Future<void> fetchMessages() async {
    if (_selectedAdminId.value == null) return;

    try {
      _isLoading.value = true;
      final response = await SupabaseConfig.client
          .from('messages')
          .select()
          .or('mobile_id.eq.$userId,admin_id.eq.$userId')
          .or('mobile_id.eq.${_selectedAdminId.value},admin_id.eq.${_selectedAdminId.value}')
          .order('created_at', ascending: true);

      _messages.value = List<Map<String, dynamic>>.from(response);

      // Update the last message ID
      if (_messages.isNotEmpty) {
        _lastMessageId = _messages.last['id'];
      }
    } catch (e) {
      print('Error fetching messages: $e');
    } finally {
      _isLoading.value = false;
    }
  }

  Future<void> sendMessage() async {
    if (_selectedAdminId.value == null) return;
    final content = messageController.text.trim();
    if (content.isEmpty) return;

    try {
      final timestamp = DateTime.now().toIso8601String();
      final newMessage = {
        'content': content,
        'mobile_id': userId,
        'admin_id': _selectedAdminId.value,
        'from_admin': false,
        'created_at': timestamp,
      };

      final response = await SupabaseConfig.client
          .from('messages')
          .insert(newMessage)
          .select()
          .single();

      messageController.clear();

      // Add the new message with its ID to our list
      _messages.add(response);
      _lastMessageId = response['id'];
    } catch (e) {
      print('Error sending message: $e');
      rethrow;
    }
  }
}
