import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/theme_provider.dart';

/// Database Entity Mock Models
class ErpUser {
  final String erpId;
  final String name;
  final String role;
  final String department;
  final String avatarUrl;
  final bool isOnline;
  final String lastSeen;

  ErpUser({
    required this.erpId,
    required this.name,
    required this.role,
    required this.department,
    required this.avatarUrl,
    required this.isOnline,
    required this.lastSeen,
  });
}

class ChatRequest {
  final String id;
  final ErpUser sender;
  final String optionalMessage;
  final DateTime timestamp;
  String status; // 'PENDING', 'ACCEPTED', 'REJECTED', 'BLOCKED'

  ChatRequest({
    required this.id,
    required this.sender,
    required this.optionalMessage,
    required this.timestamp,
    this.status = 'PENDING',
  });
}

class ErpMessage {
  final String id;
  final String senderId;
  final String receiverId;
  String content;
  final DateTime timestamp;
  final String type; // 'TEXT', 'VOICE', 'IMAGE', 'FILE', 'ERP_DOC'
  final String? attachmentUrl;
  final String? attachmentName;
  final String? attachmentSize;
  bool isStarred;
  bool isPinned;
  bool isEdited;
  bool isDeletedForMe;
  bool isDeletedForEveryone;
  String? replyToId;
  String? replyToContent;
  String? reaction; // emoji reaction

  ErpMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.timestamp,
    this.type = 'TEXT',
    this.attachmentUrl,
    this.attachmentName,
    this.attachmentSize,
    this.isStarred = false,
    this.isPinned = false,
    this.isEdited = false,
    this.isDeletedForMe = false,
    this.isDeletedForEveryone = false,
    this.replyToId,
    this.replyToContent,
    this.reaction,
  });
}

class ErpGroup {
  final String id;
  final String name;
  final String description;
  final String iconUrl;
  final List<String> memberIds;
  final List<String> adminIds;
  final List<ErpMessage> messages;

  ErpGroup({
    required this.id,
    required this.name,
    required this.description,
    required this.iconUrl,
    required this.memberIds,
    required this.adminIds,
    required this.messages,
  });
}

class ErpStatus {
  final String id;
  final ErpUser user;
  final String type; // 'TEXT', 'IMAGE'
  final String content;
  final DateTime timestamp;
  final List<String> viewers;
  final Map<String, String> reactions; // userId -> reactionEmoji

  ErpStatus({
    required this.id,
    required this.user,
    required this.type,
    required this.content,
    required this.timestamp,
    required this.viewers,
    required this.reactions,
  });
}

class ErpConnectScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const ErpConnectScreen({super.key, required this.userData});

  @override
  State<ErpConnectScreen> createState() => _ErpConnectScreenState();
}

class _ErpConnectScreenState extends State<ErpConnectScreen> with SingleTickerProviderStateMixin {
  /// Theme helpers
  late bool isDark;
  late Color primaryColor;
  late Color scaffoldBg;
  late Color chatBg;
  late Color sidebarBg;
  late Color bubbleSent;
  late Color bubbleRecv;
  late Color borderCol;
  late Color textCol;
  late Color subTextCol;

  /// User data extracted from dashboard session
  late String myErpId;
  late String myName;
  late String myRole;
  late String myDept;

  /// Sidebar navigation
  int _activeSidebarTab = 0; // 0: Chats, 1: Requests, 2: New Contact, 3: Statuses, 4: Call Logs, 5: Moderate Panel
  String? _selectedConversationId; // erpId of active chat partner OR groupId
  bool _isGroupSelected = false;
  bool _showRightPanel = false;

  /// Global Search
  final TextEditingController _globalSearchController = TextEditingController();
  final TextEditingController _messageSearchController = TextEditingController();
  bool _isSearchingMessages = false;
  String _messageSearchQuery = '';

  /// Searching ERP ID fields
  final TextEditingController _erpSearchController = TextEditingController();
  String? _erpSearchError;
  ErpUser? _searchedUserResult;

  /// Messaging inputs
  final TextEditingController _messageController = TextEditingController();
  ErpMessage? _replyMessageContext;

  /// Simulated Audio note recording states
  bool _isRecordingAudio = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;
  String? _recordedAudioPreviewUrl;

  /// WebRTC Call state simulation
  bool _isCallActive = false;
  bool _isVideoCall = false;
  bool _isIncomingCall = false;
  String? _callPartnerId;
  String _callState = 'Ringing'; // 'Ringing', 'Connected', 'Ended'
  bool _callDataSaver = false;
  String _networkQuality = 'Excellent'; // 'Excellent', 'Good', 'Fair', 'Poor'
  double _callBitrateKbps = 1500.0;
  double _dataConsumedMb = 0.0;
  Timer? _callStatsTimer;

  /// Local database mocks (Fully interactive simulation state)
  List<ErpUser> _usersDb = [];
  List<ChatRequest> _requestsDb = [];
  List<ErpMessage> _messagesDb = [];
  List<ErpGroup> _groupsDb = [];
  List<ErpStatus> _statusesDb = [];
  List<String> _blockedUsersDb = [];
  List<Map<String, dynamic>> _callLogsDb = [];
  List<Map<String, dynamic>> _abuseReportsDb = [];

