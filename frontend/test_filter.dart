import 'dart:convert';

String normalizeBranch(String b) {
  String upper = b.trim().toUpperCase();
  if (upper == 'CME' || upper == 'CM' || upper.contains('COMPUTER')) return 'Computer Engineering';
  if (upper == 'CIV' || upper == 'CIVIL' || upper == 'CE') return 'Civil Engineering';
  if (upper == 'ECE' || upper == 'EC' || upper.contains('ELECTRONICS')) return 'Electronics & Communication Engineering';
  if (upper == 'EEE' || upper == 'EE' || upper.contains('ELECTRICAL')) return 'Electrical & Electronics Engineering';
  if (upper == 'MECH' || upper == 'MEC' || upper == 'ME' || upper.contains('MECHANICAL')) return 'Mechanical Engineering';
  return b.trim();
}

String normalizeSemester(String sem) {
  String s = sem.toLowerCase().trim();
  
  if (s.contains('semester')) {
    if (s.contains('1')) return 'Semester 1';
    if (s.contains('2')) return 'Semester 2';
    if (s.contains('3')) return 'Semester 3';
    if (s.contains('4')) return 'Semester 4';
    if (s.contains('5')) return 'Semester 5';
    if (s.contains('6')) return 'Semester 6';
  }

  if (s == '1') return 'Semester 1';
  if (s == '2') return 'Semester 2';
  if (s == '3') return 'Semester 3';
  if (s == '4') return 'Semester 4';
  if (s == '5') return 'Semester 5';
  if (s == '6') return 'Semester 6';
  
  return sem.trim();
}

void main() {
  String cRegulation = "C23";
  String widgetCourseId = "C-23";
  bool matchCourse = cRegulation.toUpperCase() == widgetCourseId.toUpperCase().replaceAll('-', '');
  print("matchCourse: $matchCourse");
  
  String cBranch = normalizeBranch("cme"); // since it's "Unknown" if not parsed correctly, but parts[3] is "cme"
  String widgetBranch = "Computer Engineering";
  bool matchBranch = normalizeBranch(cBranch) == normalizeBranch(widgetBranch);
  print("cBranch: $cBranch");
  print("widgetBranch: $widgetBranch");
  print("matchBranch: $matchBranch");
  
  String cSemester = normalizeSemester("3"); // from JSON data['semester'] == 3
  String widgetSemester = "Semester 3";
  bool matchSem = normalizeSemester(cSemester) == normalizeSemester(widgetSemester);
  print("cSemester: $cSemester");
  print("widgetSemester: $widgetSemester");
  print("matchSem: $matchSem");
}
