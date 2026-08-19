class ProfileModel {
  const ProfileModel({
    required this.userId,
    required this.username,
    required this.email,
    this.city,
    this.age,
    this.gender,
    this.profilePictureUrl,
  });

  final int userId;
  final String username;
  final String email;
  final String? city;
  final int? age;
  final String? gender;
  final String? profilePictureUrl;

  factory ProfileModel.fromJson(Map<String, dynamic> json) => ProfileModel(
    userId: json['userId'] as int,
    username: json['username'] as String,
    email: json['email'] as String,
    city: json['city'] as String?,
    age: json['age'] as int?,
    gender: json['gender'] as String?,
    profilePictureUrl: json['profilePictureUrl'] as String?,
  );
}

class UpdateProfileRequest {
  const UpdateProfileRequest({
    required this.username,
    this.city,
    this.age,
    this.gender,
  });

  final String username;
  final String? city;
  final int? age;
  final String? gender;

  Map<String, dynamic> toJson() => {
    'username': username,
    'city': city,
    'age': age,
    'gender': gender,
  };
}