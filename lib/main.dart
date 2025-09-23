import 'dart:math';
import 'dart:ui' as ui;
import 'package:embiggen_your_eyes/convert.dart';
import 'package:embiggen_your_eyes/lebel.dart';
import 'package:embiggen_your_eyes/load_image.dart';
import 'package:embiggen_your_eyes/painter.dart';
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
  bool isLebelInput = false;
  Rect? lebelRect = null;
  Point<double>? labelPos = null;
  List<Lebel> labels = [];

  Map<int, List<List<ui.Image?>>>? image = {}; // zoom_level > [img_x][img_y]

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Timer? _debounceTimer;
  Set<Point<int>> _currentVisibleTiles = {};

  @override
  void initState() {
    super.initState();
    _initImages();

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

  List<Point<int>> getNextZoomTiles(int x, int y) {
    const int factor = 2;
    int xStart = x * factor;
    int yStart = y * factor;

    final nextTiles = <Point<int>>[];
    for (int dx = 0; dx < factor; dx++) {
      for (int dy = 0; dy < factor; dy++) {
        nextTiles.add(Point(xStart + dx, yStart + dy));
      }
    }
    return nextTiles;
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

    final newVisibleTiles = <Point<int>>{};
    for (int y = bound.startY; y < bound.endY; y++) {
      for (int x = bound.startX; x < bound.endX; x++) {
        newVisibleTiles.add(Point(x, y));
      }
    }

    final currentVisibleTiles = <Point<int>>{};
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
        currentVisibleTiles.add(Point(x, y));
      }
    }

    bool allCurrentTilesLoaded = true;
    for (final tile in currentVisibleTiles) {
      if (widget.image![widget.currentZoomLevel]![tile.y][tile.x] == null) {
        allCurrentTilesLoaded = false;
        loadNetworkImage(tile.x, tile.y, widget.currentZoomLevel).then((value) {
          if (mounted) {
            setState(() {
              widget.image![widget.currentZoomLevel]![tile.y][tile.x] = value;
            });
          }
        });
      }
    }

    if (allCurrentTilesLoaded) {
      final nextZoomLevel = widget.currentZoomLevel + 1;
      final nextTilesToLoad = <Point<int>>{};

      for (final tile in currentVisibleTiles) {
        final nextTiles = getNextZoomTiles(tile.x, tile.y);
        nextTilesToLoad.addAll(nextTiles);
      }

      for (final tile in nextTilesToLoad) {
        if (tile.y >= 0 &&
            tile.y < widget.image![nextZoomLevel]!.length &&
            tile.x >= 0 &&
            tile.x < widget.image![nextZoomLevel]![0].length &&
            widget.image![nextZoomLevel]![tile.y][tile.x] == null) {
          loadNetworkImage(tile.x, tile.y, nextZoomLevel).then((value) {
            if (mounted) {
              setState(() {
                widget.image![nextZoomLevel]![tile.y][tile.x] = value;
              });
            }
          });
        }
      }
    }
  }

  Size _getCurrentResolution() {
    double w = resolutionTable[widget.currentZoomLevel]!.width;
    double h = resolutionTable[widget.currentZoomLevel]!.height;
    return Size(w * widget.scale, h * widget.scale);
  }

  void _startDebounceTimer() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 200), () {
      _loadTilesForCurrentViewport();
    });
  }

  void _zoomIn() {
    if (widget.currentZoomLevel < resolutionTable.length) {
      setState(() {
        final oldScale = widget.scale;
        final oldZoomLevel = widget.currentZoomLevel;
        final focal = Offset(
          widget.viewportOffset.dx + widget.viewPortSize.width / 2.0,
          widget.viewportOffset.dy + widget.viewPortSize.height / 2.0,
        );

        // Update zoom level and scale
        final nextZoomLevel = oldZoomLevel + 1;
        final nextScale = 1.0;

        // Correct focal point calculation for discrete zoom levels
        final oldTotalScale = oldScale * resolutionTable[oldZoomLevel]!.width;
        final nextTotalScale =
            nextScale * resolutionTable[nextZoomLevel]!.width;
        final imagePoint = (focal - widget.initialPos) / oldTotalScale;
        final newInitialPos = focal - imagePoint * nextTotalScale;

        widget.initialPos = newInitialPos;
        widget.scale = nextScale;
        widget.currentZoomLevel = nextZoomLevel;

        _loadTilesForCurrentViewport();
      });
    }
  }

  void _zoomOut() {
    if (widget.currentZoomLevel > 1) {
      setState(() {
        final oldScale = widget.scale;
        final oldZoomLevel = widget.currentZoomLevel;
        final focal = Offset(
          widget.viewportOffset.dx + widget.viewPortSize.width / 2,
          widget.viewportOffset.dy + widget.viewPortSize.height / 2,
        );

        // Update zoom level and scale
        final nextZoomLevel = oldZoomLevel - 1;
        final nextScale = 1.0;

        // Correct focal point calculation for discrete zoom levels
        final oldTotalScale = oldScale * resolutionTable[oldZoomLevel]!.width;
        final nextTotalScale =
            nextScale * resolutionTable[nextZoomLevel]!.width;
        final imagePoint = (focal - widget.initialPos) / oldTotalScale;
        final newInitialPos = focal - imagePoint * nextTotalScale;

        widget.initialPos = newInitialPos;
        widget.scale = nextScale;
        widget.currentZoomLevel = nextZoomLevel;

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
                    onPointerUp: (event) {
                      if (widget.isLebelInput) {
                        setState(() {
                          Lebel lebel = Lebel(
                            pos: screenToImageSpace(
                              imageCurrentRes:
                                 _getCurrentResolution(),
                              imageOffset: widget.initialPos,
                              pointerLocation: event.position,
                              scale: widget.scale
                            ),
                            originalSize: _getCurrentResolution(),
                          );

                          widget.labels.add(lebel);
                        });
                        print(widget.labels.length);
                      }
                    },
                    onPointerDown: (event) {
                      print('Down');
                    },
                    onPointerSignal: (PointerSignalEvent event) async {
                      if (event is PointerScrollEvent) {
                        final oldScale = widget.scale;
                        final oldZoomLevel = widget.currentZoomLevel;

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

                        Offset newInitialPos;
                        final focal = event.localPosition;

                        if (nextZoomLevel != oldZoomLevel) {
                          final oldTotalScale =
                              oldScale * resolutionTable[oldZoomLevel]!.width;
                          final nextTotalScale =
                              nextScale * resolutionTable[nextZoomLevel]!.width;
                          final imagePoint =
                              (focal - widget.initialPos) / oldTotalScale;
                          newInitialPos = focal - imagePoint * nextTotalScale;
                        } else {
                          final scaleChange = nextScale / oldScale;
                          newInitialPos =
                              focal - (focal - widget.initialPos) * scaleChange;
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
                        final oldScale = widget.scale;
                        final oldZoomLevel = widget.currentZoomLevel;

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

                        Offset newInitialPos;
                        final focal = details.focalPoint;

                        if (nextZoomLevel != oldZoomLevel) {
                          final oldTotalScale =
                              oldScale * resolutionTable[oldZoomLevel]!.width;
                          final nextTotalScale =
                              nextScale * resolutionTable[nextZoomLevel]!.width;
                          final imagePoint =
                              (focal - widget.initialPos) / oldTotalScale;
                          newInitialPos = focal - imagePoint * nextTotalScale;
                        } else {
                          final scaleChange = nextScale / oldScale;
                          newInitialPos =
                              focal - (focal - widget.initialPos) * scaleChange;
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
                          labels: widget.labels,
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
                          Switch(
                            value: widget.isLebelInput,
                            onChanged: (v) {
                              setState(() {
                                widget.isLebelInput = v;
                              });
                            },
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