  @override
  void initState() {
    super.initState();
    _initUserInfo();
    _seedMockDatabase();
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _callStatsTimer?.cancel();
    _globalSearchController.dispose();
    _messageSearchController.dispose();
    _erpSearchController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _initUserInfo() {
    myRole = widget.userData['role'] ?? 'Student';
    myDept = widget.userData['branch'] ?? widget.userData['department'] ?? 'CSE';
    
    // Resolve login ERP IDs dynamically
    if (widget.userData['id'] != null && widget.userData['id'].toString().length > 5) {
      myErpId = widget.userData['login_id']?.toString() ?? widget.userData['id']?.toString() ?? 'ERP-ID';
    } else {
      myErpId = widget.userData['id']?.toString() ?? 'ERP-ID';
    }
    myName = widget.userData['full_name'] ?? 'ERP User';
  }

  void _seedMockDatabase() {
    // 1. Target Directory Users (Strict Connection Lookup ONLY)
    _usersDb = [
      ErpUser(erpId: 'FAC-50194', name: 'Prof. Rajesh Kumar', role: 'Faculty', department: 'Computer Engineering', avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150', isOnline: true, lastSeen: 'Online'),
      ErpUser(erpId: '24634-CM-026', name: 'Rohan Sharma', role: 'Student', department: 'Civil Engineering', avatarUrl: 'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=150', isOnline: false, lastSeen: 'Last seen 10 mins ago'),
      ErpUser(erpId: 'EMP-1004', name: 'Anil Dev', role: 'Administrator', department: 'Management Office', avatarUrl: 'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=150', isOnline: true, lastSeen: 'Online'),
      ErpUser(erpId: 'PAR-2031', name: 'Suresh Sharma', role: 'Parent', department: 'Parent of Rohan Sharma', avatarUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150', isOnline: false, lastSeen: 'Last seen 3 hours ago'),
      ErpUser(erpId: 'HOD-3021', name: 'Dr. Vikram Sen', role: 'HOD', department: 'CME Department', avatarUrl: 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150', isOnline: true, lastSeen: 'Online'),
      ErpUser(erpId: 'PRI-1001', name: 'Dr. M. S. Murthy', role: 'Principal', department: 'Principal Office', avatarUrl: 'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=150', isOnline: true, lastSeen: 'Online'),
      ErpUser(erpId: 'COO-2002', name: 'Smt. K. Sarada', role: 'Coordinator', department: 'Exam Cell', avatarUrl: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=150', isOnline: false, lastSeen: 'Last seen yesterday'),
    ];

    // 2. Chat Requests
    _requestsDb = [
      ChatRequest(
        id: 'req_1',
        sender: _usersDb[0], // Faculty
        optionalMessage: 'Hello, need to discuss the upcoming syllabus deadline request.',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      ChatRequest(
        id: 'req_2',
        sender: _usersDb[3], // Parent
        optionalMessage: 'Hello, tracking attendance record anomalies of Rohan.',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];

    // 3. Messages Db
    _messagesDb = [
      ErpMessage(id: 'm_1', senderId: 'EMP-1004', receiverId: myErpId, content: 'Welcome to ERP Connect! Use the ID search to build your connection directory.', timestamp: DateTime.now().subtract(const Duration(days: 3))),
      ErpMessage(id: 'm_2', senderId: 'HOD-3021', receiverId: myErpId, content: 'Good morning, please review the curriculum file attached below.', timestamp: DateTime.now().subtract(const Duration(hours: 5))),
      ErpMessage(id: 'm_3', senderId: 'HOD-3021', receiverId: myErpId, content: 'Curriculum_2026.pdf', timestamp: DateTime.now().subtract(const Duration(hours: 4)), type: 'FILE', attachmentName: 'Curriculum_2026.pdf', attachmentSize: '1.2 MB'),
      ErpMessage(id: 'm_4', senderId: myErpId, receiverId: 'HOD-3021', content: 'Yes Dr. Sen, I will verify it right away.', timestamp: DateTime.now().subtract(const Duration(hours: 3))),
    ];

    // 4. Groups Db
    _groupsDb = [
      ErpGroup(
        id: 'g_1',
        name: 'CSE Department Faculty',
        description: 'Official group chat for faculty coordination',
        iconUrl: 'https://images.unsplash.com/photo-1522071820081-009f0129c71c?w=150',
        memberIds: ['FAC-50194', 'HOD-3021', 'PRI-1001', myErpId],
        adminIds: ['HOD-3021'],
        messages: [
          ErpMessage(id: 'gm_1', senderId: 'HOD-3021', receiverId: 'g_1', content: 'Colleagues, principal has called a staff meeting tomorrow at 10 AM.', timestamp: DateTime.now().subtract(const Duration(hours: 10))),
          ErpMessage(id: 'gm_2', senderId: 'PRI-1001', receiverId: 'g_1', content: 'Please carry all attendance record worksheets.', timestamp: DateTime.now().subtract(const Duration(hours: 8))),
        ],
      ),
      ErpGroup(
        id: 'g_2',
        name: 'Placement Coordination Cell',
        description: 'Student updates regarding placements & internships',
        iconUrl: 'https://images.unsplash.com/photo-1543269865-cbf427effbad?w=150',
        memberIds: ['24634-CM-026', 'EMP-1004', myErpId],
        adminIds: ['EMP-1004'],
        messages: [
          ErpMessage(id: 'gm_3', senderId: 'EMP-1004', receiverId: 'g_2', content: 'Wipro drive registration link is closing in 2 hours.', timestamp: DateTime.now().subtract(const Duration(hours: 1))),
        ],
      ),
    ];

    // 5. Statuses Db
    _statusesDb = [
      ErpStatus(id: 's_1', user: _usersDb[0], type: 'TEXT', content: 'Weekend syllabus correction session completed! 👍', timestamp: DateTime.now().subtract(const Duration(hours: 5)), viewers: ['EMP-1004'], reactions: {'EMP-1004': '👏'}),
      ErpStatus(id: 's_2', user: _usersDb[4], type: 'IMAGE', content: 'https://images.unsplash.com/photo-1517245386807-bb43f82c33c4?w=400', timestamp: DateTime.now().subtract(const Duration(hours: 12)), viewers: [], reactions: {}),
    ];

    // 6. Call Logs
    _callLogsDb = [
      {'partner': _usersDb[0], 'type': 'VOICE', 'outgoing': false, 'missed': false, 'time': 'Today, 2:30 PM'},
      {'partner': _usersDb[4], 'type': 'VIDEO', 'outgoing': true, 'missed': false, 'time': 'Yesterday, 11:15 AM'},
      {'partner': _usersDb[1], 'type': 'VOICE', 'outgoing': false, 'missed': true, 'time': 'June 9, 4:45 PM'},
    ];

    // 7. Admin Abuse reports
    _abuseReportsDb = [
      {'reporter': '24634-CM-026', 'reported': 'FAC-50194', 'reason': 'Spamming marks reminders', 'time': '2026-06-10 14:02'},
    ];
  }

  /// Interactive Simulation Helpers
  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;
    final content = _messageController.text.trim();
    _messageController.clear();

    final newMessage = ErpMessage(
      id: 'm_${DateTime.now().millisecondsSinceEpoch}',
      senderId: myErpId,
      receiverId: _selectedConversationId!,
      content: content,
      timestamp: DateTime.now(),
      replyToId: _replyMessageContext?.id,
      replyToContent: _replyMessageContext?.content,
    );

    setState(() {
      if (_isGroupSelected) {
        final idx = _groupsDb.indexWhere((g) => g.id == _selectedConversationId);
        if (idx != -1) {
          _groupsDb[idx].messages.add(newMessage);
        }
      } else {
        _messagesDb.add(newMessage);
      }
      _replyMessageContext = null;
    });

    // Simulate Echo / Auto Reply after 3 seconds for premium demo feel
    if (!_isGroupSelected) {
      Timer(const Duration(seconds: 2), () {
        if (!mounted || _selectedConversationId != newMessage.receiverId) return;
        final partner = _usersDb.firstWhere((u) => u.erpId == _selectedConversationId);
        
        setState(() {
          _messagesDb.add(ErpMessage(
            id: 'm_${DateTime.now().millisecondsSinceEpoch}',
            senderId: _selectedConversationId!,
            receiverId: myErpId,
            content: 'Simulation reply from ${partner.name}: Received your message successfully!',
            timestamp: DateTime.now(),
          ));
        });
      });
    }
  }

  void _sendAttachment(String type, String name, String size, {String content = ''}) {
    final newMsg = ErpMessage(
      id: 'm_${DateTime.now().millisecondsSinceEpoch}',
      senderId: myErpId,
      receiverId: _selectedConversationId!,
      content: content.isEmpty ? name : content,
      timestamp: DateTime.now(),
      type: type,
      attachmentName: name,
      attachmentSize: size,
    );

    setState(() {
      if (_isGroupSelected) {
        final idx = _groupsDb.indexWhere((g) => g.id == _selectedConversationId);
        if (idx != -1) {
          _groupsDb[idx].messages.add(newMsg);
        }
      } else {
        _messagesDb.add(newMsg);
      }
    });
  }

  void _sendErpAttachment(String docType) {
    String name = '';
    String size = '';
    String previewContent = '';
    
    switch (docType) {
      case 'ASSIGNMENT':
        name = 'Assignment_CM_501.pdf';
        size = '840 KB';
        previewContent = '📝 Assignment CM-501 (Database Systems)';
        break;
      case 'MARKS':
        name = 'Semester_4_Marks_Memo.pdf';
        size = '1.4 MB';
        previewContent = '🎓 Semester IV Consolidated Marks Memo';
        break;
      case 'FEE':
        name = 'Tuition_Fee_Receipt_2026.pdf';
        size = '450 KB';
        previewContent = '💳 Receipt: Tuition Fee (Part A)';
        break;
      case 'TIMETABLE':
        name = 'Weekly_Class_Timetable.pdf';
        size = '320 KB';
        previewContent = '📅 Semester V Class Timetable Schedule';
        break;
      case 'LEAVE':
        name = 'Approved_Medical_Leave_Form.pdf';
        size = '510 KB';
        previewContent = '🏥 Approved Leave Form (Medical Absences)';
        break;
    }

    _sendAttachment('ERP_DOC', name, size, content: previewContent);
    Navigator.pop(context); // Close the attachment bottom sheet
  }

  void _sendVoiceNote() {
    if (_recordedAudioPreviewUrl == null) return;
    _sendAttachment('VOICE', 'Voice Note (0:${_recordingSeconds.toString().padLeft(2, '0')})', '240 KB');
    setState(() {
      _recordedAudioPreviewUrl = null;
      _recordingSeconds = 0;
    });
  }

  void _startAudioRecording() {
    setState(() {
      _isRecordingAudio = true;
      _recordingSeconds = 0;
      _recordedAudioPreviewUrl = null;
    });
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _recordingSeconds++;
      });
    });
  }

  void _stopAudioRecording({bool cancel = false}) {
    _recordingTimer?.cancel();
    setState(() {
      _isRecordingAudio = false;
      if (!cancel && _recordingSeconds > 0) {
        _recordedAudioPreviewUrl = 'simulated_audio_url_path';
      } else {
        _recordingSeconds = 0;
      }
    });
  }

  void _searchErpId() {
    final query = _erpSearchController.text.trim();
    if (query.isEmpty) return;

    final found = _usersDb.firstWhere(
      (u) => u.erpId.toLowerCase() == query.toLowerCase(),
      orElse: () => ErpUser(erpId: '', name: '', role: '', department: '', avatarUrl: '', isOnline: false, lastSeen: ''),
    );

    setState(() {
      if (found.erpId.isEmpty) {
        _searchedUserResult = null;
        _erpSearchError = 'No user found with the exact ERP ID: "$query"';
      } else if (found.erpId == myErpId) {
        _searchedUserResult = null;
        _erpSearchError = 'You cannot connect with your own ERP ID.';
      } else {
        _searchedUserResult = found;
        _erpSearchError = null;
      }
    });
  }

  void _sendConnectionRequest() {
    if (_searchedUserResult == null) return;
    
    // Check if already requested
    final isDuplicate = _requestsDb.any((r) => r.sender.erpId == myErpId && r.sender.erpId == _searchedUserResult!.erpId);
    if (isDuplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connection request already pending.')),
      );
      return;
    }

    setState(() {
      _requestsDb.add(ChatRequest(
        id: 'req_${DateTime.now().millisecondsSinceEpoch}',
        sender: ErpUser(
          erpId: myErpId,
          name: myName,
          role: myRole,
          department: myDept,
          avatarUrl: 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150', // placeholder self avatar
          isOnline: true,
          lastSeen: 'Online',
        ),
        optionalMessage: 'Connection request from $myName ($myRole)',
        timestamp: DateTime.now(),
        status: 'PENDING',
      ));
      
      _searchedUserResult = null;
      _erpSearchController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Connection request sent successfully!')),
    );
  }

  void _handleRequestAction(ChatRequest req, String action) {
    setState(() {
      req.status = action;
      if (action == 'ACCEPTED') {
        _selectedConversationId = req.sender.erpId;
        _isGroupSelected = false;
        _activeSidebarTab = 0; // return to chats
        
        // Seed welcome greeting messages
        _messagesDb.add(ErpMessage(
          id: 'm_greet_${DateTime.now().millisecondsSinceEpoch}',
          senderId: req.sender.erpId,
          receiverId: myErpId,
          content: 'Hello! Thanks for accepting the connection request.',
          timestamp: DateTime.now(),
        ));
      } else if (action == 'BLOCKED') {
        _blockedUsersDb.add(req.sender.erpId);
      }
      _requestsDb.removeWhere((r) => r.id == req.id);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Request $action')),
    );
  }

  /// WebRTC Video/Voice call simulation controls
  void _initiateCall(String erpId, bool isVideo) {
    setState(() {
      _isCallActive = true;
      _isVideoCall = isVideo;
      _isIncomingCall = false;
      _callPartnerId = erpId;
      _callState = 'Ringing';
      _callBitrateKbps = isVideo ? 1200.0 : 64.0;
      _dataConsumedMb = 0.0;
    });

    // Simulate connecting
    Timer(const Duration(seconds: 3), () {
      if (!mounted || !_isCallActive) return;
      setState(() {
        _callState = 'Connected';
      });

      // Periodic statistic simulator
      _callStatsTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted || !_isCallActive || _callState != 'Connected') {
          timer.cancel();
          return;
        }

        // Random network quality oscillations
        final rand = DateTime.now().second % 12;
        String quality = 'Excellent';
        double rate = _isVideoCall ? 1800.0 : 70.0;
        
        if (rand == 4 || rand == 8) {
          quality = 'Good';
          rate = _isVideoCall ? 900.0 : 50.0;
        } else if (rand == 6) {
          quality = 'Fair';
          rate = _isVideoCall ? 450.0 : 35.0;
        } else if (rand == 10) {
          quality = 'Poor';
          rate = _isVideoCall ? 110.0 : 20.0;
        }

        if (_callDataSaver) {
          rate = _isVideoCall ? 320.0 : 30.0;
        }

        setState(() {
          _networkQuality = quality;
          _callBitrateKbps = rate;
          
          double bytesSec = (rate * 1000) / 8; // bits to bytes
          _dataConsumedMb += bytesSec / (1024 * 1024); // increment MB
        });
      });
    });
  }

