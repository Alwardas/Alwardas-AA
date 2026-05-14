import '../api_config.dart';
import '../api_constants.dart';
import '../models/api_response.dart';

class CurriculumService {
  static Future<ApiResponse<dynamic>> getMergedCurriculum({
    required String branch,
    required int semester,
    required String subjectCode,
    required String section,
    required String year,
    String regulation = 'C23',
  }) async {
    final endpoint = '${ApiConstants.baseUrl}/api/curriculum/merged?'
        'branch=${Uri.encodeComponent(branch)}&'
        'semester=$semester&'
        'regulation=$regulation&'
        'subjectCode=${Uri.encodeComponent(subjectCode)}&'
        'section=${Uri.encodeComponent(section)}&'
        'year=${Uri.encodeComponent(year)}';
    
    return await ApiConfig.get(endpoint);
  }

  static Future<ApiResponse<dynamic>> updateProgress({
    required String topicId,
    required String subjectCode,
    required String facultyId,
    required String branch,
    required String section,
    required String year,
    required int semester,
    String? assignedDate,
    String? completedDate,
    required String status,
    String? remarks,
  }) async {
    final endpoint = '${ApiConstants.baseUrl}/api/curriculum/progress';
    final body = {
      'topicId': topicId,
      'subjectCode': subjectCode,
      'facultyId': facultyId,
      'branch': branch,
      'section': section,
      'year': year,
      'semester': semester,
      'assignedDate': assignedDate,
      'completedDate': completedDate,
      'status': status,
      'remarks': remarks,
    };
    
    return await ApiConfig.post(endpoint, body: body);
  }

  static Future<ApiResponse<dynamic>> submitFeedback({
    required String topicId,
    required String subjectCode,
    required String studentId,
    int? rating,
    String? issueType,
    bool? understood,
    String? comment,
  }) async {
    final endpoint = '${ApiConstants.baseUrl}/api/curriculum/feedback?studentId=$studentId';
    final body = {
      'topicId': topicId,
      'subjectCode': subjectCode,
      'rating': rating,
      'issueType': issueType,
      'understood': understood,
      'comment': comment,
    };
    
    return await ApiConfig.post(endpoint, body: body);
  }
}
