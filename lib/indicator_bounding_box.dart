import 'package:flutter/material.dart';

Widget createOutlinedRect({
  required Offset center,
  required double width,
  required double height,
  Color borderColor = Colors.blue,
  double borderWidth = 2.0,
}) {
  // Calculate the top and left coordinates from the center.
  final double left = center.dx - (width / 2);
  final double top = center.dy - (height / 2);

  return Positioned(
    left: left,
    top: top,
    width: width,
    height: height,
    child: Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: borderColor,
          width: borderWidth,
        ),
      ),
    ),
  );
}