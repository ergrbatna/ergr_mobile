import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_ergr/config/supabase_config.dart';
import '../controllers/messages_controller.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:collection/collection.dart';

class MessagesScreen extends StatelessWidget {
  final String userId;
  final String userName;

  MessagesScreen({
    Key? key,
    required this.userId,
    required this.userName,
  }) : super(key: key);

  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<dynamic> _lastMessageId = ValueNotifier(null);
  Timer? _refreshTimer;

  String _formatDateTime(String dateTimeString) {
    final dateTime = DateTime.parse(dateTimeString)
        .toLocal()
        .subtract(const Duration(hours: 1));
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDate == today) {
      return DateFormat('HH:mm:ss').format(dateTime);
    } else {
      return DateFormat('dd/MM/yyyy HH:mm:ss').format(dateTime);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void startPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      await checkForNewMessages();
    });
  }

  Future<void> checkForNewMessages() async {
    // Fetch messages from Supabase (or your backend)
    final response = await SupabaseConfig.client
        .from('messages')
        .select()
        .order('created_at', ascending: true);

    final newMessages = List<Map<String, dynamic>>.from(response);

    if (newMessages.isNotEmpty) {
      final newLastId = newMessages.last['id'];
      if (_lastMessageId.value != newLastId) {
        _lastMessageId.value = newLastId;
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent + 200,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesController = Get.find<MessagesController>();

    return Column(
      children: [
        // Admin Selection Section
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Obx(() => DropdownButtonFormField<String>(
                isExpanded: true,
                value: messagesController.selectedAdminId,
                hint: const Text('Select Admin'),
                decoration: InputDecoration(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.purple),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        BorderSide(color: Colors.purple.withOpacity(0.5)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: Colors.purple, width: 2),
                  ),
                ),
                items: messagesController.admins
                    .map((admin) => DropdownMenuItem(
                          value: admin['id'].toString(),
                          child: Text(admin['full_name']),
                        ))
                    .toList(),
                onChanged: (value) =>
                    messagesController.setSelectedAdmin(value),
              )),
        ),

        // Messages List
        Expanded(
          child: Obx(() {
            if (messagesController.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (messagesController.messages.isEmpty) {
              _lastMessageId.value = null;
              return const Center(
                child: Text(
                  'No messages yet',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
              );
            }

            // Scroll only when new message is added
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final messages = messagesController.messages;
              if (messages.isNotEmpty) {
                final lastMessage = messages.last;
                final lastId = lastMessage['id'];
                if (_lastMessageId.value != lastId) {
                  _lastMessageId.value = lastId;
                  if (_scrollController.hasClients) {
                    _scrollController.animateTo(
                      _scrollController.position.maxScrollExtent + 200,
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOut,
                    );
                  }
                }
              }
            });

            return ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: messagesController.messages.length,
              itemBuilder: (context, index) {
                final message = messagesController.messages[index];
                final isAdmin = message['from_admin'] ?? false;
                final time = DateTime.parse(message['created_at']);
                final adminName = messagesController.admins.firstWhereOrNull(
                  (admin) => admin['id'] == message['admin_id'],
                )?['full_name'] ?? 'Admin';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment:
                        isAdmin ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisAlignment:
                            isAdmin ? MainAxisAlignment.start : MainAxisAlignment.end,
                        children: [
                          if (!isAdmin) ...[
                            Text(
                              DateFormat('d MMM yyyy hh:mm a').format(time),
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            isAdmin ? adminName : 'Me',
                            style: const TextStyle(
                              color: Colors.purple,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          if (isAdmin) ...[
                            const SizedBox(width: 8),
                            Text(
                              DateFormat('d MMM yyyy hh:mm a').format(time),
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.all(12),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.5,
                        ),
                        decoration: BoxDecoration(
                          color: isAdmin 
                            ? Colors.purple.withOpacity(0.1) 
                            : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isAdmin 
                              ? Colors.purple.withOpacity(0.2) 
                              : Colors.grey.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          message['content'],
                          style: TextStyle(
                            color: isAdmin ? Colors.purple.shade700 : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          }),
        ),

        // Message Input
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: messagesController.messageController,
                  decoration: InputDecoration(
                    hintText: 'Tapez un message...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide:
                          BorderSide(color: Colors.purple.withOpacity(0.5)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide:
                          const BorderSide(color: Colors.purple, width: 2),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: const BoxDecoration(
                  color: Colors.purple,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white),
                  onPressed: () {
                    if (messagesController.messageController.text
                        .trim()
                        .isNotEmpty) {
                      messagesController.sendMessage().then((_) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (_scrollController.hasClients) {
                            _scrollController.animateTo(
                              _scrollController.position.maxScrollExtent,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                            );
                          }
                        });
                      });
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
