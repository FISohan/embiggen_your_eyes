import 'dart:math';
import 'dart:ui' as ui;

import 'package:embiggen_your_eyes/convert.dart';
import 'package:embiggen_your_eyes/lebel.dart';
import 'package:embiggen_your_eyes/main.dart';
import 'package:flutter/material.dart';

class Painter extends CustomPainter {
  final Size screenSize;
  final Size viewPortSize;
  late final Size imgResolution;
  final double scale;
  final Offset viewportOffset;
  final Offset initialPos;
  final int zoomLevel;
  final List<List<ui.Image?>>? images;
  final void Function(Point point) onLoadTileRequest;
  final List<Lebel?> labels;
  Painter({
    required this.screenSize,
    required this.scale,
    required this.initialPos,
    required this.viewPortSize,
    required this.images,
    required this.viewportOffset,
    required this.zoomLevel,
    required this.onLoadTileRequest,
    required this.labels,
  }) {
    imgResolution = Size(
      resolutionTable[zoomLevel]?.width ?? 0,
      resolutionTable[zoomLevel]?.height ?? 0,
    );
  }

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    _drawViewPort(canvas);
    _drawTiles(canvas);
  }


  _drawTiles(Canvas canvas) {
    if (images != null && images!.isNotEmpty) {
      final bounds = calculateTileBounds(
        scale: scale,
        initialPos: initialPos,
        viewportOffset: viewportOffset,
        zoomLevel: zoomLevel,
        viewPortSize: viewPortSize,
      );
      final startX = bounds.startX;
      final startY = bounds.startY;
      final endX = bounds.endX;
      final endY = bounds.endY;

      for (int y = startY; y < images!.length - endY; y++) {
        for (int x = startX; x < images![y].length - endX; x++) {
          final tile = images![y][x];
          if (tile != null) {
            final left = (x.toDouble() * tileSize * scale).floorToDouble();
            final top = (y.toDouble() * tileSize * scale).floorToDouble();
            final width = (tile.width.toDouble() * scale).ceilToDouble();
            final height = (tile.height.toDouble() * scale).ceilToDouble();
            _drawImage(canvas, tile, Offset(left, top), Size(width, height));
          } else {
            canvas.drawRect(
              Rect.fromLTWH(
                x * tileSize * scale + initialPos.dx,
                y * tileSize * scale + initialPos.dy,
                tileSize * scale,
                tileSize * scale,
              ),
              Paint()..color = Colors.blue.withAlpha(50),
            );
          }
        }
      }
    } else {
      _debugPoint(canvas, Offset(20, 10), Colors.greenAccent);
    }
  }

  void _drawImage(Canvas canvas, ui.Image image, Offset offset, Size size) {
    final src = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final dst = Rect.fromLTWH(
      offset.dx + initialPos.dx,
      offset.dy + initialPos.dy,
      size.width,
      size.height,
    );
    canvas.drawImageRect(
      image,
      src,
      dst,
      Paint()..filterQuality = FilterQuality.high,
    );
  }

  void _drawPlaceholderTile(Canvas canvas, int x, int y, int currentZoomLevel) {
    if (currentZoomLevel > 1) {
      // Calculate the coordinates of the parent tile at the previous zoom level
      int parentX = x ~/ 2;
      int parentY = y ~/ 2;
      int parentZoomLevel = currentZoomLevel - 1;

      final parentImages = resolutionTable.keys.contains(parentZoomLevel)
          ? images![parentZoomLevel]
          : null;
      if (parentImages == null || parentY >= parentImages.length) {
        // The parent image list or tile doesn't exist, draw a green rect as a last resort
        canvas.drawRect(
          Rect.fromLTWH(
            x * tileSize * scale + initialPos.dx,
            y * tileSize * scale + initialPos.dy,
            tileSize * scale,
            tileSize * scale,
          ),
          Paint()..color = Colors.green,
        );
        return;
      }
      final parentTile = parentImages[parentY];

      if (parentTile != null) {
        // Calculate which quadrant of the parent tile the current tile corresponds to
        final int quadrantX = x % 2;
        final int quadrantY = y % 2;

        final double srcTileSize = tileSize;
        final double srcLeft = quadrantX * srcTileSize;
        final double srcTop = quadrantY * srcTileSize;

        // The source rectangle is a quarter of the parent image
        final src = Rect.fromLTWH(srcLeft, srcTop, srcTileSize, srcTileSize);

        // The destination rectangle is the same as the current tile's destination
        final dst = Rect.fromLTWH(
          x * tileSize * scale + initialPos.dx,
          y * tileSize * scale + initialPos.dy,
          tileSize * scale,
          tileSize * scale,
        );

        canvas.drawImageRect(
          parentTile,
          src,
          dst,
          Paint()..filterQuality = FilterQuality.low,
        );
      } else {
        // Recursively call to find the grandparent tile
        _drawPlaceholderTile(canvas, parentX, parentY, parentZoomLevel);
      }
    } else {
      // If zoom level is 1 and the tile is missing, draw a green rect
      canvas.drawRect(
        Rect.fromLTWH(
          x * tileSize * scale + initialPos.dx,
          y * tileSize * scale + initialPos.dy,
          tileSize * scale,
          tileSize * scale,
        ),
        Paint()..color = Colors.green,
      );
    }
  }

  _drawViewPort(Canvas canvas) {
    Rect viewportRect = Rect.fromLTWH(
      viewportOffset.dx,
      viewportOffset.dy,
      viewPortSize.width,
      viewPortSize.height,
    );
    canvas.drawRect(
      viewportRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.white,
    );
  }

  _debugPoint(Canvas canvas, Offset c, Color color) {
    canvas.drawCircle(
      c,
      7,
      Paint()
        ..style = PaintingStyle.fill
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
