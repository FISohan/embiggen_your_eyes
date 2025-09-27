
import 'dart:math';
import 'dart:ui';

import 'package:hive/hive.dart';
import 'package:stellar_zoom/card.dart';
import 'package:stellar_zoom/lebel.dart';

class LebelAdapter extends TypeAdapter<Lebel> {
  @override
  final int typeId = 1;

  @override
  Lebel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Lebel(
      pos: Point(fields[0] as double, fields[1] as double),
      originalSize: Size(fields[2] as double, fields[3] as double),
      title: fields[4] as String?,
      description: fields[5] as String?,
      boundingBox: Size(fields[6] as double, fields[7] as double),
      category: fields[8] != null ? LabelCategory.values.firstWhere((e) => e.name == fields[8]['name']) : null,
    );
  }

  @override
  void write(BinaryWriter writer, Lebel obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.pos.x)
      ..writeByte(1)
      ..write(obj.pos.y)
      ..writeByte(2)
      ..write(obj.originalSize.width)
      ..writeByte(3)
      ..write(obj.originalSize.height)
      ..writeByte(4)
      ..write(obj.title)
      ..writeByte(5)
      ..write(obj.description)
      ..writeByte(6)
      ..write(obj.boundingBox.width)
      ..writeByte(7)
      ..write(obj.boundingBox.height)
      ..writeByte(8)
      ..write(obj.category != null ? {'name': obj.category!.name} : null);
  }
}
