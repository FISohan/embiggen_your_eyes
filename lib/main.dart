import 'dart:math';
import 'dart:ui' as ui;
import 'package:embiggen_your_eyes/load_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

void main() => runApp(MaterialApp(home: MyApp()));

double tileSize = 256.0;

final Map<int, Size> resolutionTable = {
  1: Size(1080, 253),
  2: Size(2160, 505),
  3: Size(4320, 1010),
  4: Size(8640, 2020),
  5: Size(17280, 4041),
  6: Size(34560, 8082),
  7: Size(42208, 9870),
};

({int startX, int startY, int endX, int endY}) calculateTileBounds({
  required double scale,
  required Offset initialPos,
  required Offset viewportOffset,
  required int zoomLevel,
  required Size viewPortSize,
  required Offset relativePos,
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

  int startX = relativePos.dx < 0 ? (distantX / scaledTileSize).floor() : 0;
  int startY = relativePos.dy < 0 ? (distantY / scaledTileSize).floor() : 0;

  int endX = imgEndingPoint.dx > viewPortSize.width + viewportOffset.dx
      ? (endDistantX.abs() / scaledTileSize).ceil()
      : 0;
  int endY = imgEndingPoint.dy > viewPortSize.height + viewportOffset.dy
      ? (endDistantY.abs() / scaledTileSize).ceil()
      : 0;

  return (startX: startX, startY: startY, endX: endX, endY: endY);
}

class MyApp extends StatefulWidget {
  MyApp({super.key});
  double scale = 1;
  Offset delta = Offset(0.0, 0.0);
  double scaleFactor = 1.03;

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

  Map<int, List<List<ui.Image?>>>? image = {}; // zoom_level > [img_x][img_y]

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

  Size _getCurrentResolution() {
    int maxX = (resolutionTable[widget.currentZoomLevel]!.width / tileSize)
        .ceil();
    int maxY = (resolutionTable[widget.currentZoomLevel]!.height / tileSize)
        .ceil();
    double currentScale = tileSize * widget.scale;

    return Size(maxX.toDouble() * currentScale, maxY.toDouble() * currentScale);
  }

  Future<void> _loadTiles(
    int startX,
    int endX,
    int startY,
    int endY, {
    required int zoomLevel,
  }) async {
    int maxX = (resolutionTable[zoomLevel]!.width / tileSize).ceil();
    int maxY = (resolutionTable[zoomLevel]!.height / tileSize).ceil();
    widget.image![zoomLevel] ??= List.generate(
      maxY,
      (_) => List.generate(maxX, (_) => null),
    );

    for (var y = startY; y < endY; y++) {
      for (var x = startX; x < endX; x++) {
        loadNetworkImage(x, y, widget.currentZoomLevel).then((value) {
          setState(() {
            widget.image![widget.currentZoomLevel]![y][x] = value;
          });
        });
      }
    }
  }

  void _zoomIn() {
    setState(() {
      widget.scale *= widget.scaleFactor;
      widget.currentResolution = _getCurrentResolution();
    });
  }

  void _zoomOut() {
    setState(() {
      widget.scale /= widget.scaleFactor;
      widget.currentResolution = _getCurrentResolution();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.screenSize = MediaQuery.of(context).size;
    widget.viewPortSize = Size(
      widget.screenSize.width,
      widget.screenSize.height,
    );
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
    widget.currentResolution = _getCurrentResolution();
    widget.relativePos = widget.initialPos - widget.viewportOffset;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body:
          widget.image == null || widget.image![widget.currentZoomLevel] == null
          ? Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                SizedBox(
                  width: widget.viewPortSize.width,
                  height: widget.viewPortSize.height,
                  child: Listener(
                    onPointerMove: (event) {
                      setState(() {
                        widget.initialPos += event.delta;
                      });
                    },
                    onPointerSignal: (PointerSignalEvent event) {
                      if (event is PointerScrollEvent) {
                        setState(() {
                          // 1. Determine new scale
                          double newScale = widget.scale;
                          if (event.scrollDelta.dy < 0) {
                            newScale *= widget.scaleFactor; // zoom in
                          } else if (event.scrollDelta.dy > 0) {
                            newScale /= widget.scaleFactor; // zoom out
                          }

                          // 2. Calculate the offset so zoom focuses on pointer
                          final focal = event.localPosition;
                          widget.initialPos =
                              widget.initialPos -
                              (focal - widget.initialPos) *
                                  (newScale / widget.scale - 1);

                          // 3. Apply the new scale
                          widget.scale = newScale;
                        });
                      }
                    },
                    child: GestureDetector(
                      onScaleUpdate: (ScaleUpdateDetails event) {
                        setState(() {
                          double newScale = widget.scale;

                          widget.scale *= event.scale;
                          final focal = event.focalPoint;
                          widget.initialPos =
                              widget.initialPos -
                              (focal - widget.initialPos) *
                                  (newScale / widget.scale - 1);

                          // 3. Apply the new scale
                          widget.scale = newScale;
                        });
                      },
                      child: CustomPaint(
                        painter: Painter(
                          screenSize: widget.screenSize,
                          scale: widget.scale,
                          initialPos: widget.initialPos,
                          viewPortSize: widget.viewPortSize,
                          images: widget.image![widget.currentZoomLevel],
                          relativePos: widget.relativePos,
                          viewportOffset: widget.viewportOffset,
                          zoomLevel: widget.currentZoomLevel,
                        ),
                      ),
                    ),
                  ),
                ),
                //// Controll Panel
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: Container(
                      height: 85,
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Column(
                        spacing: 1,
                        children: [
                          IconButton(
                            onPressed: _zoomIn,
                            icon: Icon(Icons.add, color: Colors.white),
                          ),
                          IconButton(
                            onPressed: _zoomOut,
                            icon: Icon(Icons.minimize, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
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
  final int zoomLevel;
  final List<List<ui.Image?>>? images;

  Painter({
    required this.screenSize,
    required this.scale,
    required this.initialPos,
    required this.viewPortSize,
    required this.images,
    required this.viewportOffset,
    required this.relativePos,
    required this.zoomLevel,
  }) {
    imgResolution = Size(
      resolutionTable[2]!.aspectRatio.toDouble() *
          (viewPortSize.height.toDouble() - 100),
      viewPortSize.height.toDouble() - 100,
    );
  }

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    _drawViewPort(canvas);
    _drawTiles(canvas);
  }

  _drawTiles(Canvas canvas) {
    final bounds = calculateTileBounds(
      scale: scale,
      initialPos: initialPos,
      viewportOffset: viewportOffset,
      zoomLevel: zoomLevel,
      viewPortSize: viewPortSize,
      relativePos: relativePos,
    );
    final startX = bounds.startX;
    final startY = bounds.startY;
    final endX = bounds.endX;
    final endY = bounds.endY;

    if (images != null && images!.isNotEmpty) {
      for (int y = startY; y < images!.length - endY; y++) {
        for (int x = startX; x < images![y].length - endX; x++) {
          final tile = images![y][x];
          if (tile != null) {
            final left = ((x.toDouble() * tileSize * scale)).ceilToDouble();
            final top = ((y.toDouble() * tileSize * scale)).ceilToDouble();
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
              Paint()..color = Colors.grey,
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
    // canvas.drawRect(
    //   dst,
    //   Paint()
    //     ..style = PaintingStyle.stroke
    //     ..color = Colors.red,
    // );
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
