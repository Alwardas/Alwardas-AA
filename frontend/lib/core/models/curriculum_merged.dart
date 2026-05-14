class CurriculumMerged {
  final String subjectCode;
  final String subjectName;
  final String regulation;
  final int semester;
  final int totalPeriods;
  final List<CurriculumUnit> units;

  CurriculumMerged({
    required this.subjectCode,
    required this.subjectName,
    required this.regulation,
    required this.semester,
    required this.totalPeriods,
    required this.units,
  });

  factory CurriculumMerged.fromJson(Map<String, dynamic> json) {
    return CurriculumMerged(
      subjectCode: json['subjectCode'] ?? '',
      subjectName: json['subjectName'] ?? '',
      regulation: json['regulation'] ?? '',
      semester: json['semester'] ?? 1,
      totalPeriods: json['totalPeriods'] ?? 0,
      units: (json['units'] as List? ?? [])
          .map((u) => CurriculumUnit.fromJson(u))
          .toList(),
    );
  }
}

class CurriculumUnit {
  final int unitNo;
  final String title;
  final int totalPeriods;
  final List<CurriculumTopic> topics;

  CurriculumUnit({
    required this.unitNo,
    required this.title,
    required this.totalPeriods,
    required this.topics,
  });

  factory CurriculumUnit.fromJson(Map<String, dynamic> json) {
    return CurriculumUnit(
      unitNo: json['unitNo'] ?? 0,
      title: json['title'] ?? '',
      totalPeriods: json['totalPeriods'] ?? 0,
      topics: (json['topics'] as List? ?? [])
          .map((t) => CurriculumTopic.fromJson(t))
          .toList(),
    );
  }
}

class CurriculumTopic {
  final String id;
  final String sno;
  final String topic;
  final int period;
  final String type;
  final String status;
  final DateTime? assignedDate;
  final DateTime? completedDate;
  final String? remarks;
  final int feedbackCount;
  final double understoodPercentage;

  CurriculumTopic({
    required this.id,
    required this.sno,
    required this.topic,
    required this.period,
    required this.type,
    required this.status,
    this.assignedDate,
    this.completedDate,
    this.remarks,
    this.feedbackCount = 0,
    this.understoodPercentage = 0.0,
  });

  int get feedback_count => feedbackCount;
  double get understood_percentage => understoodPercentage;

  factory CurriculumTopic.fromJson(Map<String, dynamic> json) {
    return CurriculumTopic(
      id: json['id'] ?? '',
      sno: json['sno'] ?? '',
      topic: json['topic'] ?? '',
      period: json['period'] ?? 1,
      type: json['type'] ?? 'theory',
      status: json['status'] ?? 'pending',
      assignedDate: json['assignedDate'] != null ? DateTime.parse(json['assignedDate']) : null,
      completedDate: json['completedDate'] != null ? DateTime.parse(json['completedDate']) : null,
      remarks: json['remarks'],
      feedbackCount: json['feedbackCount'] ?? 0,
      understoodPercentage: (json['understoodPercentage'] ?? 0.0).toDouble(),
    );
  }
}
