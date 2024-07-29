import 'package:hive/hive.dart';

part 'user.g.dart';

@HiveType(typeId: 0)
class User extends HiveObject {
  @HiveField(0)
  String mobileNumber;

  @HiveField(1)
  String sdp;

  @HiveField(2)
  String candidate;

  User(this.mobileNumber, this.sdp, this.candidate);
}
