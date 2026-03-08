import 'package:hive_ce/hive.dart';

part 'processing_type.g.dart';

@HiveType(typeId: 0)
enum ProcessingType {
  @HiveField(0)
  face,
  @HiveField(1)
  document,
  @HiveField(2)
  unknown,
}
