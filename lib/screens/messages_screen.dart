import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/messages_controller.dart';
import 'package:intl/intl.dart';

class MessagesScreen extends StatelessWidget {
  final String userId;
  final String userName;

  MessagesScreen({
    Key? key,
    required this.userId,
    required this.userName,
  }) : super(key: key);

  final ScrollController _scrollController = ScrollController();

  String _formatDateTime(String dateTimeString) {
    final dateTime = DateTime.parse(dateTimeString).toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDate == today) {
      // If message is from today, only show time
      return DateFormat('HH:mm:ss').format(dateTime);
    } else {
      // If message is from another day, show date and time
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
            items: messagesController.admins
                .map((admin) => DropdownMenuItem(
                      value: admin['id'].toString(),
                      child: Text(admin['full_name']),
                    ))
                .toList(),
            onChanged: (value) => messagesController.setSelectedAdmin(value),
          )),
        ),

        // Messages List
        Expanded(
          child: Obx(() {
            if (messagesController.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

            if (messagesController.messages.isEmpty) {
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

            return ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: messagesController.messages.length,
              itemBuilder: (context, index) {
                final message = messagesController.messages[index];
                final isFromMe = message['mobile_id'] == userId;

                return Align(
                  alignment: isFromMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    decoration: BoxDecoration(
                      color: isFromMe ? Colors.purple.shade100 : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message['content'],
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDateTime(message['created_at']),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
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
                    hintText: 'Type a message...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide(color: Colors.purple.withOpacity(0.5)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: const BorderSide(color: Colors.purple, width: 2),
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
                    if (messagesController.messageController.text.trim().isNotEmpty) {
                      messagesController.sendMessage().then((_) {
                        _scrollToBottom();
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