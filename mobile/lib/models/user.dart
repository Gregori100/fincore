class User {
  final String id;
  final String name;
  final String email;
  final DateTime? emailVerifiedAt;

  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.emailVerifiedAt,
  });

  bool get isVerified => emailVerifiedAt != null;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      emailVerifiedAt: json['email_verified_at'] == null
          ? null
          : DateTime.parse(json['email_verified_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'email': email,
        'email_verified_at': emailVerifiedAt?.toIso8601String(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is User &&
          other.id == id &&
          other.name == name &&
          other.email == email &&
          other.emailVerifiedAt == emailVerifiedAt);

  @override
  int get hashCode => Object.hash(id, name, email, emailVerifiedAt);
}
