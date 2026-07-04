import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/theme_extensions.dart';

class DesktopCommunicationView extends StatefulWidget {
  final Map<String, dynamic> userData;

  const DesktopCommunicationView({super.key, required this.userData});

  @override
  State<DesktopCommunicationView> createState() => _DesktopCommunicationViewState();
}

class _DesktopCommunicationViewState extends State<DesktopCommunicationView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _selectedChat;
  final TextEditingController _messageController = TextEditingController();

  final List<Map<String, dynamic>> _messages = [
    {'sender': 'partner', 'text': 'Good morning, HOD sir. Regarding the curriculum adjustments...', 'time': '10:15 AM'},
    {'sender': 'me', 'text': 'Morning. Yes, I saw your proposal. Let\'s proceed with Semester 3 update.', 'time': '10:17 AM'},
    {'sender': 'partner', 'text': 'Understood. I have updated the database index schema accordingly.', 'time': '10:20 AM'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({
        'sender': 'me',
        'text': text,
        'time': 'Just now',
      });
      _messageController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.bgColor,
      child: Row(
        children: [
          // Left Sidebar Pane: Conversations and Request flow
          Container(
            width: 340,
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: context.borderColor)),
            ),
            child: Column(
              children: [
                // ERP ID Lookup bar
                Padding(
                  padding: EdgeInsets.all(20),
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: context.cardColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: context.borderColor),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Icon(Icons.person_search, color: context.textMuted, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            style: TextStyle(color: context.textPrimary, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Search ERP ID...',
                              hintStyle: GoogleFonts.poppins(color: context.textMuted2),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Active conversation / requests tab headers
                TabBar(
                  controller: _tabController,
                  labelColor: Colors.blueAccent,
                  unselectedLabelColor: context.textMuted,
                  indicatorColor: Colors.blueAccent,
                  dividerColor: context.borderColor,
                  labelStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold),
                  tabs: [
                    Tab(text: 'Conversations'),
                    Tab(text: 'Chat Requests'),
                  ],
                ),

                // Tabs body list
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildActiveConversationsList(),
                      _buildRequestsWorkflowList(),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Right Pane: Messaging window
          Expanded(
            child: _selectedChat == null
                ? _buildEmptyState()
                : Column(
                    children: [
                      // Active chat header
                      Container(
                        height: 70,
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: context.borderColor)),
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.blueAccent.withOpacity(0.2),
                                  child: Icon(Icons.person, color: Colors.blueAccent),
                                ),
                                SizedBox(width: 14),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedChat!['name'],
                                      style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      _selectedChat!['role'] ?? 'Staff',
                                      style: GoogleFonts.poppins(color: context.textMuted, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                IconButton(icon: Icon(Icons.phone_outlined, color: context.textSecondary), onPressed: () {}),
                                SizedBox(width: 8),
                                IconButton(icon: Icon(Icons.videocam_outlined, color: context.textSecondary), onPressed: () {}),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Messages Stream list
                      Expanded(
                        child: ListView.builder(
                          padding: EdgeInsets.all(24),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final msg = _messages[index];
                            final isMe = msg['sender'] == 'me';

                            return Align(
                              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                margin: EdgeInsets.only(bottom: 16),
                                constraints: BoxConstraints(maxWidth: 500),
                                padding: EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isMe ? Color(0xFF3b5998) : context.cardColor,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(12),
                                    topRight: const Radius.circular(12),
                                    bottomLeft: isMe ? const Radius.circular(12) : Radius.zero,
                                    bottomRight: isMe ? Radius.zero : const Radius.circular(12),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      msg['text'],
                                      style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 13),
                                    ),
                                    SizedBox(height: 6),
                                    Text(
                                      msg['time'],
                                      style: GoogleFonts.poppins(color: context.textMuted, fontSize: 10),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      // Message Composer
                      Container(
                        height: 70,
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          border: Border(top: BorderSide(color: context.borderColor)),
                        ),
                        child: Row(
                          children: [
                            IconButton(icon: Icon(Icons.attach_file, color: context.textSecondary), onPressed: () {}),
                            SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _messageController,
                                style: TextStyle(color: context.textPrimary, fontSize: 13),
                                decoration: InputDecoration(
                                  hintText: 'Type your message...',
                                  hintStyle: GoogleFonts.poppins(color: context.textMuted2),
                                  border: InputBorder.none,
                                ),
                                onSubmitted: (_) => _sendMessage(),
                              ),
                            ),
                            SizedBox(width: 12),
                            IconButton(
                              icon: Icon(Icons.send, color: Colors.blueAccent),
                              onPressed: _sendMessage,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_outlined, color: Colors.blueAccent.withOpacity(0.2), size: 80),
          SizedBox(height: 16),
          Text(
            'Secure Campus Messaging',
            style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 4),
          Text(
            'Lookup an ERP ID or select an active accepted conversation to chat securely.',
            style: GoogleFonts.poppins(color: context.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveConversationsList() {
    final List<Map<String, dynamic>> activeChats = [
      {'name': 'Mrs. K. Shanti', 'role': 'Assistant Professor', 'lastMsg': 'Database index updated.', 'time': '10:20 AM'},
      {'name': 'Dr. V. Rama Rao', 'role': 'HOD Computer Engineering', 'lastMsg': 'Let\'s review the proposal.', 'time': '9:40 AM'},
    ];

    return ListView.builder(
      itemCount: activeChats.length,
      itemBuilder: (context, index) {
        final chat = activeChats[index];
        final isSelected = _selectedChat != null && _selectedChat!['name'] == chat['name'];

        return ListTile(
          onTap: () {
            setState(() {
              _selectedChat = chat;
            });
          },
          tileColor: isSelected ? context.cardColor : Colors.transparent,
          leading: CircleAvatar(
            backgroundColor: Colors.blueAccent.withOpacity(0.15),
            child: Icon(Icons.person, color: Colors.blueAccent),
          ),
          title: Text(chat['name'], style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
          subtitle: Text(chat['lastMsg'], style: GoogleFonts.poppins(color: context.textMuted, fontSize: 11), overflow: TextOverflow.ellipsis),
          trailing: Text(chat['time'], style: GoogleFonts.poppins(color: context.textMuted2, fontSize: 10)),
        );
      },
    );
  }

  Widget _buildRequestsWorkflowList() {
    final List<Map<String, dynamic>> incomingRequests = [
      {'name': 'Student Rohith Sen', 'role': 'ADM2026114', 'time': 'Yesterday'},
    ];

    return ListView.builder(
      itemCount: incomingRequests.length,
      itemBuilder: (context, index) {
        final req = incomingRequests[index];
        return Card(
          color: context.cardColor,
          margin: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(req['name'], style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                Text('${req['role']} • Incoming Chat Request', style: GoogleFonts.poppins(color: context.textMuted, fontSize: 11)),
                SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () {}, child: Text('Reject', style: TextStyle(color: Colors.redAccent, fontSize: 12))),
                    SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Chat request from ${req['name']} accepted.')),
                        );
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: context.textPrimary),
                      child: Text('Accept', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

