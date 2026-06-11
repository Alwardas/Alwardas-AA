import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../../core/providers/theme_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../theme/theme_constants.dart';
import '../../../core/api_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ErpConnectScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const ErpConnectScreen({super.key, required this.userData});

  @override
  State<ErpConnectScreen> createState() => _ErpConnectScreenState();
}

class _ErpConnectScreenState extends State<ErpConnectScreen> {
  // Theme state helpers
  late bool isDark;
  late Color primaryColor;
  late Color scaffoldBg;
  late Color chatBg;
  late Color sidebarBg;
  late Color bubbleSent;
  late Color bubbleSentText;
  late Color bubbleRecv;
  late Color bubbleRecvText;
  late Color borderCol;
  late Color textCol;
  late Color subTextCol;

  // Logged-in user information
  late String myErpId;
  late String myName;
  late String myRole;
  late String myDept;

  // Sidebar navigation state (0: Chats, 1: Requests, 2: Connect, 3: Calls, 4: Moderate)
  int _activeSidebarTab = 0;
  String? _selectedConversationId;
  bool _isGroupSelected = false;
  bool _showRightPanel = false;

  // Global search & filtering
  final TextEditingController _globalSearchController = TextEditingController();
  final TextEditingController _messageSearchController = TextEditingController();
  bool _isSearchingMessages = false;
  String _messageSearchQuery = '';

  // ERP ID lookup fields
  final TextEditingController _erpSearchController = TextEditingController();
  String? _erpSearchError;
  dynamic _searchedUserResult;

  // Chat input controller
  final TextEditingController _messageController = TextEditingController();
  dynamic _replyMessageContext;

  // WebRTC simulated audio notes state
  bool _isRecordingAudio = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;
  String? _recordedAudioPreviewUrl;

  // Simulated WebRTC call overlay state
  bool _isCallActive = false;
  bool _isVideoCall = false;
  bool _isIncomingCall = false;
  String? _callPartnerId;
  String _callState = 'Ringing';
  bool _callDataSaver = false;
  String _networkQuality = 'Excellent';
  double _callBitrateKbps = 1500.0;
  double _dataConsumedMb = 0.0;
  Timer? _callStatsTimer;

  // API database state
  List<dynamic> _conversations = [];
  List<dynamic> _requests = [];
  List<dynamic> _messages = [];
  List<String> _blockedUsers = [];
  
  bool _isLoadingConversations = false;
  bool _isLoadingRequests = false;
  bool _isLoadingMessages = false;

  // New Snapchat mode & local renaming state variables
  Map<String, String> _customAliases = {};
  SharedPreferences? _prefs;
  bool _isDisappearingMode = false;
  final Set<String> _disappearedMessageIds = {};
  final Set<String> _blueTickMessageIds = {};
  final Map<String, Timer> _disappearingTimers = {};
  final Set<String> _typingPartners = {};
  Timer? _typingSimulationTimer;

  // Periodic polling timers
  Timer? _conversationsTimer;
  Timer? _requestsTimer;
  Timer? _messagesTimer;

  // Local-only simulated logs
  final List<Map<String, dynamic>> _callLogsDb = [];
  final List<Map<String, dynamic>> _abuseReportsDb = [];

