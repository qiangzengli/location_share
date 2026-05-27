class AuthUser {
  const AuthUser({
    required this.uid,
    required this.username,
    this.email,
    required this.displayName,
  });

  final String uid;
  final String username;
  final String? email;
  final String displayName;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      uid: json['id'] as String,
      username: json['username'] as String,
      email: json['email'] as String?,
      displayName: json['displayName'] as String,
    );
  }
}
