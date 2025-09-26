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


({int startX, int startY, int endX, int endY}) calculateTileBounds({
  required double scale,
  required Offset initialPos,
  required Offset viewportOffset,
  required int zoomLevel,
  required Size viewPortSize,
  required tileSize,
  required resolutionTable
}) {
  double scaledTileSize = tileSize * scale;

  double distantX = ((initialPos.dx - viewportOffset.dx)).abs();
  double distantY = ((initialPos.dy - viewportOffset.dy)).abs();

  int totalTileY = (resolutionTable[zoomLevel]!.height / tileSize).ceil();
  int totalTileX = (resolutionTable[zoomLevel]!.width / tileSize).ceil();

  Offset imgEndingPoint = Offset(
    (scaledTileSize * totalTileX) + initialPos.dx - scaledTileSize,
    (scaledTileSize * totalTileY) + initialPos.dy - scaledTileSize,
  );
  double endDistantX =
      (viewPortSize.width + viewportOffset.dx) - imgEndingPoint.dx;
  double endDistantY =
      imgEndingPoint.dy - (viewPortSize.height + viewportOffset.dy);

  int startX = initialPos.dx - viewportOffset.dx < 0
      ? (distantX / scaledTileSize).floor()
      : 0;
  int startY = initialPos.dy - viewportOffset.dy < 0
      ? (distantY / scaledTileSize).floor()
      : 0;
  int endX = imgEndingPoint.dx > viewPortSize.width + viewportOffset.dx
      ? (endDistantX.abs() / scaledTileSize).ceil()
      : 0;
  int endY = imgEndingPoint.dy > viewPortSize.height + viewportOffset.dy
      ? (endDistantY.abs() / scaledTileSize).ceil()
      : 0;

  return (startX: startX, startY: startY, endX: endX, endY: endY);
}