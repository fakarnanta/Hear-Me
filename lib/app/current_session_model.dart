class CurrentSession {
  final String topic;
  final String courseName;
  final String courseCode;
  final int studentCount;
  final String? imageAsset; 

  CurrentSession({
    required this.topic,
    required this.courseName,
    required this.courseCode,
    required this.studentCount,
    this.imageAsset,
  });
}