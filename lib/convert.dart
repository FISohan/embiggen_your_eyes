import 'dart:math';

import 'package:flutter/widgets.dart';

Point<double> screenToImageSpace({
  required Offset imageOffset,
  required Offset pointerLocation,
  required Size imageCurrentRes,
  required double scale,
}) {
  Offset ip = pointerLocation - imageOffset;

  return Point(
    (ip.dx) / imageCurrentRes.width,
    (ip.dy) / imageCurrentRes.height,
  );
}

Offset imageToScreenSpace({
  required Point<double> normalizedPos,
  required Size currentImageRes,
}) {
  return Offset(
    normalizedPos.x * currentImageRes.width,
    normalizedPos.y * currentImageRes.height,
  );
}