  @override
  void initState() {
    super.initState();
    _initUserInfo();
    _fetchConversations();
    _fetchRequests();
    _fetchBlockedUsers();
    _loadAliases();

    // Start periodic background updates for notifications/chats list
    _conversationsTimer = Timer.periodic(const Duration(seconds: 4), (_) => _fetchConversations(silent: true));
    _requestsTimer = Timer.periodic(const Duration(seconds: 6), (_) => _fetchRequests(silent: true));
    
    // Seed initial call logs dynamically for realistic feel
    _seedLocalCallLogs();

    // typing simulation timer
    _typingSimulationTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (_selectedConversationId != null && !_isGroupSelected) {
        final currentPartner = _selectedConversationId!;
        if (mounted) {
          setState(() {
            _typingPartners.add(currentPartner);
          });
        }
        Timer(const Duration(seconds: 4), () {
          if (mounted) {
            setState(() {
              _typingPartners.remove(currentPartner);
            });
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _conversationsTimer?.cancel();
    _requestsTimer?.cancel();
    _messagesTimer?.cancel();
    _recordingTimer?.cancel();
    _callStatsTimer?.cancel();
    _typingSimulationTimer?.cancel();
    for (final timer in _disappearingTimers.values) {
      timer.cancel();
    }
    _globalSearchController.dispose();
    _messageSearchController.dispose();
    _erpSearchController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _initUserInfo() {
    myRole = widget.userData['role'] ?? 'Student';
    myDept = widget.userData['branch'] ?? widget.userData['department'] ?? 'CSE';
    
    if (widget.userData['id'] != null && widget.userData['id'].toString().length > 5) {
      myErpId = widget.userData['login_id']?.toString() ?? widget.userData['id']?.toString() ?? 'ERP-ID';
    } else {
      myErpId = widget.userData['id']?.toString() ?? 'ERP-ID';
    }
    myName = widget.userData['full_name'] ?? 'ERP User';
  }

  // --- LOCAL ALIAS & RENAME / DELETE IMPLEMENTATION ---

  Future<void> _loadAliases() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final keys = _prefs!.getKeys();
      final Map<String, String> loaded = {};
      for (final key in keys) {
        if (key.startsWith('alias_${myErpId}_')) {
          final partnerId = key.substring('alias_${myErpId}_'.length);
          final val = _prefs!.getString(key);
          if (val != null) {
            loaded[partnerId] = val;
          }
        }
      }
      setState(() {
        _customAliases = loaded;
      });
    } catch (e) {
      debugPrint("Error loading shared preferences: $e");
    }
  }

  Future<void> _saveAlias(String partnerId, String newName) async {
    if (_prefs == null) return;
    final key = 'alias_${myErpId}_$partnerId';
    if (newName.trim().isEmpty) {
      await _prefs!.remove(key);
      setState(() {
        _customAliases.remove(partnerId);
      });
    } else {
      await _prefs!.setString(key, newName.trim());
      setState(() {
        _customAliases[partnerId] = newName.trim();
      });
    }
    _fetchConversations(silent: true);
  }

  void _showRenameDialog(String partnerId, String currentName) {
    final controller = TextEditingController(text: _customAliases[partnerId] ?? currentName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Contact'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Custom Alias',
            hintText: 'Enter new name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _saveAlias(partnerId, ''); // Clear alias
              Navigator.pop(context);
            },
            child: const Text('Reset', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              _saveAlias(partnerId, controller.text);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteConversation(String partnerId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chat?'),
        content: const Text('Are you sure you want to delete this conversation? This will clear all messages and disconnect the link.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final response = await http.delete(
        Uri.parse('${ApiConstants.baseUrl}/api/chat/conversations/$partnerId?user_id=$myErpId'),
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conversation deleted successfully.')),
        );
        setState(() {
          _selectedConversationId = null;
          _showRightPanel = false;
        });
        _fetchConversations();
      }
    } catch (e) {
      debugPrint("Error deleting conversation: $e");
    }
  }

  void _seedLocalCallLogs() {
    _callLogsDb.addAll([
      {
        'name': 'Prof. Rajesh Kumar',
        'role': 'Faculty',
        'erpId': 'FAC-50194',
        'type': 'VOICE',
        'outgoing': false,
        'missed': false,
        'time': 'Today, 2:30 PM'
      },
      {
        'name': 'Dr. Vikram Sen',
        'role': 'HOD',
        'erpId': 'HOD-3021',
        'type': 'VIDEO',
        'outgoing': true,
        'missed': false,
        'time': 'Yesterday, 11:15 AM'
      }
    ]);
  }

  // --- API CALLS INTEGRATION ---

  Future<void> _fetchConversations({bool silent = false}) async {
    if (myErpId.isEmpty) return;
    if (!silent) setState(() => _isLoadingConversations = true);
    
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.chatConversations}?user_id=$myErpId'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _conversations = data;
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching conversations: $e");
    } finally {
      if (mounted && !silent) setState(() => _isLoadingConversations = false);
    }
  }

  Future<void> _fetchRequests({bool silent = false}) async {
    if (myErpId.isEmpty) return;
    if (!silent) setState(() => _isLoadingRequests = true);

    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.chatRequests}?user_id=$myErpId'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _requests = data;
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching requests: $e");
    } finally {
      if (mounted && !silent) setState(() => _isLoadingRequests = false);
    }
  }

  Future<void> _fetchBlockedUsers() async {
    if (myErpId.isEmpty) return;
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.chatBlocks}?user_id=$myErpId'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _blockedUsers = List<String>.from(data);
        });
      }
    } catch (e) {
      debugPrint("Error fetching blocked users: $e");
    }
  }

  Future<void> _fetchMessages({bool silent = false}) async {
    if (_selectedConversationId == null || myErpId.isEmpty) return;
    if (!silent) setState(() => _isLoadingMessages = true);

    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.chatMessagesForPartner(_selectedConversationId!)}?user_id=$myErpId'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        // Snapchat disappearing mode logic
        if (_isDisappearingMode && !_isGroupSelected) {
          for (final msg in data) {
            final msgId = msg['id'].toString();
            final isMe = msg['senderId'] == myErpId;
            
            if (!isMe) {
              // Received message: starts disappearing timer immediately when fetched/displayed
              if (!_disappearingTimers.containsKey(msgId) && !_disappearedMessageIds.contains(msgId)) {
                _disappearingTimers[msgId] = Timer(const Duration(seconds: 8), () {
                  if (mounted) {
                    setState(() {
                      _disappearedMessageIds.add(msgId);
                    });
                    _deleteChatMessage(msgId, false); // clear from DB
                  }
                });
              }
            } else {
              // Sent message: blue ticks turn after 3s, disappears after 8s
              if (!_blueTickMessageIds.contains(msgId) && !_disappearingTimers.containsKey('${msgId}_ticks') && !_disappearedMessageIds.contains(msgId)) {
                _disappearingTimers['${msgId}_ticks'] = Timer(const Duration(seconds: 3), () {
                  if (mounted) {
                    setState(() {
                      _blueTickMessageIds.add(msgId);
                    });
                  }
                });
                _disappearingTimers[msgId] = Timer(const Duration(seconds: 8), () {
                  if (mounted) {
                    setState(() {
                      _disappearedMessageIds.add(msgId);
                    });
                    _deleteChatMessage(msgId, false); // clear from DB
                  }
                });
              }
            }
          }
        }

        if (mounted) {
          setState(() {
            _messages = data;
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching messages: $e");
    } finally {
      if (mounted && !silent) setState(() => _isLoadingMessages = false);
    }
  }

  void _onConversationSelected(String id, bool isGroup) {
    _messagesTimer?.cancel();
    for (final timer in _disappearingTimers.values) {
      timer.cancel();
    }
    _disappearingTimers.clear();

    setState(() {
      _selectedConversationId = id;
      _isGroupSelected = isGroup;
      _messages = [];
      _isDisappearingMode = false;
    });
    
    _fetchMessages();
    
    // Start periodic messages polling (3s interval)
    _messagesTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _fetchMessages(silent: true);
    });
  }

  Future<void> _searchErpId() async {
    final query = _erpSearchController.text.trim();
    if (query.isEmpty) return;

    if (query.toLowerCase() == myErpId.toLowerCase()) {
      setState(() {
        _searchedUserResult = null;
        _erpSearchError = 'You cannot connect with your own ERP ID.';
      });
      return;
    }

    setState(() {
      _searchedUserResult = null;
      _erpSearchError = null;
    });

    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.chatSearch}?erp_id=$query&user_id=$myErpId'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _searchedUserResult = data;
        });
      } else {
        setState(() {
          _erpSearchError = 'No user found with the exact ERP ID: "$query"';
        });
      }
    } catch (e) {
      setState(() {
        _erpSearchError = 'Failed to execute look up. Verify backend services.';
      });
    }
  }

  Future<void> _sendConnectionRequest() async {
    if (_searchedUserResult == null) return;
    
    final body = {
      'sender_id': myErpId,
      'receiver_id': _searchedUserResult['loginId'],
      'optional_message': 'Connection request from $myName ($myRole)',
    };

    try {
      final response = await http.post(
        Uri.parse(ApiConstants.chatRequests),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Access Request sent successfully!')),
        );
        setState(() {
          _searchedUserResult = null;
          _erpSearchController.clear();
        });
        _fetchRequests();
      } else {
        final err = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err['message'] ?? 'Failed to send request.')),
        );
      }
    } catch (e) {
      debugPrint("Error sending request: $e");
    }
  }

  Future<void> _handleRequestAction(dynamic req, String action) async {
    final body = {
      'user_id': myErpId,
      'action': action,
    };

    try {
      final response = await http.post(
        Uri.parse(ApiConstants.respondChatRequest(req['id'])),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection request $action')),
        );
        _fetchRequests();
        _fetchConversations();
        
        if (action == 'ACCEPTED') {
          _onConversationSelected(req['senderId'], false);
          setState(() {
            _activeSidebarTab = 0; // go back to chats
          });
        }
      }
    } catch (e) {
      debugPrint("Error responding to request: $e");
    }
  }

  Future<void> _sendChatMessage(String content, {String type = 'TEXT', String? attachmentName, String? attachmentSize}) async {
    if (_selectedConversationId == null || myErpId.isEmpty) return;

    final body = {
      'sender_id': myErpId,
      'receiver_id': _selectedConversationId!,
      'content': content,
      'message_type': type,
      'attachment_url': '',
      'attachment_name': attachmentName ?? '',
      'attachment_size': attachmentSize ?? '',
      'reply_to_id': _replyMessageContext?['id'],
      'reply_to_content': _replyMessageContext?['content'],
    };

    setState(() {
      _replyMessageContext = null;
    });

    try {
      final response = await http.post(
        Uri.parse(ApiConstants.chatMessages),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        _fetchMessages(silent: true);
        _fetchConversations(silent: true);
      }
    } catch (e) {
      debugPrint("Error sending message: $e");
    }
  }

  Future<void> _createGroupSubmit(String name, String desc, List<String> memberIds) async {
    final body = {
      'creator_id': myErpId,
      'name': name,
      'description': desc,
      'icon_url': 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&background=0F172A&color=38BDF8&size=128',
      'members': memberIds,
    };

    try {
      final response = await http.post(
        Uri.parse(ApiConstants.chatGroups),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final res = json.decode(response.body);
        final newGroup = res['data'];
        
        _onConversationSelected(newGroup['id'], true);
        _fetchConversations();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group created successfully!')),
        );
      }
    } catch (e) {
      debugPrint("Error creating group: $e");
    }
  }

  Future<void> _blockUser(String blockedId) async {
    final body = {
      'user_id': myErpId,
      'blocked_id': blockedId,
      'action': 'BLOCK',
    };

    try {
      final response = await http.post(
        Uri.parse(ApiConstants.chatBlocks),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contact blocked successfully.')),
        );
        _fetchBlockedUsers();
        _fetchConversations();
        setState(() {
          _selectedConversationId = null;
        });
      }
    } catch (e) {
      debugPrint("Error blocking user: $e");
    }
  }

  Future<void> _deleteChatMessage(String msgId, bool forEveryone) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConstants.chatMessages}/$msgId?for_everyone=$forEveryone&user_id=$myErpId'),
      );
      if (response.statusCode == 200) {
        _fetchMessages(silent: true);
        _fetchConversations(silent: true);
      }
    } catch (e) {
      debugPrint("Error deleting message: $e");
    }
  }

  // --- AUDIO NOTES SIMULATION ---

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
        _recordedAudioPreviewUrl = 'simulated_audio_url';
      } else {
        _recordingSeconds = 0;
      }
    });
  }

  void _sendVoiceNote() {
    if (_recordedAudioPreviewUrl == null) return;
    _sendChatMessage(
      'Voice Note (0:${_recordingSeconds.toString().padLeft(2, '0')})',
      type: 'VOICE',
      attachmentName: 'voice_note_${DateTime.now().millisecondsSinceEpoch}.ogg',
      attachmentSize: '48 KB',
    );
    setState(() {
      _recordedAudioPreviewUrl = null;
      _recordingSeconds = 0;
    });
  }

  // --- WebRTC CALL SIMULATION ---

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

    Timer(const Duration(seconds: 2), () {
      if (!mounted || !_isCallActive) return;
      setState(() {
        _callState = 'Connected';
      });

      _callStatsTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted || !_isCallActive || _callState != 'Connected') {
          timer.cancel();
          return;
        }

        final secondFactor = DateTime.now().second % 10;
        String quality = 'Excellent';
        double rate = _isVideoCall ? 1600.0 : 72.0;

        if (secondFactor == 4) {
          quality = 'Good';
          rate = _isVideoCall ? 950.0 : 54.0;
        } else if (secondFactor == 8) {
          quality = 'Poor';
          rate = _isVideoCall ? 240.0 : 22.0;
        }

        if (_callDataSaver) {
          rate = _isVideoCall ? 300.0 : 24.0;
        }

        setState(() {
          _networkQuality = quality;
          _callBitrateKbps = rate;
          _dataConsumedMb += (rate * 1000) / 8 / (1024 * 1024);
        });
      });
    });
  }

  void _endCall() {
    _callStatsTimer?.cancel();
    final callPartnerName = _isGroupSelected 
        ? 'Group' 
        : (_conversations.firstWhere((c) => c['id'] == _callPartnerId, orElse: () => {'name': 'ERP User'})['name'] ?? 'ERP User');

    setState(() {
      _callLogsDb.insert(0, {
        'name': callPartnerName,
        'role': 'ERP Partner',
        'erpId': _callPartnerId ?? 'N/A',
        'type': _isVideoCall ? 'VIDEO' : 'VOICE',
        'outgoing': true,
        'missed': false,
        'time': 'Just now',
      });
      _callState = 'Ended';
    });

    Timer(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      setState(() {
        _isCallActive = false;
        _callPartnerId = null;
      });
    });
  }

  // --- ERP ATTACHMENTS SHEETS ---

  void _sendErpAttachment(String docType) {
    String name = '';
    String size = '';
    String desc = '';

    switch (docType) {
      case 'ASSIGNMENT':
        name = 'Assignment_Database_C23.pdf';
        size = '780 KB';
        desc = '📝 Assignment Doc';
        break;
      case 'MARKS':
        name = 'Consolidated_Semester_Marks_Memo.pdf';
        size = '1.2 MB';
        desc = '🎓 Marks Memo Slip';
        break;
      case 'FEE':
        name = 'Tuition_Fee_Receipt_Alwardas.pdf';
        size = '410 KB';
        desc = '💳 Term Fee Receipt';
        break;
      case 'TIMETABLE':
        name = 'Timetable_Revision_V2.pdf';
        size = '350 KB';
        desc = '📅 Semester Class Schedule';
        break;
    }

    _sendChatMessage(desc, type: 'ERP_DOC', attachmentName: name, attachmentSize: size);
    Navigator.pop(context);
  }

  // --- UI WIDGET RENDERING ---

  @override
  Widget build(BuildContext context) {
    isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    // Redesigned Color Palette matching existing theme (Glassmorphism card constants)
    primaryColor = isDark ? ThemeColors.accentCyan : ThemeColors.lightTint;
    scaffoldBg = isDark ? const Color(0xFF020617) : const Color(0xFFF8FAFC);
    sidebarBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    chatBg = isDark ? const Color(0xFF020617) : const Color(0xFFF1F5F9);
    borderCol = isDark ? ThemeColors.darkBorder : const Color(0xFFE2E8F0);
    textCol = isDark ? ThemeColors.darkTextPrimary : ThemeColors.lightText;
    subTextCol = isDark ? ThemeColors.darkTextSecondary : ThemeColors.lightSubtext;

    // Chat bubbles matching primary themes
    bubbleSent = isDark ? const Color(0xFF1E293B) : const Color(0xFFDBEAFE);
    bubbleSentText = isDark ? ThemeColors.darkTextPrimary : const Color(0xFF1E3A8A);
    bubbleRecv = isDark ? const Color(0xFF0F172A) : Colors.white;
    bubbleRecvText = isDark ? ThemeColors.darkTextPrimary : const Color(0xFF334155);

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
                  // 1. Sidebar Panel (Left) - Hidden on mobile if a chat conversation is selected
                  if (MediaQuery.of(context).size.width > 700 || _selectedConversationId == null)
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
                          if (MediaQuery.of(context).size.width > 700) ...[
                            // Desktop: Show chat window, and optionally details panel next to it
                            Expanded(
                              child: Container(
                                color: chatBg,
                                child: _selectedConversationId != null
                                    ? _buildChatWindow()
                                    : _buildEmptyState(),
                              ),
                            ),
                            if (_showRightPanel && _selectedConversationId != null)
                              Container(
                                width: 320,
                                decoration: BoxDecoration(
                                  color: sidebarBg,
                                  border: Border(left: BorderSide(color: borderCol, width: 1)),
                                ),
                                child: _buildRightDetailPanel(),
                              ),
                          ] else ...[
                            // Mobile: Show either chat window or details panel (taking full width)
                            Expanded(
                              child: Container(
                                color: chatBg,
                                child: _selectedConversationId == null
                                    ? _buildEmptyState()
                                    : (_showRightPanel
                                        ? _buildRightDetailPanel()
                                        : _buildChatWindow()),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),

              // 4. Simulated WebRTC Call Overlay Dialog
              if (_isCallActive) _buildCallOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    final pendingCount = _requests.where((r) => r['receiverId'] == myErpId && r['status'] == 'PENDING').length;
    
    return Column(
      children: [
        // Sidebar Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: sidebarBg,
            border: Border(bottom: BorderSide(color: borderCol, width: 1)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: primaryColor.withOpacity(0.15),
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

        // Sidebar Navigation Tabs (Status tab removed)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: Row(
            children: [
              _buildTabButton(0, Icons.chat_bubble_outline, 'Chats'),
              _buildTabButton(1, Icons.pending_outlined, 'Requests ($pendingCount)'),
              _buildTabButton(2, Icons.person_add_alt_outlined, 'Connect'),
              _buildTabButton(3, Icons.call_outlined, 'Calls'),
              if (myRole.toLowerCase().contains('admin') || myRole.toLowerCase().contains('coordinator') || myRole.toLowerCase().contains('principal'))
                _buildTabButton(4, Icons.security_outlined, 'Moderate'),
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
        backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
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
        return _buildCallsTab();
      case 4:
        return _buildModerateTab();
      default:
        return _buildChatsList();
    }
  }

  Widget _buildChatsList() {
    final filtered = _conversations.where((c) {
      if (_globalSearchController.text.isEmpty) return true;
      final q = _globalSearchController.text.toLowerCase();
      final name = (c['name'] ?? '').toString().toLowerCase();
      final id = (c['id'] ?? '').toString().toLowerCase();
      return name.contains(q) || id.contains(q);
    }).toList();

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
              fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
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
              backgroundColor: primaryColor.withOpacity(0.12),
              foregroundColor: primaryColor,
              elevation: 0,
              minimumSize: const Size(double.infinity, 38),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.groups_outlined, size: 18),
            label: Text('Create Coordination Group', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold)),
            onPressed: _createNewGroup,
          ),
        ),

        Expanded(
          child: _isLoadingConversations
              ? const Center(child: CircularProgressIndicator())
              : filtered.isEmpty
                  ? Center(child: Text('No active chats yet.\nUse Connect tab to search by ERP ID.', textAlign: TextAlign.center, style: TextStyle(color: subTextCol, fontSize: 12)))
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final c = filtered[i];
                        final isGroup = c['isGroup'] == true;
                        final isSelected = _selectedConversationId == c['id'] && _isGroupSelected == isGroup;
                        
                        final avatarUrl = isGroup
                            ? (c['iconUrl'] ?? 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(c['name'])}&background=0F172A&color=38BDF8')
                            : 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(c['name'])}&background=0F172A&color=22D3EE';
                                   final isTyping = _typingPartners.contains(c['id']);
                        final lastMsg = isTyping ? 'Typing...' : (c['lastMessage'] ?? (isGroup ? 'Tap to start group coordination' : 'Connected.'));
                        final lastTimeStr = c['lastMessageTime'] != null
                            ? DateFormat('hh:mm a').format(DateTime.parse(c['lastMessageTime']))
                            : '';
                        final displayName = _customAliases[c['id']] ?? c['name'] ?? '';

                        return ListTile(
                          selected: isSelected,
                          selectedTileColor: isDark ? Colors.white10 : Colors.black12,
                          leading: CircleAvatar(
                            backgroundImage: NetworkImage(avatarUrl),
                            radius: 20,
                          ),
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(color: textCol, fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                              if (lastTimeStr.isNotEmpty)
                                Text(lastTimeStr, style: TextStyle(color: subTextCol, fontSize: 9)),
                            ],
                          ),
                          subtitle: Text(
                            lastMsg,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isTyping ? primaryColor : subTextCol,
                              fontWeight: isTyping ? FontWeight.bold : FontWeight.normal,
                              fontSize: 11,
                            ),
                          ),
                          onTap: () => _onConversationSelected(c['id'], isGroup),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildRequestsTab() {
    final incomingPending = _requests.where((r) => r['receiverId'] == myErpId && r['status'] == 'PENDING').toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('Access Link Requests (${incomingPending.length})', style: GoogleFonts.poppins(color: textCol, fontWeight: FontWeight.bold, fontSize: 14)),
        ),
        Expanded(
          child: _isLoadingRequests
              ? const Center(child: CircularProgressIndicator())
              : incomingPending.isEmpty
                  ? Center(child: Text('No pending incoming chat requests.', style: TextStyle(color: subTextCol)))
                  : ListView.builder(
                      itemCount: incomingPending.length,
                      itemBuilder: (context, idx) {
                        final req = incomingPending[idx];
                        final senderAvatar = 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(req['senderName'])}&background=0F172A&color=22D3EE';
                        
                        return Card(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: borderCol)),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(backgroundImage: NetworkImage(senderAvatar), radius: 20),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(req['senderName'] ?? '', style: GoogleFonts.poppins(color: textCol, fontWeight: FontWeight.bold, fontSize: 13)),
                                          Text('${req['senderRole']} • ${req['senderId']}', style: TextStyle(color: subTextCol, fontSize: 10)),
                                          if (req['senderBranch'] != null)
                                            Text(req['senderBranch'], style: TextStyle(color: primaryColor, fontSize: 10, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                if (req['optionalMessage'] != null && req['optionalMessage'].toString().isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: scaffoldBg, borderRadius: BorderRadius.circular(6)),
                                    child: Text('"${req['optionalMessage']}"', style: TextStyle(color: textCol, fontSize: 11, fontStyle: FontStyle.italic)),
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

  Widget _buildConnectTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Establish Secure ERP Link', style: GoogleFonts.poppins(color: textCol, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          Text(
            'For privacy, no directories exist. Search by exact ERP ID only.',
            style: TextStyle(color: subTextCol, fontSize: 11),
          ),
          const SizedBox(height: 15),
          
          // Premium Glass-like search card
          AppTheme.buildGlassCard(
            isDark: isDark,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
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
                          fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                          filled: true,
                          labelStyle: TextStyle(color: primaryColor, fontSize: 12),
                        ),
                        onSubmitted: (_) => _searchErpId(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      style: IconButton.styleFrom(backgroundColor: primaryColor, padding: const EdgeInsets.all(12)),
                      icon: const Icon(Icons.search, color: Colors.white),
                      onPressed: _searchErpId,
                    )
                  ],
                ),
                if (_erpSearchError != null) ...[
                  const SizedBox(height: 10),
                  Text(_erpSearchError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ],
            ),
          ),

          const SizedBox(height: 25),

          if (_searchedUserResult != null) ...[
            Card(
              color: sidebarBg,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: borderCol)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    CircleAvatar(
                      backgroundImage: NetworkImage(
                        'https://ui-avatars.com/api/?name=${Uri.encodeComponent(_searchedUserResult['fullName'])}&background=0F172A&color=22D3EE&size=128'
                      ),
                      radius: 36,
                    ),
                    const SizedBox(height: 12),
                    Text(_searchedUserResult['fullName'] ?? '', style: GoogleFonts.poppins(color: textCol, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('${_searchedUserResult['role']} • ${_searchedUserResult['loginId']}', style: TextStyle(color: subTextCol, fontSize: 11)),
                    if (_searchedUserResult['branch'] != null)
                      Text('${_searchedUserResult['branch']} ${_searchedUserResult['section'] ?? ""}', style: TextStyle(color: primaryColor, fontSize: 12, fontWeight: FontWeight.bold)),
                    const Divider(height: 25),
                    
                    _searchedUserResult['isConnected'] == true
                        ? TextButton.icon(
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text('Already Connected'),
                            onPressed: null,
                          )
                        : _searchedUserResult['connectionStatus'] == 'PENDING'
                            ? const Text('Connection Request Pending Approval', style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12))
                            : ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  minimumSize: const Size(double.infinity, 44),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                                label: const Text('Send Connection Request', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                onPressed: _sendConnectionRequest,
                              )
                  ],
                ),
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildCallsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Secure Call Logs', style: GoogleFonts.poppins(color: textCol, fontWeight: FontWeight.bold, fontSize: 14)),
        ),
        Expanded(
          child: _callLogsDb.isEmpty
              ? Center(child: Text('No call logs.', style: TextStyle(color: subTextCol)))
              : ListView.builder(
                  itemCount: _callLogsDb.length,
                  itemBuilder: (context, idx) {
                    final log = _callLogsDb[idx];
                    final avatarUrl = 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(log['name'])}&background=0F172A&color=22D3EE';
                    
                    return ListTile(
                      leading: CircleAvatar(backgroundImage: NetworkImage(avatarUrl)),
                      title: Text(log['name'], style: GoogleFonts.poppins(color: textCol, fontWeight: FontWeight.bold, fontSize: 13)),
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
                        icon: Icon(log['type'] == 'VIDEO' ? Icons.videocam_outlined : Icons.call_outlined, color: primaryColor),
                        onPressed: () => _initiateCall(log['erpId'], log['type'] == 'VIDEO'),
                      ),
                    );
                  },
                ),
        )
      ],
    );
  }

  Widget _buildModerateTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Abuse Reports & Moderation', style: GoogleFonts.poppins(color: textCol, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 4),
          const Text('Monitor communication logs, block abuses and verify user metrics.', style: TextStyle(fontSize: 10)),
          const SizedBox(height: 15),
          
          Row(
            children: [
              Expanded(
                child: Card(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: borderCol)),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        Text('Abuse Reports', style: TextStyle(color: subTextCol, fontSize: 10)),
                        const SizedBox(height: 4),
                        Text('${_requests.where((r) => r['status'] == 'BLOCKED').length}', style: GoogleFonts.poppins(color: Colors.redAccent, fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Card(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: borderCol)),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        Text('Active Connections', style: TextStyle(color: subTextCol, fontSize: 10)),
                        const SizedBox(height: 4),
                        Text('${_conversations.length}', style: GoogleFonts.poppins(color: primaryColor, fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 15),
          Text('Active Blocked Users Directory', style: GoogleFonts.poppins(color: textCol, fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 8),

          _blockedUsers.isEmpty
              ? Text('No users blocked.', style: TextStyle(color: subTextCol, fontSize: 11))
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _blockedUsers.length,
                  itemBuilder: (context, i) {
                    final blockedId = _blockedUsers[i];
                    return ListTile(
                      dense: true,
                      title: Text(blockedId, style: TextStyle(color: textCol)),
                      trailing: TextButton(
                        onPressed: () async {
                          // Unblock
                          final body = {
                            'user_id': myErpId,
                            'blocked_id': blockedId,
                            'action': 'UNBLOCK',
                          };
                          await http.post(
                            Uri.parse(ApiConstants.chatBlocks),
                            headers: {'Content-Type': 'application/json'},
                            body: json.encode(body),
                          );
                          _fetchBlockedUsers();
                        },
                        child: const Text('Unblock', style: TextStyle(fontSize: 11)),
                      ),
                    );
                  },
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
          Icon(Icons.shield_outlined, size: 64, color: primaryColor.withOpacity(0.35)),
          const SizedBox(height: 15),
          Text('ERP Connect secure Messenger', style: GoogleFonts.poppins(color: textCol, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text('Text faculty, peers and parents using exact IDs.', style: TextStyle(color: subTextCol, fontSize: 12)),
          const SizedBox(height: 2),
          Text('Protected under ERP system security protocols.', style: TextStyle(color: subTextCol, fontSize: 11, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  Widget _buildChatWindow() {
    final activeConv = _conversations.firstWhere((c) => c['id'] == _selectedConversationId, orElse: () => null);
    if (activeConv == null) {
      return _buildEmptyState();
    }

    final isGroup = activeConv['isGroup'] == true;
    final chatTitle = activeConv['name'] ?? '';
    final chatSubtitle = isGroup ? '${activeConv['description'] ?? ""}' : (activeConv['role'] ?? '');
    
    final avatar = isGroup
        ? (activeConv['iconUrl'] ?? 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(chatTitle)}&background=0F172A&color=38BDF8')
        : 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(chatTitle)}&background=0F172A&color=22D3EE';

    final displayMessages = _messages.where((m) {
      if (_disappearedMessageIds.contains(m['id'].toString())) {
        return false;
      }
      if (_isSearchingMessages && _messageSearchQuery.isNotEmpty) {
        return m['content'].toString().toLowerCase().contains(_messageSearchQuery.toLowerCase());
      }
      return true;
    }).toList();

    return Column(
      children: [
        // Chat Window Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: sidebarBg,
            border: Border(bottom: BorderSide(color: borderCol, width: 1)),
          ),
          child: Row(
            children: [
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
                      Text(_customAliases[_selectedConversationId!] ?? chatTitle, style: GoogleFonts.poppins(color: textCol, fontWeight: FontWeight.bold, fontSize: 13)),
                      Text(
                        _typingPartners.contains(_selectedConversationId!) ? 'Typing...' : chatSubtitle, 
                        style: TextStyle(
                          color: _typingPartners.contains(_selectedConversationId!) ? primaryColor : subTextCol, 
                          fontWeight: _typingPartners.contains(_selectedConversationId!) ? FontWeight.bold : FontWeight.normal,
                          fontSize: 10
                        ), 
                        overflow: TextOverflow.ellipsis
                      ),
                    ],
                  ),
                ),
              ),

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
              if (!isGroup) ...[
                IconButton(
                  icon: Icon(
                    _isDisappearingMode ? Icons.auto_delete : Icons.auto_delete_outlined, 
                    color: _isDisappearingMode ? Colors.purpleAccent : subTextCol,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _isDisappearingMode = !_isDisappearingMode;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_isDisappearingMode 
                            ? '👻 Snapchat Disappearing Mode enabled!' 
                            : 'Snapchat Disappearing Mode disabled.'),
                      ),
                    );
                  },
                  tooltip: 'Disappearing Messages (Snapchat Mode)',
                ),
                IconButton(
                  icon: const Icon(Icons.call_outlined, size: 20),
                  color: primaryColor,
                  onPressed: () => _initiateCall(_selectedConversationId!, false),
                ),
                IconButton(
                  icon: const Icon(Icons.videocam_outlined, size: 20),
                  color: primaryColor,
                  onPressed: () => _initiateCall(_selectedConversationId!, true),
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
        if (_isDisappearingMode && !isGroup)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            color: Colors.purple.withOpacity(0.12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.auto_delete, size: 14, color: Colors.purpleAccent),
                const SizedBox(width: 6),
                Text(
                  'Snapchat Disappearing Mode: Messages vanish after being viewed.',
                  style: GoogleFonts.poppins(color: isDark ? Colors.purpleAccent : Colors.purple[800], fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

        // Message Search
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

        // Messages List
        Expanded(
          child: _isLoadingMessages && _messages.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : displayMessages.isEmpty
                  ? Center(child: Text(_isSearchingMessages ? 'No matching messages found.' : 'No messages here yet.', style: TextStyle(color: subTextCol)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      physics: const BouncingScrollPhysics(),
                      itemCount: displayMessages.length,
                      itemBuilder: (context, idx) {
                        final msg = displayMessages[idx];
                        final isMe = msg['senderId'] == myErpId;
                        return _buildMessageBubble(msg, isMe);
                      },
                    ),
        ),

        // Reply context preview
        if (_replyMessageContext != null)
          Container(
            color: isDark ? const Color(0xFF1E293B) : Colors.grey[200],
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.reply, size: 18, color: primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Replying to: ${_replyMessageContext['content']}',
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

        // Voice Note Simulated Preview
        if (_recordedAudioPreviewUrl != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: sidebarBg,
            child: Row(
              children: [
                Icon(Icons.mic, color: primaryColor),
                const SizedBox(width: 10),
                Expanded(child: Text('Simulated Voice Note (0:${_recordingSeconds.toString().padLeft(2, '0')})', style: TextStyle(color: textCol, fontSize: 12))),
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

        // Chat Input Bar
        Container(
          padding: const EdgeInsets.all(10),
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF0F2F5),
          child: _isRecordingAudio
              ? Row(
                  children: [
                    const Icon(Icons.fiber_manual_record, color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Recording voice note... 0:${_recordingSeconds.toString().padLeft(2, '0')}',
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
                    IconButton(
                      icon: const Icon(Icons.attach_file),
                      color: subTextCol,
                      onPressed: _showAttachmentDrawer,
                    ),

                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        style: TextStyle(color: textCol, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Type a secure message...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                          fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          filled: true,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        onChanged: (val) => setState(() {}),
                        onSubmitted: (val) {
                          if (val.trim().isNotEmpty) {
                            _sendChatMessage(val.trim());
                            _messageController.clear();
                          }
                        },
                      ),
                    ),

                    const SizedBox(width: 6),
                    
                    _messageController.text.trim().isEmpty
                        ? IconButton(
                            icon: const Icon(Icons.mic_none_outlined),
                            color: primaryColor,
                            onPressed: _startAudioRecording,
                          )
                        : IconButton(
                            icon: const Icon(Icons.send_outlined),
                            color: primaryColor,
                            onPressed: () {
                              final txt = _messageController.text.trim();
                              if (txt.isNotEmpty) {
                                _sendChatMessage(txt);
                                _messageController.clear();
                              }
                            },
                          ),
                  ],
                ),
        ),
      ],
    );
  }

  void _showAttachmentDrawer() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Attach ERP Repository Document', style: GoogleFonts.poppins(color: textCol, fontSize: 15, fontWeight: FontWeight.bold)),
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
                _buildAttachmentCard(Icons.assignment_outlined, 'Assignment', Colors.orange, () => _sendErpAttachment('ASSIGNMENT')),
                _buildAttachmentCard(Icons.analytics_outlined, 'Marks Memo', Colors.blue, () => _sendErpAttachment('MARKS')),
                _buildAttachmentCard(Icons.receipt_long_outlined, 'Fee Receipt', Colors.green, () => _sendErpAttachment('FEE')),
                _buildAttachmentCard(Icons.calendar_month_outlined, 'Timetable', Colors.purple, () => _sendErpAttachment('TIMETABLE')),
                _buildAttachmentCard(Icons.image_outlined, 'Photos', Colors.teal, () {
                  _sendChatMessage('Mock Photo Uploaded', type: 'IMAGE', attachmentName: 'campus_photo.jpg', attachmentSize: '512 KB');
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
            CircleAvatar(backgroundColor: color.withOpacity(0.12), child: Icon(icon, color: color)),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(color: textCol, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(dynamic msg, bool isMe) {
    final bubbleColor = isMe ? bubbleSent : bubbleRecv;
    final alignment = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final fontCol = isMe ? bubbleSentText : bubbleRecvText;
    final bubbleBorder = isMe
        ? const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12), topRight: Radius.circular(12))
        : const BorderRadius.only(topLeft: Radius.circular(12), bottomRight: Radius.circular(12), topRight: Radius.circular(12));

    final timeStr = msg['createdAt'] != null
        ? DateFormat('hh:mm a').format(DateTime.parse(msg['createdAt']))
        : '';

    final isDeleted = msg['isDeletedForEveryone'] == true;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          GestureDetector(
            onLongPress: () => _showMessageActions(msg),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.65),
              decoration: BoxDecoration(color: bubbleColor, borderRadius: bubbleBorder),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Reply reference
                  if (msg['replyToContent'] != null && msg['replyToContent'].toString().isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(6),
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.05),
                        border: Border(left: BorderSide(color: primaryColor, width: 3)),
                      ),
                      child: Text(msg['replyToContent'], style: TextStyle(color: subTextCol, fontSize: 10, fontStyle: FontStyle.italic)),
                    ),
                  ],

                  if (isDeleted)
                    const Text('This message was deleted.', style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic))
                  else if (msg['messageType'] == 'TEXT')
                    Text(msg['content'] ?? '', style: TextStyle(color: fontCol, fontSize: 12))
                  else if (msg['messageType'] == 'VOICE')
                    _buildVoicePlayer(msg)
                  else if (msg['messageType'] == 'IMAGE')
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            height: 120, width: 180,
                            color: Colors.black12,
                            child: const Icon(Icons.image, color: Colors.grey, size: 36),
                          )
                        ),
                        const SizedBox(height: 4),
                        Text(msg['content'] ?? '', style: TextStyle(color: fontCol, fontSize: 11)),
                      ],
                    )
                  else if (msg['messageType'] == 'FILE' || msg['messageType'] == 'ERP_DOC')
                    _buildFileAttachmentBubble(msg),

                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(timeStr, style: TextStyle(color: subTextCol, fontSize: 8)),
                      if (isMe && !isDeleted) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.done_all, 
                          size: 12, 
                          color: _isDisappearingMode
                              ? (_blueTickMessageIds.contains(msg['id'].toString()) 
                                  ? Colors.blueAccent 
                                  : Colors.grey)
                              : primaryColor,
                        ),
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

  Widget _buildVoicePlayer(dynamic msg) {
    double playSpeed = 1.0;
    return StatefulBuilder(
      builder: (context, setBubbleState) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.play_arrow_rounded, size: 24),
            color: primaryColor,
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Simulating voice playback...')));
            },
          ),
          const SizedBox(width: 4),
          // Waveform
          Row(
            children: List.generate(8, (i) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 1),
              width: 2,
              height: (i % 3 + 1) * 4.0 + 2.0,
              color: primaryColor.withOpacity(0.5),
            )),
          ),
          const SizedBox(width: 10),
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
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(10)),
              child: Text('${playSpeed}x', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileAttachmentBubble(dynamic msg) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.04), borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.description_outlined, color: primaryColor, size: 28),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(msg['attachmentName'] ?? 'Document.pdf', style: TextStyle(color: textCol, fontWeight: FontWeight.bold, fontSize: 11), overflow: TextOverflow.ellipsis),
                Text(msg['attachmentSize'] ?? '420 KB', style: TextStyle(color: subTextCol, fontSize: 9)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.download_for_offline_outlined, size: 18),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Downloading ${msg['attachmentName'] ?? "document"}...')));
            },
          )
        ],
      ),
    );
  }

  void _showMessageActions(dynamic msg) {
    if (msg['isDeletedForEveryone'] == true) return;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply_outlined),
              title: const Text('Reply'),
              onTap: () {
                setState(() {
                  _replyMessageContext = msg;
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.content_copy_outlined),
              title: const Text('Copy Text'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: msg['content'] ?? ''));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Message copied to clipboard.')));
              },
            ),
            if (msg['senderId'] == myErpId)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Delete for Everyone', style: TextStyle(color: Colors.red)),
                onTap: () {
                  _deleteChatMessage(msg['id'], true);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRightDetailPanel() {
    final activeConv = _conversations.firstWhere((c) => c['id'] == _selectedConversationId, orElse: () => null);
    if (activeConv == null) return const SizedBox();

    final isGroup = activeConv['isGroup'] == true;
    final String name = activeConv['name'] ?? '';
    final String id = isGroup ? 'Group ID: ${activeConv['id']}' : activeConv['id'];
    final String roleText = isGroup ? (activeConv['description'] ?? "") : (activeConv['role'] ?? '');

    final avatar = isGroup
        ? (activeConv['iconUrl'] ?? 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&background=0F172A&color=38BDF8')
        : 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&background=0F172A&color=22D3EE';

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
                CircleAvatar(backgroundImage: NetworkImage(avatar), radius: 44),
                const SizedBox(height: 12),
                Text(_customAliases[activeConv['id']] ?? name, textAlign: TextAlign.center, style: GoogleFonts.poppins(color: textCol, fontSize: 15, fontWeight: FontWeight.bold)),
                Text(id, style: TextStyle(color: subTextCol, fontSize: 11)),
                const SizedBox(height: 6),
                Text(roleText, textAlign: TextAlign.center, style: TextStyle(color: primaryColor, fontSize: 11, fontWeight: FontWeight.bold)),
                const Divider(height: 30),

                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: primaryColor.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      Icon(Icons.lock_outline, color: primaryColor, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Secure ID communication. All chats require verified credentials to link.',
                          style: TextStyle(fontSize: 10),
                        ),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                Card(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: borderCol)),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.edit_outlined),
                        title: const Text('Rename Contact', style: TextStyle(fontSize: 12)),
                        onTap: () => _showRenameDialog(activeConv['id'], name),
                      ),
                      if (!isGroup)
                        ListTile(
                          leading: const Icon(Icons.block, color: Colors.red),
                          title: const Text('Block Connection', style: TextStyle(fontSize: 12, color: Colors.red)),
                          onTap: () {
                            _blockUser(activeConv['id']);
                          },
                        ),
                      ListTile(
                        leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        title: Text(isGroup ? 'Leave & Delete Group' : 'Delete Chat History', style: const TextStyle(fontSize: 12, color: Colors.redAccent)),
                        onTap: () {
                          _deleteConversation(activeConv['id']);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _createNewGroup() {
    final groupNameController = TextEditingController();
    final groupDescController = TextEditingController();
    List<String> selectedMembers = [];

    // Filter connected contacts from chats list to add them to a group
    final directPartners = _conversations.where((c) => c['isGroup'] == false).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
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
                Text('Create Coordination Group', style: GoogleFonts.poppins(color: textCol, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                TextField(
                  controller: groupNameController,
                  style: TextStyle(color: textCol),
                  decoration: const InputDecoration(
                    labelText: 'Group Name',
                    hintText: 'e.g. CSE-A Coordination Group',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: groupDescController,
                  style: TextStyle(color: textCol),
                  decoration: const InputDecoration(
                    labelText: 'Group Description',
                    hintText: 'Purpose of group cell coordination...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 15),
                Text('Add Connected Links (ERP IDs):', style: GoogleFonts.poppins(color: textCol, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                
                directPartners.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Text('You must have connected ERP contact links to create a group.', style: TextStyle(color: subTextCol, fontSize: 11)),
                      )
                    : Container(
                        constraints: const BoxConstraints(maxHeight: 180),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: directPartners.length,
                          itemBuilder: (context, i) {
                            final u = directPartners[i];
                            final id = u['id'];
                            final name = u['name'] ?? '';
                            final isSelected = selectedMembers.contains(id);
                            
                            return CheckboxListTile(
                              title: Text(name, style: TextStyle(color: textCol, fontSize: 13)),
                              subtitle: Text('${u['role']} - $id', style: TextStyle(color: subTextCol, fontSize: 11)),
                              value: isSelected,
                              onChanged: (val) {
                                setModalState(() {
                                  if (val == true) {
                                    selectedMembers.add(id);
                                  } else {
                                    selectedMembers.remove(id);
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
                        _createGroupSubmit(
                          groupNameController.text.trim(),
                          groupDescController.text.trim(),
                          selectedMembers,
                        );
                        Navigator.pop(context);
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

  Widget _buildCallOverlay() {
    final activeConv = _conversations.firstWhere((c) => c['id'] == _callPartnerId, orElse: () => null);
    final partnerName = activeConv != null ? activeConv['name'] : 'ERP User';
    final partnerAvatar = 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(partnerName)}&background=0F172A&color=22D3EE&size=256';

    return Container(
      color: Colors.black.withValues(alpha: 0.95),
      width: double.infinity,
      height: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          CircleAvatar(backgroundImage: NetworkImage(partnerAvatar), radius: 56),
          const SizedBox(height: 20),
          Text(partnerName, style: GoogleFonts.poppins(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          Text('${_isVideoCall ? "Video" : "Voice"} Calling (${_callPartnerId ?? ""})', style: const TextStyle(color: Colors.white54, fontSize: 13)),
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
                      const Text('Bitrate:', style: TextStyle(color: Colors.white70, fontSize: 11)),
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
