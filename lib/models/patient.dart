class Patient {
  final String id;
  final String name;
  final int age;
  final String gender;
  final bool isNew; // true = new case, false = follow-up
  final String diagnosis;

  Patient({
    required this.id,
    required this.name,
    required this.age,
    required this.gender,
    required this.isNew,
    required this.diagnosis,
  });
}
