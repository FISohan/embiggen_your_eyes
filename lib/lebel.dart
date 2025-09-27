import 'dart:math';

import 'package:flutter/material.dart';
import 'package:stellar_zoom/card.dart';

class Lebel {
  final Point<double> pos;
  final Size originalSize;
  final String? title;
  final String? description;
  final Size boundingBox;
  final LabelCategory? category;

  Lebel({
    required this.pos,
    required this.originalSize,
    this.title,
    this.description,
    required this.boundingBox,
    this.category
  });
}
