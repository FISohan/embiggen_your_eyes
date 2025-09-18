import 'dart:math';
import 'dart:ui' as ui;
import 'package:embiggen_your_eyes/load_image.dart';
import 'package:flutter/material.dart';

void main() => runApp(MaterialApp(home: MyApp()));

double tileSize = 256;

final Map<int, Size> resolutionTable = {
  1: Size(1080, 253),
  2: Size(2160, 505),
  3: Size(4320, 1010),
  4: Size(8640, 2020),
  5: Size(17280, 4041),
  6: Size(34560, 8082),
  7: Size(42208, 9870),
};

class MyApp extends StatefulWidget {
  MyApp({super.key});
  double scale = 1;
  Offset delta = Offset(0.0, 0.0);
  double scaleFactor = 1.08;

  Size viewPortSize = Size(600, 400);
  Offset initialPos = Offset(0.0, 0.0);
  Offset relativePos = Offset(0.0, 0.0);
  Size screenSize = Size(0.0, 0.0);
  Size currentResolution = Size(0.0, 0.0);
  Offset viewportOffset = Offset(0.0, 0.0);

  int startX = 0;
  int endX = 0;
  int startY = 0;
  int endY = 0;
  int currentZoomLevel = 1;

  Map<int, List<List<ui.Image>>>? image = {}; // zoom_level > [img_x][img_y]

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();

    // Load tiles for zoom level 1
    int maxX = (resolutionTable[widget.currentZoomLevel]!.width / tileSize)
        .ceil();
    int maxY = (resolutionTable[widget.currentZoomLevel]!.height / tileSize)
        .ceil();

    _loadInitialTiles(maxX, maxY);
  }

  Future<void> _loadInitialTiles(int maxX, int maxY) async {
    await _loadTiles(0, maxX, 0, maxY, zoomLevel: widget.currentZoomLevel);
    if (mounted) setState(() {});
  }

  Future<void> _loadTiles(
    int startX,
    int endX,
    int startY,
    int endY, {
    required int zoomLevel,
  }) async {
    List<List<ui.Image>> tiles = [];

    for (var y = startY; y < endY; y++) {
      List<Future<ui.Image>> rowFutures = [];
      for (var x = startX; x < endX; x++) {
        rowFutures.add(loadNetworkImage(x, y, zoomLevel));
      }
      tiles.add(await Future.wait(rowFutures));
    }

    widget.image![zoomLevel] = tiles;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.screenSize = MediaQuery.of(context).size;

    // Initial scale to fit viewport
    double scaleX =
        widget.viewPortSize.width /
        resolutionTable[widget.currentZoomLevel]!.width;
    double scaleY =
        widget.viewPortSize.height /
        resolutionTable[widget.currentZoomLevel]!.height;
    widget.scale = min(scaleX, scaleY);
    widget.viewportOffset = Offset(
      (widget.screenSize.width / 2) - (widget.viewPortSize.width / 2),
      (widget.screenSize.height / 2) - (widget.viewPortSize.height / 2),
    );
    widget.initialPos = widget.viewportOffset;

    widget.relativePos = widget.initialPos - widget.viewportOffset;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: () {
          setState(() {
            widget.scale *= widget.scaleFactor;
          });
        },
        onPanUpdate: (DragUpdateDetails drag) {
          setState(() {
            widget.initialPos += drag.delta;
            widget.relativePos = widget.initialPos - widget.viewportOffset;
          });
        },
        child:
            widget.image == null ||
                widget.image![widget.currentZoomLevel] == null
            ? Center(child: CircularProgressIndicator())
            : Stack(
                children: [
                  Text('''Scale:${widget.scale} \n
                      pos:${widget.relativePos.dx} ${widget.relativePos.dy}'''),
                  CustomPaint(
                    size: Size(
                      widget.screenSize.width,
                      widget.screenSize.height,
                    ),
                    painter: Painter(
                      screenSize: widget.screenSize,
                      scale: widget.scale,
                      initialPos: widget.initialPos,
                      viewPortSize: widget.viewPortSize,
                      images: widget.image![widget.currentZoomLevel],
                      relativePos: widget.relativePos,
                      viewportOffset: widget.viewportOffset,
                    ),
                  ),
                ],
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
  final Offset relativePos;
  final Offset viewportOffset;
  final Offset initialPos;
  final List<List<ui.Image>>? images;

  Painter({
    required this.screenSize,
    required this.scale,
    required this.initialPos,
    required this.viewPortSize,
    required this.images,
    required this.viewportOffset,
    required this.relativePos,
  }) {
    imgResolution = Size(
      resolutionTable[2]!.aspectRatio.toDouble() *
          (viewPortSize.height.toDouble() - 100),
      viewPortSize.height.toDouble() - 100,
    );
  }

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    _drawTiles(canvas);
    _drawViewPort(canvas);
  }

  _drawTiles(Canvas canvas) {
    if (images != null && images!.isNotEmpty) {
      double scaledTileSize = tileSize * scale;

      double distantX = ((relativePos.dx - viewportOffset.dx) + scaledTileSize)
          .abs();
      double distantY = ((relativePos.dy - viewportOffset.dy) - scaledTileSize)
          .abs();

      int startX = (distantX / scaledTileSize).floor();
      int startY = (distantY / scaledTileSize).floor();

      double endDistantX = ((distantX + viewPortSize.width) / scaledTileSize);
      double endDistantY = ((distantY + viewPortSize.height) / scaledTileSize);

      int endX = (endDistantX / scaledTileSize).ceil();
      int endY = (endDistantX / scaledTileSize).floor();
      print(endX);
      print(endDistantX);

      for (int y = min(0, startY); y < images!.length; y++) {
        for (int x = startX; x < images![y].length; x++) {
          final tile = images![y][x];
          if (tile != null) {
            _drawImage(
              canvas,
              tile,
              Offset(x * tileSize.toDouble(), y * tileSize.toDouble()),
              Size(scaledTileSize, scaledTileSize),
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
      offset.dx * scale + initialPos.dx,
      offset.dy * scale + initialPos.dy,
      size.width,
      size.height,
    );
    canvas.drawImageRect(image, src, dst, Paint());
    canvas.drawRect(
      dst,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.red,
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
        ..color = Colors.black,
    );
  }

  _debugPoint(Canvas canvas, Offset c, Color color) {
    canvas.drawCircle(
      c,
      3,
      Paint()
        ..style = PaintingStyle.fill
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
