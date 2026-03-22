import 'dart:convert';

class ParentRequest {
  final String id;
  final String parentId;
  final String studentId;
  final String requestType;
  final String subject;
  final String description;
  final String dateDuration;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? assignedTo;
  final String? parentName;
  final String? parentRole;
  final String? studentName;
  final String? studentLoginId;
  final String? assignedName;
  final String? voiceNote;

  ParentRequest({
    required this.id,
    required this.parentId,
    required this.studentId,
    required this.requestType,
    required this.subject,
    required this.description,
    required this.dateDuration,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.assignedTo,
    this.parentName,
    this.parentRole,
    this.studentName,
    this.studentLoginId,
    this.assignedName,
    this.voiceNote,
  });

  factory ParentRequest.fromJson(Map<String, dynamic> json) {
    return ParentRequest(
      id: json['id'],
      parentId: json['parentId'],
      studentId: json['studentId'],
      requestType: json['requestType'],
      subject: json['subject'],
      description: json['description'],
      dateDuration: json['dateDuration'],
      status: json['status'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      assignedTo: json['assignedTo'],
      parentName: json['parentName'],
      parentRole: json['parentRole'],
      studentName: json['studentName'],
      studentLoginId: json['studentLoginId'],
      assignedName: json['assignedName'],
      voiceNote: json['voiceNote'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'parentId': parentId,
      'studentId': studentId,
      'requestType': requestType,
      'subject': subject,
      'description': description,
      'dateDuration': dateDuration,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'assignedTo': assignedTo,
      'parentName': parentName,
      'parentRole': parentRole,
      'studentName': studentName,
      'studentLoginId': studentLoginId,
      'assignedName': assignedName,
      'voiceNote': voiceNote,
    };
  }
}
