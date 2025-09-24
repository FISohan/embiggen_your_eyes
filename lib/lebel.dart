import 'dart:math';

import 'package:flutter/material.dart';

class Lebel {
  final Point<double> pos;
  final Size originalSize;
  final String? title;
  final String? description;
  final Size? boundingBox;

  Lebel({
    required this.pos,
    required this.originalSize,
    this.title,
    this.description,
    this.boundingBox,
  });
}
