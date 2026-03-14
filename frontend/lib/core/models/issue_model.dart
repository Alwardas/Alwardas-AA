class Issue {
  final String id;
  final String title;
  final String description;
  final String category;
  final String priority;
  final String status;
  final String createdBy;
  final String userRole;
  final String? assignedTo;
  final DateTime createdDate;
  final String? creatorName;
  final String? assignedName;

  Issue({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.priority,
    required this.status,
    required this.createdBy,
    required this.userRole,
    this.assignedTo,
    required this.createdDate,
    this.creatorName,
    this.assignedName,
  });

  factory Issue.fromJson(Map<String, dynamic> json) {
    return Issue(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? '',
      priority: json['priority'] ?? '',
      status: json['status'] ?? '',
      createdBy: json['createdBy'] ?? '',
      userRole: json['userRole'] ?? '',
      assignedTo: json['assignedTo'],
      createdDate: json['createdDate'] != null ? DateTime.parse(json['createdDate']) : DateTime.now(),
      creatorName: json['creatorName'],
      assignedName: json['assignedName'],
    );
  }
}

class IssueComment {
  final String id;
  final String issueId;
  final String comment;
  final String commentBy;
  final DateTime commentDate;
  final String? userName;

  IssueComment({
    required this.id,
    required this.issueId,
    required this.comment,
    required this.commentBy,
    required this.commentDate,
    this.userName,
  });

  factory IssueComment.fromJson(Map<String, dynamic> json) {
    return IssueComment(
      id: json['id'] ?? '',
      issueId: json['issueId'] ?? '',
      comment: json['comment'] ?? '',
      commentBy: json['commentBy'] ?? '',
      commentDate: DateTime.parse(json['commentDate']),
      userName: json['userName'],
    );
  }
}
