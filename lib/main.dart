import 'dart:math';
import 'dart:ui' as ui;
import 'package:embiggen_your_eyes/load_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'dart:async';

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

class MyApp extends StatefulWidget {
  MyApp({super.key});
  double scale = 1;
  Offset delta = Offset(0.0, 0.0);
  double scaleFactor = 1.03;

  Size viewPortSize = Size(600, 400);
  Offset initialPos = Offset(0.0, 0.0);
  Size screenSize = Size(0.0, 0.0);
  Size currentResolution = Size(0.0, 0.0);
  Offset viewportOffset = Offset(0.0, 0.0);

  int startX = 0;
  int endX = 0;
  int startY = 0;
  int endY = 0;
  int currentZoomLevel = 1;

  bool isLoading = false;

  Map<int, List<List<ui.Image?>>>? image = {}; // zoom_level > [img_x][img_y]

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _initImages();

    // Load tiles for zoom level 1
    int maxX = (resolutionTable[widget.currentZoomLevel]!.width / tileSize)
        .ceil();
    int maxY = (resolutionTable[widget.currentZoomLevel]!.height / tileSize)
        .ceil();

    _loadInitialTiles(maxX, maxY);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.screenSize = MediaQuery.of(context).size;
    widget.viewPortSize = Size(
      widget.screenSize.width,
      widget.screenSize.height,
    );
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
  }

  void _initImages() {
    resolutionTable.forEach((int key, Size value) {
      int maxX = (value.width / tileSize).ceil();
      int maxY = (value.height / tileSize).ceil();
      widget.image![key] ??= List.generate(
        maxY,
        (_) => List.generate(maxX, (_) => null),
      );
    });
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
    for (var y = startY; y < endY; y++) {
      for (var x = startX; x < endX; x++) {
        if (widget.image![zoomLevel]![y][x] == null) {
          loadNetworkImage(x, y, zoomLevel).then((value) {
            if (mounted) {
              setState(() {
                widget.image![zoomLevel]![y][x] = value;
              });
            }
          });
        }
      }
    }
  }

  Future<void> _loadTilesForCurrentViewport() async {
    if (widget.currentZoomLevel > 7) return;

    final bound = calculateTileBounds(
      scale: widget.scale,
      initialPos: widget.initialPos,
      viewportOffset: widget.viewportOffset,
      zoomLevel: widget.currentZoomLevel,
      viewPortSize: widget.viewPortSize,
    );

    for (
      int y = bound.startY;
      y < widget.image![widget.currentZoomLevel]!.length - bound.endY;
      y++
    ) {
      for (
        int x = bound.startX;
        x < widget.image![widget.currentZoomLevel]![y].length - bound.endX;
        x++
      ) {
        if (widget.image![widget.currentZoomLevel]![y][x] == null) {
          // If the tile is not loaded, check if a lower resolution tile exists
          // This creates a smoother transition effect
          if (widget.currentZoomLevel > 1) {
            final int prevZoomLevel = widget.currentZoomLevel - 1;
            final int prevX = (x / 2).floor();
            final int prevY = (y / 2).floor();

            // Check bounds to avoid errors
            if (prevY >= 0 &&
                prevY < widget.image![prevZoomLevel]!.length &&
                prevX >= 0 &&
                prevX < widget.image![prevZoomLevel]![0].length) {
              final ui.Image? prevImage =
                  widget.image![prevZoomLevel]![prevY][prevX];
              if (prevImage != null) {
                widget.image![widget.currentZoomLevel]![y][x] = prevImage;
              }
            }
          }
          loadNetworkImage(x, y, widget.currentZoomLevel).then((value) {
            if (mounted) {
              setState(() {
                widget.image![widget.currentZoomLevel]![y][x] = value;
              });
            }
          });
        }
      }
    }
  }

  Size _getCurrentResolution() {
    int maxX = (resolutionTable[widget.currentZoomLevel]!.width / tileSize)
        .ceil();
    int maxY = (resolutionTable[widget.currentZoomLevel]!.height / tileSize)
        .ceil();
    double currentScale = tileSize * widget.scale;
    return Size(maxX.toDouble() * currentScale, maxY.toDouble() * currentScale);
  }

  void _startDebounceTimer() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 200), () {
      _loadTilesForCurrentViewport();
    });
  }

  // Corrected _zoomIn() method
  void _zoomIn() {
    if (widget.currentZoomLevel < resolutionTable.length) {
      setState(() {
        widget.currentZoomLevel++;

        // Calculate the new image's top-left position
        // The image size doubles, so the initial position must also be scaled
        // to keep the same content in view.
        widget.initialPos = Offset(
          widget.initialPos.dx * 2,
          widget.initialPos.dy * 2,
        );

        _loadTilesForCurrentViewport();
      });
    }
  }

  void _zoomOut() {
    if (widget.currentZoomLevel > 1) {
      setState(() {
        widget.currentZoomLevel--;

        // Halve the initial position to keep the content in view
        widget.initialPos = Offset(
          widget.initialPos.dx * -0.5,
          widget.initialPos.dy * -0.5,
        );

        _loadTilesForCurrentViewport();
      });
    }
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
                        _startDebounceTimer();
                      });
                    },
                    onPointerSignal: (PointerSignalEvent event) async {
                      if (event is PointerScrollEvent) {
                        double oldScale = widget.scale;
                        int oldZoomLevel = widget.currentZoomLevel;

                        double nextScale = widget.scale;
                        int nextZoomLevel = oldZoomLevel;

                        if (event.scrollDelta.dy < 0) {
                          nextScale *= widget.scaleFactor;
                        } else if (event.scrollDelta.dy > 0) {
                          nextScale /= widget.scaleFactor;
                        }

                        if (nextScale >= 2.0 &&
                            nextZoomLevel < resolutionTable.length) {
                          nextZoomLevel++;
                          nextScale = nextScale / 2.0;
                        } else if (nextScale < 0.5 && nextZoomLevel > 1) {
                          nextZoomLevel--;
                          nextScale = nextScale * 2.0;
                        }

                        Offset newInitialPos = widget.initialPos;
                        if (nextZoomLevel != oldZoomLevel) {
                          // Calculate new position based on the center of the viewport
                          final double centerDx = widget.viewPortSize.width / 2;
                          final double centerDy =
                              widget.viewPortSize.height / 2;
                          final Offset center = Offset(centerDx, centerDy);

                          // Old image point at the center of the viewport
                          final Offset oldImagePoint =
                              (center - widget.initialPos) / oldScale;

                          // New initial position to keep that point at the center
                          newInitialPos = center - oldImagePoint * nextScale;
                        } else {
                          // Standard focal point calculation
                          final focal = event.localPosition;
                          newInitialPos =
                              widget.initialPos -
                              (focal - widget.initialPos) *
                                  (nextScale / oldScale - 1);
                        }

                        setState(() {
                          widget.initialPos = newInitialPos;
                          widget.scale = nextScale;
                          widget.currentZoomLevel = nextZoomLevel;
                        });

                        if (oldZoomLevel != widget.currentZoomLevel) {
                          _loadTilesForCurrentViewport();
                        } else {
                          _startDebounceTimer();
                        }
                      }
                    },
                    child: GestureDetector(
                      onScaleUpdate: (ScaleUpdateDetails details) {
                        double oldScale = widget.scale;
                        int oldZoomLevel = widget.currentZoomLevel;

                        double nextScale = widget.scale * details.scale;
                        int nextZoomLevel = oldZoomLevel;

                        if (nextScale >= 2.0 &&
                            nextZoomLevel < resolutionTable.length) {
                          nextZoomLevel++;
                          nextScale = nextScale / 2.0;
                        } else if (nextScale < 0.5 && nextZoomLevel > 1) {
                          nextZoomLevel--;
                          nextScale = nextScale * 2.0;
                        }

                        Offset newInitialPos = widget.initialPos;
                        if (nextZoomLevel != oldZoomLevel) {
                          // Calculate new position based on the center of the viewport
                          final double centerDx = widget.viewPortSize.width / 2;
                          final double centerDy =
                              widget.viewPortSize.height / 2;
                          final Offset center = Offset(centerDx, centerDy);

                          // Old image point at the center of the viewport
                          final Offset oldImagePoint =
                              (center - widget.initialPos) / oldScale;

                          // New initial position to keep that point at the center
                          newInitialPos = center - oldImagePoint * nextScale;
                        } else {
                          // Standard focal point calculation
                          final focal = details.focalPoint;
                          newInitialPos =
                              widget.initialPos -
                              (focal - widget.initialPos) *
                                  (nextScale / oldScale - 1);
                        }

                        setState(() {
                          widget.initialPos = newInitialPos;
                          widget.scale = nextScale;
                          widget.currentZoomLevel = nextZoomLevel;
                        });

                        if (oldZoomLevel != widget.currentZoomLevel) {
                          _loadTilesForCurrentViewport();
                        } else {
                          _startDebounceTimer();
                        }
                      },
                      child: CustomPaint(
                        painter: Painter(
                          screenSize: widget.screenSize,
                          scale: widget.scale,
                          initialPos: widget.initialPos,
                          viewPortSize: widget.viewPortSize,
                          images: widget.image![widget.currentZoomLevel],
                          viewportOffset: widget.viewportOffset,
                          zoomLevel: widget.currentZoomLevel,
                          onLoadTileRequest: (_) {},
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: Container(
                      height: 145,
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Wrap(
                        direction: Axis.vertical,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 10,
                        children: [
                          IconButton(
                            onPressed: _zoomIn,
                            icon: Icon(Icons.add, color: Colors.white),
                          ),
                          IconButton(
                            onPressed: _zoomOut,
                            icon: Icon(Icons.minimize, color: Colors.white),
                          ),
                          Text(
                            "${widget.currentZoomLevel}x",
                            style: TextStyle(color: Colors.white),
                          ),
                          widget.isLoading
                              ? SizedBox(
                                  height: 10,
                                  width: 10,
                                  child: CircularProgressIndicator(),
                                )
                              : SizedBox.square(dimension: 0),
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
  final Offset viewportOffset;
  final Offset initialPos;
  final int zoomLevel;
  final List<List<ui.Image?>>? images;
  final void Function(Point point) onLoadTileRequest;

  Painter({
    required this.screenSize,
    required this.scale,
    required this.initialPos,
    required this.viewPortSize,
    required this.images,
    required this.viewportOffset,
    required this.zoomLevel,
    required this.onLoadTileRequest,
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
      3,
      Paint()
        ..style = PaintingStyle.fill
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