  void _endCall() {
    _callStatsTimer?.cancel();
    
    // Add call log
    final partner = _usersDb.firstWhere((u) => u.erpId == _callPartnerId, orElse: () => _usersDb[0]);
    setState(() {
      _callLogsDb.insert(0, {
        'partner': partner,
        'type': _isVideoCall ? 'VIDEO' : 'VOICE',
        'outgoing': !_isIncomingCall,
        'missed': false,
        'time': 'Just now',
      });
      
      _callState = 'Ended';
    });

    Timer(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {
        _isCallActive = false;
        _callPartnerId = null;
      });
    });
  }

  /// Story Status simulation
  void _addTextStatus() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Text('Add Text Status', style: GoogleFonts.poppins(color: textCol, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: textController,
          maxLines: 3,
          style: TextStyle(color: textCol),
          decoration: const InputDecoration(
            hintText: "What is on your mind? (e.g. syllabus update, class cancelled)",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (textController.text.trim().isNotEmpty) {
                setState(() {
                  _statusesDb.insert(0, ErpStatus(
                    id: 's_self_${DateTime.now().millisecondsSinceEpoch}',
                    user: ErpUser(
                      erpId: myErpId,
                      name: myName,
                      role: myRole,
                      department: myDept,
                      avatarUrl: 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150',
                      isOnline: true,
                      lastSeen: 'Online',
                    ),
                    type: 'TEXT',
                    content: textController.text.trim(),
                    timestamp: DateTime.now(),
                    viewers: [],
                    reactions: {},
                  ));
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Status updated.')));
              }
            },
            child: const Text('Publish'),
          ),
        ],
      ),
    );
  }

  void _createNewGroup() {
    final groupNameController = TextEditingController();
    final groupDescController = TextEditingController();
    List<String> selectedMembers = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            top: 20, left: 24, right: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Create Placement/Class Group', style: GoogleFonts.poppins(color: textCol, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                TextField(
                  controller: groupNameController,
                  style: TextStyle(color: textCol),
                  decoration: const InputDecoration(
                    labelText: 'Group Name',
                    hintText: 'e.g. CSE-A Period 3 Coordinator',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: groupDescController,
                  style: TextStyle(color: textCol),
                  decoration: const InputDecoration(
                    labelText: 'Group Description',
                    hintText: 'Topic/Department coordinates...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 15),
                Text('Select Members to Include:', style: GoogleFonts.poppins(color: textCol, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _usersDb.length,
                    itemBuilder: (context, i) {
                      final u = _usersDb[i];
                      final isSelected = selectedMembers.contains(u.erpId);
                      return CheckboxListTile(
                        title: Text(u.name, style: TextStyle(color: textCol)),
                        subtitle: Text('${u.role} - ${u.erpId}', style: TextStyle(color: subTextCol, fontSize: 11)),
                        value: isSelected,
                        onChanged: (val) {
                          setModalState(() {
                            if (val == true) {
                              selectedMembers.add(u.erpId);
                            } else {
                              selectedMembers.remove(u.erpId);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                      onPressed: () {
                        if (groupNameController.text.trim().isEmpty) return;
                        final newG = ErpGroup(
                          id: 'g_${DateTime.now().millisecondsSinceEpoch}',
                          name: groupNameController.text.trim(),
                          description: groupDescController.text.trim(),
                          iconUrl: 'https://images.unsplash.com/photo-1522071820081-009f0129c71c?w=150',
                          memberIds: [...selectedMembers, myErpId],
                          adminIds: [myErpId],
                          messages: [
                            ErpMessage(id: 'gm_init_${DateTime.now().millisecondsSinceEpoch}', senderId: myErpId, receiverId: 'g_temp', content: 'Group created by $myName ($myRole)', timestamp: DateTime.now())
                          ],
                        );
                        setState(() {
                          _groupsDb.add(newG);
                          _selectedConversationId = newG.id;
                          _isGroupSelected = true;
                        });
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('New Group Created!')));
                      },
                      child: const Text('Create', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    primaryColor = const Color(0xFF10B981); // WhatsApp Emerald Green
    scaffoldBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    chatBg = isDark ? const Color(0xFF0B141A) : const Color(0xFFE5DDD5);
    sidebarBg = isDark ? const Color(0xFF111B21) : Colors.white;
    bubbleSent = isDark ? const Color(0xFF005C4B) : const Color(0xFFD9FDD3);
    bubbleRecv = isDark ? const Color(0xFF202C33) : Colors.white;
    borderCol = isDark ? Colors.white10 : Colors.black12;
    textCol = isDark ? Colors.white : Colors.black87;
    subTextCol = isDark ? Colors.white60 : Colors.black54;

    return Theme(
      data: Theme.of(context).copyWith(
        primaryColor: primaryColor,
        hintColor: primaryColor,
      ),
      child: Scaffold(
        backgroundColor: scaffoldBg,
        body: SafeArea(
          child: Stack(
            children: [
              Row(
                children: [
                  // 1. Sidebar Panel (Left)
                  Container(
                    width: MediaQuery.of(context).size.width > 700 ? 360 : MediaQuery.of(context).size.width,
                    decoration: BoxDecoration(
                      color: sidebarBg,
                      border: Border(right: BorderSide(color: borderCol, width: 1)),
                    ),
                    child: _buildSidebar(),
                  ),

                  // 2. Chat Conversation Panel (Center / Right)
                  if (MediaQuery.of(context).size.width > 700 || _selectedConversationId != null)
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              color: chatBg,
                              child: _selectedConversationId != null
                                  ? _buildChatWindow()
                                  : _buildEmptyState(),
                            ),
                          ),

                          // 3. User Details Sidebar panel (Right)
                          if (_showRightPanel && _selectedConversationId != null)
                            Container(
                              width: 320,
                              decoration: BoxDecoration(
                                color: sidebarBg,
                                border: Border(left: BorderSide(color: borderCol, width: 1)),
                              ),
                              child: _buildRightDetailPanel(),
                            ),
                        ],
                      ),
                    ),
                ],
              ),

              // 4. Simulated WebRTC Call Overlay Dialog
              if (_isCallActive)
                _buildCallOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  /// LEFT SIDEBAR LAYOUT
  Widget _buildSidebar() {
    return Column(
      children: [
        // Sidebar Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: isDark ? const Color(0xFF202C33) : const Color(0xFFF0F2F5),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: primaryColor.withOpacity(0.2),
                child: Text(myName.isNotEmpty ? myName[0].toUpperCase() : 'E', style: GoogleFonts.poppins(color: primaryColor, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(myName, style: GoogleFonts.poppins(color: textCol, fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('$myRole • $myErpId', style: GoogleFonts.poppins(color: subTextCol, fontSize: 10)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                color: primaryColor,
                onPressed: () => Navigator.pop(context),
                tooltip: 'Exit ERP Connect',
              ),
            ],
          ),
        ),

        // Sidebar Navigation Tabs
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Row(
            children: [
              _buildTabButton(0, Icons.chat, 'Chats'),
              _buildTabButton(1, Icons.pending_actions_rounded, 'Requests (${_requestsDb.where((r)=>r.status=='PENDING').length})'),
              _buildTabButton(2, Icons.person_add_alt_1_rounded, 'Connect'),
              _buildTabButton(3, Icons.filter_tilt_shift_rounded, 'Status'),
              _buildTabButton(4, Icons.call, 'Calls'),
              if (myRole.toLowerCase().contains('admin') || myRole.toLowerCase().contains('coordinator') || myRole.toLowerCase().contains('principal'))
                _buildTabButton(5, Icons.admin_panel_settings_rounded, 'Moderate'),
            ],
          ),
        ),
        const Divider(height: 1),

        // Sidebar Main Content List
        Expanded(
          child: _getSidebarBodyContent(),
        ),
      ],
    );
  }

  Widget _buildTabButton(int index, IconData icon, String label) {
    final isSelected = _activeSidebarTab == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.white : subTextCol),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.poppins(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Colors.white : textCol)),
          ],
        ),
        selected: isSelected,
        selectedColor: primaryColor,
        backgroundColor: isDark ? const Color(0xFF202C33) : const Color(0xFFE2E8F0),
        onSelected: (val) {
          if (val) {
            setState(() {
              _activeSidebarTab = index;
            });
          }
        },
      ),
    );
  }

  Widget _getSidebarBodyContent() {
    switch (_activeSidebarTab) {
      case 0:
        return _buildChatsList();
      case 1:
        return _buildRequestsTab();
      case 2:
        return _buildConnectTab();
      case 3:
        return _buildStatusesTab();
      case 4:
        return _buildCallsTab();
      case 5:
        return _buildModerateTab();
      default:
        return _buildChatsList();
    }
  }

  /// CHATS TAB - ACTIVE LIST
  Widget _buildChatsList() {
    // Collect active conversation partners from messages DB (excluding self)
    final chatPartners = <String>{};
    for (var m in _messagesDb) {
      if (m.senderId == myErpId) chatPartners.add(m.receiverId);
      if (m.receiverId == myErpId) chatPartners.add(m.senderId);
    }

    final activeUsers = _usersDb.where((u) => chatPartners.contains(u.erpId)).toList();

    return Column(
      children: [
        // Sidebar Chat Search
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: TextField(
            controller: _globalSearchController,
            style: TextStyle(color: textCol, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search chats or groups...',
              prefixIcon: Icon(Icons.search, size: 16, color: subTextCol),
              isDense: true,
              fillColor: isDark ? const Color(0xFF202C33) : Colors.white,
              filled: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
            onChanged: (val) => setState(() {}),
          ),
        ),

        // Add Group Button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor.withOpacity(0.15),
              foregroundColor: primaryColor,
              elevation: 0,
              minimumSize: const Size(double.infinity, 38),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.groups, size: 18),
            label: Text('Create Class/Faculty Group', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold)),
            onPressed: _createNewGroup,
          ),
        ),

        // List
        Expanded(
          child: activeUsers.isEmpty && _groupsDb.isEmpty
              ? Center(child: Text('No active chats yet.\nUse Connect tab to search by ERP ID.', textAlign: TextAlign.center, style: TextStyle(color: subTextCol, fontSize: 12)))
              : ListView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    // Groups List
                    if (_groupsDb.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 16, top: 12, bottom: 4),
                        child: Text('Groups', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5)),
                      ),
                      ..._groupsDb.where((g) {
                        if (_globalSearchController.text.isEmpty) return true;
                        return g.name.toLowerCase().contains(_globalSearchController.text.toLowerCase());
                      }).map((g) {
                        final lastMsg = g.messages.isNotEmpty ? g.messages.last : null;
                        final isSelected = _selectedConversationId == g.id && _isGroupSelected;
                        return ListTile(
                          selected: isSelected,
                          selectedTileColor: isDark ? Colors.white10 : Colors.black12,
                          leading: CircleAvatar(
                            backgroundImage: NetworkImage(g.iconUrl),
                            radius: 20,
                          ),
                          title: Text(g.name, style: GoogleFonts.poppins(color: textCol, fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: Text(lastMsg != null ? '${lastMsg.senderId}: ${lastMsg.content}' : 'Tap to start group coordination', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: subTextCol, fontSize: 11)),
                          trailing: Text(lastMsg != null ? DateFormat('hh:mm a').format(lastMsg.timestamp) : '', style: TextStyle(color: subTextCol, fontSize: 10)),
                          onTap: () {
                            setState(() {
                              _selectedConversationId = g.id;
                              _isGroupSelected = true;
                            });
                          },
                        );
                      }),
                    ],

                    // Personal Chats List
                    Padding(
                      padding: const EdgeInsets.only(left: 16, top: 16, bottom: 4),
                      child: Text('Direct Messages', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5)),
                    ),
                    ...activeUsers.where((u) {
                      if (_globalSearchController.text.isEmpty) return true;
                      return u.name.toLowerCase().contains(_globalSearchController.text.toLowerCase()) || u.erpId.toLowerCase().contains(_globalSearchController.text.toLowerCase());
                    }).map((u) {
                      // Get conversation messages
                      final convMsgs = _messagesDb.where((m) =>
                        (m.senderId == myErpId && m.receiverId == u.erpId) ||
                        (m.senderId == u.erpId && m.receiverId == myErpId)
                      ).toList();
                      final lastMsg = convMsgs.isNotEmpty ? convMsgs.last : null;
                      final isSelected = _selectedConversationId == u.erpId && !_isGroupSelected;
                      
                      // Typing indicator mock
                      final isTyping = (u.erpId == 'FAC-50194' && DateTime.now().second % 10 < 3);

                      return ListTile(
                        selected: isSelected,
                        selectedTileColor: isDark ? Colors.white10 : Colors.black12,
                        leading: Stack(
                          children: [
                            CircleAvatar(
                              backgroundImage: NetworkImage(u.avatarUrl),
                              radius: 20,
                            ),
                            if (u.isOnline)
                              Positioned(
                                right: 0, bottom: 0,
                                child: Container(
                                  width: 10, height: 10,
                                  decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle, border: Border.all(color: sidebarBg, width: 1.5)),
                                ),
                              ),
                          ],
                        ),
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(u.name, style: GoogleFonts.poppins(color: textCol, fontWeight: FontWeight.bold, fontSize: 13)),
                            if (lastMsg != null)
                              Text(DateFormat('hh:mm a').format(lastMsg.timestamp), style: TextStyle(color: subTextCol, fontSize: 9)),
                          ],
                        ),
                        subtitle: Row(
                          children: [
                            Expanded(
                              child: isTyping
                                  ? Text('Typing...', style: TextStyle(color: primaryColor, fontSize: 11, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic))
                                  : Text(lastMsg != null ? lastMsg.content : 'Requested connection connected.', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: subTextCol, fontSize: 11)),
                            ),
                            if (lastMsg != null && lastMsg.senderId == myErpId) ...[
                              const SizedBox(width: 4),
                              Icon(Icons.done_all, size: 14, color: primaryColor), // read tick
                            ]
                          ],
                        ),
                        onTap: () {
                          setState(() {
                            _selectedConversationId = u.erpId;
                            _isGroupSelected = false;
                          });
                        },
                      );
                    }),
                  ],
                ),
        ),
      ],
    );
  }

  /// REQUESTS TAB
  Widget _buildRequestsTab() {
    final pending = _requestsDb.where((r) => r.status == 'PENDING').toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('Pending Access Requests (${pending.length})', style: GoogleFonts.poppins(color: textCol, fontWeight: FontWeight.bold, fontSize: 14)),
        ),
        Expanded(
          child: pending.isEmpty
              ? Center(child: Text('No pending incoming chat requests.', style: TextStyle(color: subTextCol)))
              : ListView.builder(
                  itemCount: pending.length,
                  itemBuilder: (context, idx) {
                    final req = pending[idx];
                    return Card(
                      color: isDark ? const Color(0xFF202C33) : Colors.white,
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(backgroundImage: NetworkImage(req.sender.avatarUrl), radius: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(req.sender.name, style: GoogleFonts.poppins(color: textCol, fontWeight: FontWeight.bold, fontSize: 13)),
                                      Text('${req.sender.role} • ${req.sender.erpId}', style: TextStyle(color: subTextCol, fontSize: 10)),
                                      Text(req.sender.department, style: TextStyle(color: primaryColor, fontSize: 10, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (req.optionalMessage.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: scaffoldBg, borderRadius: BorderRadius.circular(6)),
                                child: Text('"${req.optionalMessage}"', style: TextStyle(color: textCol, fontSize: 11, fontStyle: FontStyle.italic)),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                                  onPressed: () => _handleRequestAction(req, 'REJECTED'),
                                  child: const Text('Reject'),
                                ),
                                const SizedBox(width: 6),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(foregroundColor: Colors.grey),
                                  onPressed: () => _handleRequestAction(req, 'BLOCKED'),
                                  child: const Text('Block'),
                                ),
                                const SizedBox(width: 6),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                                  onPressed: () => _handleRequestAction(req, 'ACCEPTED'),
                                  child: const Text('Accept', style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
        )
      ],
    );
  }

  /// CONNECT TAB - ERP ID SEARCH
  Widget _buildConnectTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Establish Secure ERP Link', style: GoogleFonts.poppins(color: textCol, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          Text(
            'For security, no student/faculty directory exists. Enter the exact ID to connect.',
            style: TextStyle(color: subTextCol, fontSize: 11),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _erpSearchController,
                  style: TextStyle(color: textCol),
                  decoration: InputDecoration(
                    labelText: 'Enter ERP ID to connect',
                    hintText: 'e.g. FAC-50194, 24634-CM-026',
                    border: const OutlineInputBorder(),
                    fillColor: isDark ? const Color(0xFF202C33) : Colors.white,
                    filled: true,
                    labelStyle: TextStyle(color: primaryColor),
                  ),
                  onSubmitted: (_) => _searchErpId(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: primaryColor),
                icon: const Icon(Icons.search, color: Colors.white),
                onPressed: _searchErpId,
              )
            ],
          ),
          if (_erpSearchError != null) ...[
            const SizedBox(height: 10),
            Text(_erpSearchError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
          ],

          const SizedBox(height: 25),

          if (_searchedUserResult != null) ...[
            Card(
              color: isDark ? const Color(0xFF202C33) : Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    CircleAvatar(
                      backgroundImage: NetworkImage(_searchedUserResult!.avatarUrl),
                      radius: 36,
                    ),
                    const SizedBox(height: 12),
                    Text(_searchedUserResult!.name, style: GoogleFonts.poppins(color: textCol, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('${_searchedUserResult!.role} • ${_searchedUserResult!.erpId}', style: TextStyle(color: subTextCol, fontSize: 11)),
                    Text(_searchedUserResult!.department, style: TextStyle(color: primaryColor, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(color: _searchedUserResult!.isOnline ? Colors.green : Colors.grey, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text(_searchedUserResult!.isOnline ? 'Online' : 'Offline', style: TextStyle(color: subTextCol, fontSize: 11)),
                      ],
                    ),
                    const Divider(height: 25),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                      label: const Text('Send Access Request', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      onPressed: _sendConnectionRequest,
                    )
                  ],
                ),
              ),
            ),
          ] else ...[
            // Helpful hints
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: primaryColor.withOpacity(0.05), borderRadius: BorderRadius.circular(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('💡 Quick ID Reference for Testing:', style: GoogleFonts.poppins(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 6),
                  const Text('• Faculty ID: FAC-50194 (Prof. Rajesh Kumar)', style: TextStyle(fontSize: 11)),
                  const Text('• Student ID: 24634-CM-026 (Rohan Sharma)', style: TextStyle(fontSize: 11)),
                  const Text('• Parent ID: PAR-2031 (Suresh Sharma)', style: TextStyle(fontSize: 11)),
                  const Text('• HOD ID: HOD-3021 (Dr. Vikram Sen)', style: TextStyle(fontSize: 11)),
                ],
              ),
            ),
          ]
        ],
      ),
    );
  }

  /// STATUSES (STORIES) TAB
  Widget _buildStatusesTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: Stack(
            children: [
              CircleAvatar(
                backgroundColor: primaryColor.withOpacity(0.2),
                child: Text(myName[0].toUpperCase(), style: TextStyle(color: primaryColor)),
              ),
              Positioned(
                right: -2, bottom: -2,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                  child: const Icon(Icons.add, size: 12, color: Colors.white),
                ),
              )
            ],
          ),
          title: Text('My Status', style: GoogleFonts.poppins(color: textCol, fontWeight: FontWeight.bold, fontSize: 13)),
          subtitle: const Text('Tap to write text status updates', style: TextStyle(fontSize: 11)),
          onTap: _addTextStatus,
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 12, bottom: 4),
          child: Text('Recent Updates (24h Expiry)', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 11)),
        ),
        Expanded(
          child: _statusesDb.isEmpty
              ? Center(child: Text('No statuses posted in the last 24h.', style: TextStyle(color: subTextCol)))
              : ListView.builder(
                  itemCount: _statusesDb.length,
                  itemBuilder: (context, idx) {
                    final status = _statusesDb[idx];
                    return ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: primaryColor, width: 2)),
                        child: CircleAvatar(backgroundImage: NetworkImage(status.user.avatarUrl)),
                      ),
                      title: Text(status.user.name, style: GoogleFonts.poppins(color: textCol, fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: Text(DateFormat('hh:mm a').format(status.timestamp), style: const TextStyle(fontSize: 11)),
                      onTap: () {
                        // Show status modal
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                            contentPadding: EdgeInsets.zero,
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  leading: CircleAvatar(backgroundImage: NetworkImage(status.user.avatarUrl)),
                                  title: Text(status.user.name, style: TextStyle(color: textCol, fontWeight: FontWeight.bold)),
                                  subtitle: Text('${status.user.role} • ERP Status', style: TextStyle(color: subTextCol, fontSize: 10)),
                                ),
                                if (status.type == 'TEXT')
                                  Container(
                                    width: double.infinity,
                                    color: primaryColor.withOpacity(0.08),
                                    padding: const EdgeInsets.all(32),
                                    child: Text(
                                      status.content,
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.poppins(color: textCol, fontSize: 16, fontWeight: FontWeight.w500),
                                    ),
                                  )
                                else
                                  Image.network(status.content),
                                Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Views: ${status.viewers.length + 1} students', style: TextStyle(color: subTextCol, fontSize: 11)),
                                      Text('Reaction: 👏', style: TextStyle(color: primaryColor, fontSize: 11)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
        )
      ],
    );
  }

  /// CALLS LOG TAB
  Widget _buildCallsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Simulated Call Logs', style: GoogleFonts.poppins(color: textCol, fontWeight: FontWeight.bold, fontSize: 14)),
        ),
        Expanded(
          child: _callLogsDb.isEmpty
              ? Center(child: Text('No call logs.', style: TextStyle(color: subTextCol)))
              : ListView.builder(
                  itemCount: _callLogsDb.length,
                  itemBuilder: (context, idx) {
                    final log = _callLogsDb[idx];
                    final ErpUser p = log['partner'];
                    return ListTile(
                      leading: CircleAvatar(backgroundImage: NetworkImage(p.avatarUrl)),
                      title: Text(p.name, style: GoogleFonts.poppins(color: textCol, fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: Row(
                        children: [
                          Icon(
                            log['outgoing'] ? Icons.call_made : Icons.call_received,
                            size: 14,
                            color: log['missed'] ? Colors.red : Colors.green,
                          ),
                          const SizedBox(width: 4),
                          Text(log['time'], style: const TextStyle(fontSize: 11)),
                        ],
                      ),
                      trailing: IconButton(
                        icon: Icon(log['type'] == 'VIDEO' ? Icons.videocam : Icons.call, color: primaryColor),
                        onPressed: () => _initiateCall(p.erpId, log['type'] == 'VIDEO'),
                      ),
                    );
                  },
                ),
        )
      ],
    );
  }

  /// MODERATE PANEL (Admin Only)
  Widget _buildModerateTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ERP Abuse & Moderation Panel', style: GoogleFonts.poppins(color: textCol, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 4),
          const Text('Monitor active calls, moderate servers, and review abuse report lists.', style: TextStyle(fontSize: 10)),
          const SizedBox(height: 15),
          
          // Stats Row
          Row(
            children: [
              Expanded(
                child: Card(
                  color: isDark ? const Color(0xFF202C33) : Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        Text('Active Users', style: TextStyle(color: subTextCol, fontSize: 10)),
                        const SizedBox(height: 4),
                        Text('148', style: GoogleFonts.poppins(color: primaryColor, fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Card(
                  color: isDark ? const Color(0xFF202C33) : Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        Text('Call Minutes', style: TextStyle(color: subTextCol, fontSize: 10)),
                        const SizedBox(height: 4),
                        Text('1,240', style: GoogleFonts.poppins(color: Colors.blueAccent, fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),
          Text('Server Storage Monitoring', style: GoogleFonts.poppins(color: textCol, fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 6),
          LinearProgressIndicator(value: 0.42, backgroundColor: borderCol, color: primaryColor),
          const SizedBox(height: 4),
          Text('4.2 GB / 10 GB (42% used)', style: TextStyle(color: subTextCol, fontSize: 10)),

          const SizedBox(height: 20),
          Text('Abuse Reports Log:', style: GoogleFonts.poppins(color: textCol, fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 8),

          ..._abuseReportsDb.map((rep) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04), borderRadius: BorderRadius.circular(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Reported: ${rep['reported']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                      Text(rep['time'], style: TextStyle(color: subTextCol, fontSize: 9)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Reporter: ${rep['reporter']}', style: TextStyle(color: subTextCol, fontSize: 11)),
                  Text('Reason: "${rep['reason']}"', style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        style: TextButton.styleFrom(foregroundColor: Colors.red, padding: EdgeInsets.zero, minimumSize: const Size(50, 30)),
                        onPressed: () {
                          setState(() {
                            _blockedUsersDb.add(rep['reported']);
                            _abuseReportsDb.clear();
                          });
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User blocked from ERP server.')));
                        },
                        child: const Text('Ban User', style: TextStyle(fontSize: 11)),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        style: TextButton.styleFrom(foregroundColor: Colors.grey, padding: EdgeInsets.zero, minimumSize: const Size(50, 30)),
                        onPressed: () {
                          setState(() {
                            _abuseReportsDb.clear();
                          });
                        },
                        child: const Text('Dismiss', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  )
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  /// EMPTY STATE
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_person_rounded, size: 64, color: primaryColor.withOpacity(0.4)),
          const SizedBox(height: 15),
          Text('ERP Connect secure Messenger', style: GoogleFonts.poppins(color: textCol, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text('Chat with faculty, students, & parents.', style: TextStyle(color: subTextCol, fontSize: 12)),
          const SizedBox(height: 2),
          Text('End-to-End Encrypted ERP ID connections.', style: TextStyle(color: subTextCol, fontSize: 11, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  /// ACTIVE CHAT WINDOW LAYOUT
  Widget _buildChatWindow() {
    ErpUser? partner;
    ErpGroup? group;

    if (_isGroupSelected) {
      group = _groupsDb.firstWhere((g) => g.id == _selectedConversationId);
    } else {
      partner = _usersDb.firstWhere((u) => u.erpId == _selectedConversationId);
    }

    final String chatTitle = group != null ? group.name : partner!.name;
    final String chatSubtitle = group != null ? '${group.memberIds.length} members' : partner!.lastSeen;
    final String avatar = group != null ? group.iconUrl : partner!.avatarUrl;

    // Filter messages for active screen
    final conversationMessages = _isGroupSelected
        ? group!.messages
        : _messagesDb.where((m) =>
            (m.senderId == myErpId && m.receiverId == partner!.erpId) ||
            (m.senderId == partner!.erpId && m.receiverId == myErpId)
          ).toList();

    // Starred or search filtered
    final displayMessages = conversationMessages.where((m) {
      if (_isSearchingMessages && _messageSearchQuery.isNotEmpty) {
        return m.content.toLowerCase().contains(_messageSearchQuery.toLowerCase());
      }
      return true;
    }).toList();

    return Column(
      children: [
        // 1. Chat Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: isDark ? const Color(0xFF202C33) : const Color(0xFFF0F2F5),
          child: Row(
            children: [
              // Mobile Back Arrow
              if (MediaQuery.of(context).size.width <= 700)
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  color: primaryColor,
                  onPressed: () {
                    setState(() {
                      _selectedConversationId = null;
                    });
                  },
                ),

              CircleAvatar(backgroundImage: NetworkImage(avatar), radius: 20),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _showRightPanel = !_showRightPanel),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(chatTitle, style: GoogleFonts.poppins(color: textCol, fontWeight: FontWeight.bold, fontSize: 13)),
                      Text(chatSubtitle, style: TextStyle(color: subTextCol, fontSize: 10)),
                    ],
                  ),
                ),
              ),

              // Actions
              IconButton(
                icon: const Icon(Icons.search, size: 20),
                color: subTextCol,
                onPressed: () {
                  setState(() {
                    _isSearchingMessages = !_isSearchingMessages;
                    if (!_isSearchingMessages) _messageSearchQuery = '';
                  });
                },
              ),
              if (!_isGroupSelected) ...[
                IconButton(
                  icon: const Icon(Icons.call, size: 20),
                  color: primaryColor,
                  onPressed: () => _initiateCall(partner!.erpId, false),
                ),
                IconButton(
                  icon: const Icon(Icons.videocam, size: 20),
                  color: primaryColor,
                  onPressed: () => _initiateCall(partner!.erpId, true),
                ),
              ],
              IconButton(
                icon: const Icon(Icons.info_outline, size: 20),
                color: subTextCol,
                onPressed: () => setState(() => _showRightPanel = !_showRightPanel),
              ),
            ],
          ),
        ),

        // Message Search Bar toggle
        if (_isSearchingMessages)
          Container(
            padding: const EdgeInsets.all(8),
            color: sidebarBg,
            child: TextField(
              controller: _messageSearchController,
              autofocus: true,
              style: TextStyle(color: textCol),
              decoration: InputDecoration(
                hintText: 'Search in conversation...',
                prefixIcon: const Icon(Icons.search, size: 16),
                suffixIcon: IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () {
                  setState(() {
                    _isSearchingMessages = false;
                    _messageSearchQuery = '';
                    _messageSearchController.clear();
                  });
                }),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (val) {
                setState(() {
                  _messageSearchQuery = val;
                });
              },
            ),
          ),

        // 2. Chat Messages Area
        Expanded(
          child: displayMessages.isEmpty
              ? Center(child: Text(_isSearchingMessages ? 'No matching messages found.' : 'No messages here yet.', style: TextStyle(color: subTextCol)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  physics: const BouncingScrollPhysics(),
                  itemCount: displayMessages.length,
                  itemBuilder: (context, idx) {
                    final msg = displayMessages[idx];
                    final isMe = msg.senderId == myErpId;
                    return _buildMessageBubble(msg, isMe);
                  },
                ),
        ),

        // 3. Reply Context Bar
        if (_replyMessageContext != null)
          Container(
            color: isDark ? const Color(0xFF1F2937) : Colors.grey[200],
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.reply, size: 18, color: primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Replying to: ${_replyMessageContext!.content}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: textCol, fontSize: 11),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () => setState(() => _replyMessageContext = null),
                )
              ],
            ),
          ),

        // 4. Voice Note Recording Preview Bar
        if (_recordedAudioPreviewUrl != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: sidebarBg,
            child: Row(
              children: [
                Icon(Icons.mic, color: primaryColor),
                const SizedBox(width: 10),
                Expanded(child: Text('Voice Note Simulated (0:${_recordingSeconds.toString().padLeft(2, '0')})', style: TextStyle(color: textCol, fontSize: 12))),
                TextButton(
                  onPressed: () => setState(() {
                    _recordedAudioPreviewUrl = null;
                    _recordingSeconds = 0;
                  }),
                  child: const Text('Delete', style: TextStyle(color: Colors.red)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                  onPressed: _sendVoiceNote,
                  child: const Text('Send', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),

        // 5. Chat Input Bar
        Container(
          padding: const EdgeInsets.all(10),
          color: isDark ? const Color(0xFF202C33) : const Color(0xFFF0F2F5),
          child: _isRecordingAudio
              ? Row(
                  children: [
                    const Icon(Icons.fiber_manual_record, color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Recording simulated voice... 0:${_recordingSeconds.toString().padLeft(2, '0')}',
                      style: GoogleFonts.poppins(color: textCol, fontSize: 12),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => _stopAudioRecording(cancel: true),
                      child: const Text('Cancel', style: TextStyle(color: Colors.red)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.stop, color: Colors.red),
                      onPressed: () => _stopAudioRecording(cancel: false),
                    )
                  ],
                )
              : Row(
                  children: [
                    // Attachments Drawer Button
                    IconButton(
                      icon: const Icon(Icons.attach_file),
                      color: subTextCol,
                      onPressed: () => _showAttachmentDrawer(),
                    ),

                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        style: TextStyle(color: textCol, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Type a secure message...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                          fillColor: isDark ? const Color(0xFF2A3942) : Colors.white,
                          filled: true,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),

                    const SizedBox(width: 6),
                    
                    // Voice Recorder or Send Trigger
                    _messageController.text.isEmpty
                        ? IconButton(
                            icon: const Icon(Icons.mic),
                            color: primaryColor,
                            onPressed: _startAudioRecording,
                          )
                        : IconButton(
                            icon: const Icon(Icons.send),
                            color: primaryColor,
                            onPressed: _sendMessage,
                          ),
                  ],
                ),
        ),
      ],
    );
  }

  /// ATTACHMENT MENU DRAWER
  void _showAttachmentDrawer() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Secure ERP File Attachments', style: GoogleFonts.poppins(color: textCol, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            GridView(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.1,
              ),
              children: [
                _buildAttachmentCard(Icons.assignment, 'Assignment', Colors.orange, () => _sendErpAttachment('ASSIGNMENT')),
                _buildAttachmentCard(Icons.analytics, 'Marks Memo', Colors.blue, () => _sendErpAttachment('MARKS')),
                _buildAttachmentCard(Icons.receipt_long, 'Fee Receipt', Colors.green, () => _sendErpAttachment('FEE')),
                _buildAttachmentCard(Icons.calendar_month, 'Timetable', Colors.purple, () => _sendErpAttachment('TIMETABLE')),
                _buildAttachmentCard(Icons.sick, 'Leave Slip', Colors.red, () => _sendErpAttachment('LEAVE')),
                _buildAttachmentCard(Icons.image, 'Photo/Media', Colors.teal, () {
                  _sendAttachment('IMAGE', 'Mock_Photo.jpg', '420 KB');
                  Navigator.pop(context);
                }),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentCard(IconData icon, String title, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        color: isDark ? Colors.white10 : Colors.black.withOpacity(0.02),
        elevation: 0,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(backgroundColor: color.withOpacity(0.2), child: Icon(icon, color: color)),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(color: textCol, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  /// MESSAGE BUBBLES LAYOUT
  Widget _buildMessageBubble(ErpMessage msg, bool isMe) {
    final bubbleColor = isMe ? bubbleSent : bubbleRecv;
    final alignment = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleBorder = isMe
        ? const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12), topRight: Radius.circular(12))
        : const BorderRadius.only(topLeft: Radius.circular(12), bottomRight: Radius.circular(12), topRight: Radius.circular(12));

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          // Reply quote bubble inside bubble
          GestureDetector(
            onLongPress: () {
              // Message actions bottom sheet
              _showMessageActions(msg);
            },
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.all(10),
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.65),
              decoration: BoxDecoration(color: bubbleColor, borderRadius: bubbleBorder),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Reply reference
                  if (msg.replyToContent != null) ...[
                    Container(
                      padding: const EdgeInsets.all(6),
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.05),
                        border: Border(left: BorderSide(color: primaryColor, width: 3)),
                      ),
                      child: Text(msg.replyToContent!, style: TextStyle(color: subTextCol, fontSize: 10, fontStyle: FontStyle.italic)),
                    ),
                  ],

                  // Types of Messages Render
                  if (msg.type == 'TEXT')
                    Text(msg.content, style: TextStyle(color: textCol, fontSize: 12))
                  else if (msg.type == 'VOICE')
                    _buildVoicePlayer(msg)
                  else if (msg.type == 'IMAGE')
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network('https://images.unsplash.com/photo-1517245386807-bb43f82c33c4?w=400')),
                        const SizedBox(height: 4),
                        Text(msg.content, style: TextStyle(color: textCol, fontSize: 11)),
                      ],
                    )
                  else if (msg.type == 'FILE' || msg.type == 'ERP_DOC')
                    _buildFileAttachmentBubble(msg),

                  // Message timestamp/read status footer
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(DateFormat('hh:mm a').format(msg.timestamp), style: TextStyle(color: subTextCol, fontSize: 8)),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.done_all, size: 12, color: primaryColor), // read seen tick
                      ]
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoicePlayer(ErpMessage msg) {
    double playSpeed = 1.0;
    return StatefulBuilder(
      builder: (context, setBubbleState) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.play_circle_fill, size: 28),
            color: primaryColor,
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Playing voice memo...')));
            },
          ),
          // Waveform placeholder
          Expanded(
            child: Container(
              height: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(15, (i) => Container(
                  width: 2,
                  height: (i % 3 + 1) * 4.0 + 2.0,
                  color: primaryColor.withOpacity(0.5),
                )),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              setBubbleState(() {
                if (playSpeed == 1.0) {
                  playSpeed = 1.5;
                } else if (playSpeed == 1.5) {
                  playSpeed = 2.0;
                } else {
                  playSpeed = 1.0;
                }
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Text('${playSpeed}x', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileAttachmentBubble(ErpMessage msg) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.04), borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(msg.type == 'ERP_DOC' ? Icons.description_rounded : Icons.insert_drive_file, color: primaryColor, size: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(msg.attachmentName ?? 'Document.pdf', style: TextStyle(color: textCol, fontWeight: FontWeight.bold, fontSize: 11), overflow: TextOverflow.ellipsis),
                Text(msg.attachmentSize ?? 'Unknown size', style: TextStyle(color: subTextCol, fontSize: 9)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.download_rounded, size: 18),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Downloading ${msg.attachmentName}...')));
            },
          )
        ],
      ),
    );
  }

  /// MESSAGE BUBBLE LONG PRESS ACTIONS
  void _showMessageActions(ErpMessage msg) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('Reply'),
              onTap: () {
                setState(() {
                  _replyMessageContext = msg;
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.star_border),
              title: const Text('Star Message'),
              onTap: () {
                setState(() {
                  msg.isStarred = true;
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Message Starred.')));
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy Text'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: msg.content));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Message copied to clipboard.')));
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Message', style: TextStyle(color: Colors.red)),
              onTap: () {
                setState(() {
                  _messagesDb.removeWhere((m) => m.id == msg.id);
                });
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// RIGHT USER DETAILS PANEL
  Widget _buildRightDetailPanel() {
    ErpUser? partner;
    ErpGroup? group;

    if (_isGroupSelected) {
      group = _groupsDb.firstWhere((g) => g.id == _selectedConversationId);
    } else {
      partner = _usersDb.firstWhere((u) => u.erpId == _selectedConversationId);
    }

    final String name = group != null ? group.name : partner!.name;
    final String id = group != null ? 'Group ID: ${group.id}' : partner!.erpId;
    final String sub = group != null ? group.description : '${partner!.role} • ${partner.department}';
    final String avatar = group != null ? group.iconUrl : partner!.avatarUrl;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Connection Info', style: GoogleFonts.poppins(color: textCol, fontWeight: FontWeight.bold, fontSize: 14)),
              IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _showRightPanel = false)),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                CircleAvatar(backgroundImage: NetworkImage(avatar), radius: 48),
                const SizedBox(height: 12),
                Text(name, textAlign: TextAlign.center, style: GoogleFonts.poppins(color: textCol, fontSize: 15, fontWeight: FontWeight.bold)),
                Text(id, style: TextStyle(color: subTextCol, fontSize: 11)),
                const SizedBox(height: 6),
                Text(sub, textAlign: TextAlign.center, style: TextStyle(color: primaryColor, fontSize: 11, fontWeight: FontWeight.bold)),
                const Divider(height: 30),

                // Encryption notification
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: primaryColor.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      Icon(Icons.lock, color: primaryColor, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'End-to-End Encrypted. Messages are locked using secure role credentials.',
                          style: TextStyle(fontSize: 10),
                        ),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Actions List
                Card(
                  color: isDark ? const Color(0xFF202C33) : Colors.white,
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.star_rate_rounded, color: Colors.orangeAccent),
                        title: const Text('Starred Messages', style: TextStyle(fontSize: 12)),
                        onTap: () {
                          // ShowStarred dialog
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opening starred catalog...')));
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.archive_outlined),
                        title: const Text('Archive Chat', style: TextStyle(fontSize: 12)),
                        onTap: () {
                          setState(() {
                            _selectedConversationId = null;
                          });
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.block, color: Colors.red),
                        title: const Text('Block User', style: TextStyle(fontSize: 12, color: Colors.red)),
                        onTap: () {
                          setState(() {
                            _blockedUsersDb.add(id);
                            _selectedConversationId = null;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User connection blocked.')));
                        },
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
        )
      ],
    );
  }

  /// WEBRTC CALL OVERLAY COMPONENT
  Widget _buildCallOverlay() {
    final partner = _usersDb.firstWhere((u) => u.erpId == _callPartnerId, orElse: () => _usersDb[0]);
    return Container(
      color: Colors.black.withOpacity(0.92),
      width: double.infinity,
      height: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          CircleAvatar(backgroundImage: NetworkImage(partner.avatarUrl), radius: 56),
          const SizedBox(height: 20),
          Text(partner.name, style: GoogleFonts.poppins(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          Text('${_isVideoCall ? "Video" : "Voice"} Calling (${partner.erpId})', style: const TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(15)),
            child: Text(
              _callState,
              style: GoogleFonts.poppins(color: primaryColor, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),

          if (_callState == 'Connected') ...[
            const SizedBox(height: 40),
            // Codec & Network Stats Panel
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(15)),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('WebRTC Codec:', style: TextStyle(color: Colors.white70, fontSize: 11)),
                      Text(_isVideoCall ? 'VP9 (HD)' : 'Opus (24kHz)', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Network Quality:', style: TextStyle(color: Colors.white70, fontSize: 11)),
                      Text(
                        _networkQuality,
                        style: TextStyle(
                          color: _networkQuality == 'Excellent' || _networkQuality == 'Good' ? Colors.green : Colors.orange,
                          fontSize: 11, fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Bitrate Status:', style: TextStyle(color: Colors.white70, fontSize: 11)),
                      Text('${_callBitrateKbps.toStringAsFixed(1)} kbps', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Usage metrics:', style: TextStyle(color: Colors.white70, fontSize: 11)),
                      Text('${_dataConsumedMb.toStringAsFixed(2)} MB', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Divider(color: Colors.white24, height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Low Data Saver:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      Switch(
                        value: _callDataSaver,
                        activeColor: primaryColor,
                        onChanged: (val) {
                          setState(() {
                            _callDataSaver = val;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          const Spacer(),
          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white24,
                child: IconButton(
                  icon: const Icon(Icons.mic_off, color: Colors.white),
                  onPressed: () {},
                ),
              ),
              const SizedBox(width: 25),
              CircleAvatar(
                radius: 32,
                backgroundColor: Colors.red,
                child: IconButton(
                  icon: const Icon(Icons.call_end, color: Colors.white, size: 28),
                  onPressed: _endCall,
                ),
              ),
              const SizedBox(width: 25),
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white24,
                child: IconButton(
                  icon: const Icon(Icons.volume_up, color: Colors.white),
                  onPressed: () {},
                ),
              ),
            ],
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
