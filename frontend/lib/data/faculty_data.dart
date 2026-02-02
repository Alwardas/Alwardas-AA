class FacultyMember {
  final String id;
  final String name;
  final String designation;
  final String department;
  final String email;
  final String phone;
  final String experience;

  const FacultyMember({
    required this.id,
    required this.name,
    required this.designation,
    required this.department,
    required this.email,
    required this.phone,
    required this.experience,
  });
}

class FacultyData {
  static const List<FacultyMember> facultyList = [
    FacultyMember(
      id: 'F101',
      name: 'Dr. Srinivas Rao',
      designation: 'Professor & HOD',
      department: 'Computer Engineering',
      email: 'srinivas.rao@alwardas.com',
      phone: '+91 98480 12345',
      experience: '20 Years',
    ),
    FacultyMember(
      id: 'F102',
      name: 'Ms. Lakshmi Devi',
      designation: 'Asst. Professor',
      department: 'Computer Engineering',
      email: 'lakshmi.devi@alwardas.com',
      phone: '+91 91234 56789',
      experience: '12 Years',
    ),
    FacultyMember(
      id: 'F103',
      name: 'Mr. Rajesh Kumar',
      designation: 'Lecturer',
      department: 'Computer Engineering',
      email: 'rajesh.k@alwardas.com',
      phone: '+91 82345 67890',
      experience: '8 Years',
    ),
    FacultyMember(
      id: 'F201',
      name: 'Dr. Anand Murthy',
      designation: 'Professor & HOD',
      department: 'Civil Engineering',
      email: 'anand.m@alwardas.com',
      phone: '+91 76543 21098',
      experience: '22 Years',
    ),
    FacultyMember(
      id: 'F202',
      name: 'Mr. Suresh Raina',
      designation: 'Asst. Professor',
      department: 'Civil Engineering',
      email: 'suresh.r@alwardas.com',
      phone: '+91 63012 34567',
      experience: '15 Years',
    ),
    FacultyMember(
      id: 'F301',
      name: 'Dr. Venkat Raman',
      designation: 'Professor & HOD',
      department: 'Mechanical Engineering',
      email: 'venkat.r@alwardas.com',
      phone: '+91 99887 76655',
      experience: '25 Years',
    ),
  ];

  static List<FacultyMember> getByDepartment(String dept) {
    return facultyList.where((f) => f.department == dept).toList();
  }
}
