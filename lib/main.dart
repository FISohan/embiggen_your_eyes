import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

void main() => runApp(MyApp());

final Map<int, Size> resolutionTable = {
  1: Size(1080, 1008),
  2: Size(2160, 2016),
  3: Size(4320, 4032),
  4: Size(8640, 8064),
  5: Size(11909, 11115),
};

class MyApp extends StatefulWidget {
  MyApp({super.key});
  double scale = 1;
  Offset delta = Offset(0, 0);
  double scaleFactor = 1.08;
  Size viewPortSize = Size(600, 600);
  Offset initialPos = Offset(0, 0);
  Size screenSize = Size(0, 0);
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void didChangeDependencies() {
    // TODO: implement didChangeDependencies
    super.didChangeDependencies();
    widget.screenSize = MediaQuery.of(context).size;
    widget.initialPos = Offset(
      (widget.screenSize.width / 2) - (widget.viewPortSize.width / 2),
      (widget.screenSize.height / 2) - (widget.viewPortSize.height / 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          widget.scale *= widget.scaleFactor;
        });
      },
      onPanUpdate: (DragUpdateDetails drag) {
        setState(() {
          widget.initialPos += drag.delta;
        });
      },
      child: CustomPaint(
        size: Size(widget.screenSize.width, widget.screenSize.width),
        painter: Painter(
          screenSize: widget.screenSize,
          scale: widget.scale,
          initialPos: widget.initialPos,
          viewPortSize: widget.viewPortSize,
        ),
      ),
    );
  }
}

class Painter extends CustomPainter {
  final Size screenSize;
  final Size viewPortSize;
  late final Size imgResolution;
  final double scale;

  final Offset initialPos;

  Painter({
    required this.screenSize,
    required this.scale,
    required this.initialPos,
    required this.viewPortSize,
  }) {
    imgResolution = Size(
      resolutionTable[1]!.aspectRatio.toDouble() *
          (viewPortSize.height.toDouble() - 100),
      viewPortSize.height.toDouble() - 100,
    );
  }

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    _drawTiles(canvas, 1);
    _drawViewPort(canvas);
  }

  bool _isPointInRect(
    double x,
    double y,
    double width,
    double height,
    double x1,
    double y1,
  ) {
    bool isXInside = x1 >= x && x1 <= x + width;
    bool isYInside = y1 >= y && y1 <= y + height;

    return isXInside && isYInside;
  }

  List<Offset> _getRectangleCorners(
    double x,
    double y,
    double width,
    double height,
  ) {
    final Offset topLeft = Offset(x, y);
    final Offset topRight = Offset(x + width, y);
    final Offset bottomLeft = Offset(x, y + height);
    final Offset bottomRight = Offset(x + width, y + height);

    return [topLeft, topRight, bottomRight, bottomLeft];
  }

  _drawTiles(Canvas canvas, int zoomLevel) {
    double tileSize = 256;
    Size originalImgRes = resolutionTable[zoomLevel]!;
    int rows = (originalImgRes.width / tileSize).toInt();
    int cols = (originalImgRes.height / tileSize).toInt();
    double originalImgScale = (originalImgRes.width / imgResolution.width);
    tileSize = (tileSize / originalImgScale) * scale;
    Size currentResolution = Size(rows * tileSize, cols * tileSize);

    Paint paint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.red;
    Paint strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.blue;

    int countCornerInsideViewPort = 1;

    for (int i = 0; i < rows; i += 1) {
      for (int j = 0; j < cols; j += 1) {
        double tileWidth = min(
          tileSize.toDouble(),
          originalImgRes.width - (i * tileSize),
        );
        double tileHeight = min(
          tileSize.toDouble(),
          originalImgRes.height - (j * tileSize),
        );
        Offset pos = Offset(
          (i * tileSize) + initialPos.dx,
          (j * tileSize) + initialPos.dy,
        );
        Rect rect = Rect.fromLTWH(
          pos.dx.floorToDouble(),
          pos.dy.floorToDouble(),
          tileWidth,
          tileHeight,
        );
        List<Offset> corners = _getRectangleCorners(
          pos.dx,
          pos.dy,
          tileWidth,
          tileHeight,
        );

        for (final Offset corner in corners) {
          if (_isPointInRect(
            (screenSize.width / 2) - (viewPortSize.width / 2),
            (screenSize.height / 2) - (viewPortSize.height / 2),
            viewPortSize.width,
            viewPortSize.width,
            corner.dx,
            corner.dy,
          )) {
            _debugPoint(canvas, corner, Colors.amberAccent);
            countCornerInsideViewPort = 1;
            break;
          } else {
            _debugPoint(canvas, corner, Colors.lightGreen);
            countCornerInsideViewPort *= 0;
          }
        }
        canvas.drawRect(
          rect,
          countCornerInsideViewPort == 1 ? paint : strokePaint,
        );
      }
    }
  }

  _drawViewPort(Canvas canvas) {
    Rect viewportRect = Rect.fromLTWH(
      (screenSize.width / 2) - (viewPortSize.width / 2),
      (screenSize.height / 2) - (viewPortSize.height / 2),
      viewPortSize.width,
      viewPortSize.height,
    );
    Paint viewportRectPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.black;

    canvas.drawRect(viewportRect, viewportRectPaint);
  }

  _debugPoint(Canvas canvas, Offset c, Color color) {
    Paint paint = Paint()
      ..style = PaintingStyle.fill
      ..color = color;
    canvas.drawCircle(c, 3, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
