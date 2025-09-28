import 'dart:math';
import 'dart:ui' as ui;
import 'package:stellar_zoom/convert.dart';
import 'package:stellar_zoom/dataset_metadata.dart';
import 'package:stellar_zoom/lebel.dart';
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
  final Size currentRes;
  final Map<int, Size> resolutionTable;
  final bool isShowLabel;
  final Size? snapshotBoxSize;
  final Offset? snapshotBoxStartPos;
  final bool isAiSearch;
  final bool shouldShow;
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
    required this.resolutionTable,
    required this.currentRes,
    required this.isShowLabel,
    required this.isAiSearch,
    this.snapshotBoxSize,
    this.snapshotBoxStartPos,
    required this.shouldShow,
  }) {
    imgResolution = Size(
      resolutionTable[zoomLevel]?.width ?? 0,
      resolutionTable[zoomLevel]?.height ?? 0,
    );
  }

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    _drawTiles(canvas);
    if (isShowLabel) {
      _drawLabelBounndingBox(canvas);
    }
    if (shouldShow) {
      _drawSnapShotBoundingBox(canvas);
    }
  }

  _drawSnapShotBoundingBox(Canvas c) {
    if (snapshotBoxSize != null && snapshotBoxStartPos != null) {
      Rect rect = Rect.fromLTWH(
        snapshotBoxStartPos!.dx,
        snapshotBoxStartPos!.dy,
        snapshotBoxSize!.width,
        snapshotBoxSize!.height,
      );
      c.drawRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = Colors.tealAccent,
      );
    }
  }

  _drawLabelBounndingBox(Canvas canvas) {
    for (int i = 0; i < labels.length; i++) {
      final label = labels[i];
      final currentImageRes = currentRes;

      // Calculate screen position once
      final screenPosition = imageToScreenSpace(
        normalizedPos: label!.pos,
        currentImageRes: currentImageRes,
      );
      final finalPosition = screenPosition + initialPos + Offset(10.0, 10.0);

      // Calculate scaled bounding box size once
      final scaleX = currentImageRes.width / label.originalSize.width;
      final scaleY = currentImageRes.height / label.originalSize.height;

      Rect rect = Rect.fromCenter(
        center: finalPosition,
        width: label.boundingBox.width * scaleX,
        height: label.boundingBox.height * scaleY,
      );

      canvas.drawRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = Colors.lightGreenAccent,
      );
    }
  }

  _drawTiles(Canvas canvas) {
    if (images != null && images!.isNotEmpty) {
      final bounds = calculateTileBounds(
        scale: scale,
        initialPos: initialPos,
        viewportOffset: viewportOffset,
        zoomLevel: zoomLevel,
        viewPortSize: viewPortSize,
        tileSize: tileSize,
        resolutionTable: resolutionTable,
      );
      final startX = bounds.startX;
      final startY = bounds.startY;
      final endX = bounds.endX;
      final endY = bounds.endY;

      for (int y = startY; y < images!.length - endY; y++) {
        for (int x = startX; x < images![y].length - endX; x++) {
          final tile = images![y][x];
          if (tile != null) {
            final double left = (x.toDouble() * tileSize * scale)
                .floorToDouble();
            final double top = (y.toDouble() * tileSize * scale)
                .floorToDouble();
            final double width = (tile.width.toDouble() * scale).ceilToDouble();
            final double height = (tile.height.toDouble() * scale)
                .ceilToDouble();
            final tileRect = Rect.fromLTWH(left, top, width, height);
            final Rect adjustedRect = tileRect.inflate(0.5);
            _drawImage(canvas, tile, adjustedRect.topLeft, adjustedRect.size);
          } else {
            _drawPlaceholder(
              Offset(
                x * tileSize * scale + initialPos.dx,
                y * tileSize * scale + initialPos.dy,
              ),
              Size(tileSize * scale, tileSize * scale),
              "Fcat afaj ejaj ka",
              canvas,
            );
          }
        }
      }
    } else {
      _debugPoint(canvas, Offset(20, 10), Colors.greenAccent);
    }
  }

  void _drawPlaceholder(Offset offset, Size size, String text, Canvas canvas) {
    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: Colors.black, fontSize: 25),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    Rect rect = Rect.fromLTWH(offset.dx, offset.dy, size.width, size.height);
    canvas.drawRect(rect, Paint()..color = Colors.blue);
    final Offset textOffset = Offset(
      offset.dx + (size.width - textPainter.width) / 2,
      offset.dy + (size.height - textPainter.height) / 2,
    );

    textPainter.paint(canvas, textOffset);
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
