class BackendFacultyMember {
  final String id;
  final String loginId;
  final String name;
  final String email;
  final String phone;
  final String experience;
  final String branch;
  final String role;

  BackendFacultyMember({
    required this.id,
    required this.loginId,
    required this.name,
    required this.email,
    required this.phone,
    required this.experience,
    required this.branch,
    required this.role,
  });

  factory BackendFacultyMember.fromJson(Map<String, dynamic> json) {
    return BackendFacultyMember(
      id: json['id'] ?? '',
      loginId: json['loginId'] ?? 'N/A',
      name: json['fullName'] ?? 'Unknown',
      email: json['email'] ?? 'N/A',
      phone: json['phoneNumber'] ?? 'N/A',
      experience: json['experience'] ?? 'N/A',
      branch: json['branch'] ?? 'General',
      role: json['role'] ?? 'Faculty',
    );
  }
}
