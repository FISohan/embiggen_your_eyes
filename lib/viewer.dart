import 'dart:math';
import 'dart:ui' as ui;
import 'package:stellar_zoom/card.dart';
import 'package:stellar_zoom/convert.dart';
import 'package:stellar_zoom/dataset_metadata.dart';
import 'package:stellar_zoom/lebel.dart';
import 'package:stellar_zoom/load_image.dart';
import 'package:stellar_zoom/painter.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:hive/hive.dart';

class Viewer extends StatefulWidget {
  final Map<int, Size> resolutionTable;
  final String id;
  const Viewer({super.key, required this.resolutionTable, required this.id});
  @override
  State<Viewer> createState() => _ViewerState();
}

class _ViewerState extends State<Viewer> {
  Timer? _debounceTimer;
  late Map<int, Size> resolutionTable;
  late Box<Lebel> _labelBox;

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
  List<Lebel> labels = [];
  bool showCustomLabelUi = false;
  int currentLabelIndex = -1;
  bool isShowingLabel = true;
  Map<int, List<List<ui.Image?>>>? image = {}; // zoom_level > [img_x][img_y]

  // Cache management
  static const int maxCacheSizeInBytes = 50 * 1024 * 1024; // 500 MB

  int _calculateCacheSize() {
    int size = 0;
    image?.forEach((_, zoomLevelImages) {
      for (var row in zoomLevelImages) {
        for (var img in row) {
          if (img != null) {
            size +=
                img.height * img.width * 4; // Approximate size in bytes (RGBA)
          }
        }
      }
    });
    return size;
  }

  void _manageCache() {
    int currentSize = _calculateCacheSize();
    print("Current cache size: ${currentSize / 1024 / 1024} MB");
    if (currentSize < maxCacheSizeInBytes) return;

    print("Cache size exceeds the limit. Cleaning up...");

    final bound = calculateTileBounds(
      scale: scale,
      initialPos: initialPos,
      viewportOffset: viewportOffset,
      zoomLevel: currentZoomLevel,
      viewPortSize: viewPortSize,
      tileSize: tileSize,
      resolutionTable: resolutionTable,
    );

    final visibleTiles = <Point<int>>{};
    for (int y = bound.startY; y < bound.endY; y++) {
      for (int x = bound.startX; x < bound.endX; x++) {
        visibleTiles.add(Point(x, y));
      }
    }

    int bytesToFree = currentSize - maxCacheSizeInBytes;
    print("Bytes to free: ${bytesToFree / 1024 / 1024} MB");
    List<MapEntry<int, Point<int>>> allTiles = [];

    image?.forEach((zoomLevel, zoomLevelImages) {
      for (int y = 0; y < zoomLevelImages.length; y++) {
        for (int x = 0; x < zoomLevelImages[y].length; x++) {
          if (zoomLevelImages[y][x] != null) {
            allTiles.add(MapEntry(zoomLevel, Point(x, y)));
          }
        }
      }
    });

    allTiles.sort((a, b) {
      int zoomDiffA = (a.key - currentZoomLevel).abs();
      int zoomDiffB = (b.key - currentZoomLevel).abs();
      if (zoomDiffA != zoomDiffB) {
        return zoomDiffB.compareTo(
          zoomDiffA,
        ); // Sort by zoom level difference descending
      } else {
        return a.key.compareTo(b.key); // Then by zoom level ascending
      }
    });

    for (var entry in allTiles) {
      if (bytesToFree <= 0) break;

      if (entry.key == currentZoomLevel && visibleTiles.contains(entry.value)) {
        continue; // Don't remove visible tiles
      }

      final img = image![entry.key]![entry.value.y][entry.value.x];
      if (img != null) {
        final freedBytes = img.height * img.width * 4;
        bytesToFree -= freedBytes;
        image![entry.key]![entry.value.y][entry.value.x] = null;
        print(
          "Removed tile at zoom ${entry.key}, x: ${entry.value.x}, y: ${entry.value.y}. Freed ${freedBytes / 1024 / 1024} MB",
        );
      }
    }
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    resolutionTable = widget.resolutionTable;
    _initImages();

    int maxX = (resolutionTable[currentZoomLevel]!.width / tileSize).ceil();
    int maxY = (resolutionTable[currentZoomLevel]!.height / tileSize).ceil();
    _openLabelBox();
    _loadInitialTiles(maxX, maxY);
  }

  void _openLabelBox() async {
    _labelBox = await Hive.openBox<Lebel>(widget.id);
    setState(() {
      labels = _labelBox.values.toList();
    });
  }

  @override
  void dispose() {
    _labelBox.close();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    screenSize = MediaQuery.of(context).size;
    viewPortSize = Size(screenSize.width, screenSize.height);
    double scaleX =
        viewPortSize.width / resolutionTable[currentZoomLevel]!.width;
    double scaleY =
        viewPortSize.height / resolutionTable[currentZoomLevel]!.height;
    scale = min(scaleX, scaleY);
    currentResolution = _getCurrentResolution();
    initialPos = Offset(
      (screenSize.width / 2) - (currentResolution.width / 2),
      (screenSize.height / 2) - (currentResolution.height / 2),
    );
    ;
  }

  void _initImages() {
    resolutionTable.forEach((int key, Size value) {
      int maxX = (value.width / tileSize).ceil();
      int maxY = (value.height / tileSize).ceil();
      image![key] ??= List.generate(
        maxY,
        (_) => List.generate(maxX, (_) => null),
      );
    });
  }

  Future<void> _loadInitialTiles(int maxX, int maxY) async {
    await _loadTiles(0, maxX, 0, maxY, zoomLevel: currentZoomLevel);
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
        if (image![zoomLevel]![y][x] == null) {
          loadNetworkImage(x, y, zoomLevel, widget.id).then((value) {
            if (mounted) {
              setState(() {
                image![zoomLevel]![y][x] = value;
              });
              _manageCache();
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

  int _getMaxZoomLevel() {
    int ans = 0;
    for (int key in resolutionTable.keys) {
      ans = max(key, ans);
    }
    return ans;
  }

  Future<void> _loadTilesForCurrentViewport() async {
    if (currentZoomLevel > _getMaxZoomLevel()) return;

    final bound = calculateTileBounds(
      scale: scale,
      initialPos: initialPos,
      viewportOffset: viewportOffset,
      zoomLevel: currentZoomLevel,
      viewPortSize: viewPortSize,
      tileSize: tileSize,
      resolutionTable: resolutionTable,
    );

    // final newVisibleTiles = <Point<int>>{};
    // for (int y = bound.startY; y < bound.endY; y++) {
    //   for (int x = bound.startX; x < bound.endX; x++) {
    //     newVisibleTiles.add(Point(x, y));
    //   }
    // }

    final currentVisibleTiles = <Point<int>>{};
    for (
      int y = bound.startY;
      y < image![currentZoomLevel]!.length - bound.endY;
      y++
    ) {
      for (
        int x = bound.startX;
        x < image![currentZoomLevel]![y].length - bound.endX;
        x++
      ) {
        currentVisibleTiles.add(Point(x, y));
      }
    }

    bool allCurrentTilesLoaded = true;
    for (final tile in currentVisibleTiles) {
      if (image![currentZoomLevel]![tile.y][tile.x] == null) {
        allCurrentTilesLoaded = false;
        loadNetworkImage(tile.x, tile.y, currentZoomLevel, widget.id).then((
          value,
        ) {
          if (mounted) {
            setState(() {
              image![currentZoomLevel]![tile.y][tile.x] = value;
            });
            _manageCache();
          }
        });
      }
    }

    if (allCurrentTilesLoaded) {
      final nextZoomLevel = currentZoomLevel + 1;
      final nextTilesToLoad = <Point<int>>{};

      for (final tile in currentVisibleTiles) {
        final nextTiles = getNextZoomTiles(tile.x, tile.y);
        nextTilesToLoad.addAll(nextTiles);
      }

      for (final tile in nextTilesToLoad) {
        if (tile.y >= 0 &&
            tile.y < image![nextZoomLevel]!.length &&
            tile.x >= 0 &&
            tile.x < image![nextZoomLevel]![0].length) {
          loadNetworkImage(tile.x, tile.y, nextZoomLevel, widget.id).then((
            value,
          ) {
            if (mounted) {
              setState(() {
                image![nextZoomLevel]![tile.y][tile.x] = value;
              });
              _manageCache();
            }
          });
        }
      }
    }
  }

  Size _getCurrentResolution() {
    double w = resolutionTable[currentZoomLevel]!.width;
    double h = resolutionTable[currentZoomLevel]!.height;
    return Size(w * scale, h * scale);
  }

  void _startDebounceTimer() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 200), () {
      _loadTilesForCurrentViewport();
    });
  }

  void _zoomIn() {
    if (currentZoomLevel < _getMaxZoomLevel()) {
      setState(() {
        final oldScale = scale;
        final oldZoomLevel = currentZoomLevel;
        final focal = Offset(
          viewportOffset.dx + viewPortSize.width / 2.0,
          viewportOffset.dy + viewPortSize.height / 2.0,
        );

        // Update zoom level and scale
        final nextZoomLevel = oldZoomLevel + 1;
        final nextScale = 1.0;

        // Correct focal point calculation for discrete zoom levels
        final oldTotalScale = oldScale * resolutionTable[oldZoomLevel]!.width;
        final nextTotalScale =
            nextScale * resolutionTable[nextZoomLevel]!.width;
        final imagePoint = (focal - initialPos) / oldTotalScale;
        final newInitialPos = focal - imagePoint * nextTotalScale;

        initialPos = newInitialPos;
        scale = nextScale;
        currentZoomLevel = nextZoomLevel;

        _loadTilesForCurrentViewport();
      });
    }
  }

  void _zoomOut() {
    if (currentZoomLevel > 1) {
      setState(() {
        final oldScale = scale;
        final oldZoomLevel = currentZoomLevel;
        final focal = Offset(
          viewportOffset.dx + viewPortSize.width / 2,
          viewportOffset.dy + viewPortSize.height / 2,
        );

        // Update zoom level and scale
        final nextZoomLevel = oldZoomLevel - 1;
        final nextScale = 1.0;

        // Correct focal point calculation for discrete zoom levels
        final oldTotalScale = oldScale * resolutionTable[oldZoomLevel]!.width;
        final nextTotalScale =
            nextScale * resolutionTable[nextZoomLevel]!.width;
        final imagePoint = (focal - initialPos) / oldTotalScale;
        final newInitialPos = focal - imagePoint * nextTotalScale;

        initialPos = newInitialPos;
        scale = nextScale;
        currentZoomLevel = nextZoomLevel;

        _loadTilesForCurrentViewport();
      });
    }
  }

  void _handleZoom(double scaleChange, Offset focalPoint) {
    final oldScale = scale;
    final oldZoomLevel = currentZoomLevel;

    double nextScale = scale * scaleChange;
    int nextZoomLevel = oldZoomLevel;

    // Logic to transition between discrete zoom levels
    if (nextScale >= 2.0 && nextZoomLevel < _getMaxZoomLevel()) {
      nextZoomLevel++;
      nextScale /= 2.0;
    } else if (nextScale < 1.0 && nextZoomLevel > 1) {
      // Adjusted threshold for smoother zoom out
      nextZoomLevel--;
      nextScale *= 2.0;
    }

    Offset newInitialPos;
    // The math for calculating the new position based on the focal point
    if (nextZoomLevel != oldZoomLevel) {
      // When changing discrete zoom level
      final oldTotalWidth =
          oldScale * widget.resolutionTable[oldZoomLevel]!.width;
      final nextTotalWidth =
          nextScale * widget.resolutionTable[nextZoomLevel]!.width;
      final imagePoint = (focalPoint - initialPos) / oldTotalWidth;
      newInitialPos = focalPoint - (imagePoint * nextTotalWidth);
    } else {
      // When changing scale within the same zoom level
      final scaleRatio = nextScale / oldScale;
      newInitialPos = focalPoint - (focalPoint - initialPos) * scaleRatio;
    }

    setState(() {
      initialPos = newInitialPos;
      scale = nextScale;
      currentZoomLevel = nextZoomLevel;
    });

    // Load new tiles if we changed levels, otherwise debounce for panning/small zooms
    if (oldZoomLevel != currentZoomLevel) {
      _loadTilesForCurrentViewport();
    } else {
      _startDebounceTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: image == null || image![currentZoomLevel] == null
          ? Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                _buildCanvas(),
                _buildZoomControllPanel(),
                _buildZoomLebelAndSearchPanel(),
                if (isShowingLabel) ..._buildLabelOverlays(),

                if (showCustomLabelUi && currentLabelIndex != -1)
                  _featuresCard(),
              ],
            ),
    );
  }

  SizedBox _buildCanvas() {
    return SizedBox(
      width: viewPortSize.width,
      height: viewPortSize.height,
      child: Listener(
        onPointerMove: (event) {
          setState(() {
            initialPos += event.delta;
            _startDebounceTimer();
          });
        },
        onPointerSignal: (PointerSignalEvent event) async {
          if (event is PointerScrollEvent) {
            final scaleChange = event.scrollDelta.dy < 0
                ? scaleFactor
                : 1 / scaleFactor;
            _handleZoom(scaleChange, event.localPosition);
          }
        },
        child: GestureDetector(
          onLongPressStart: (event) {
            if (isLebelInput) {
              setState(() {
                Lebel lebel = Lebel(
                  pos: screenToImageSpace(
                    imageCurrentRes: _getCurrentResolution(),
                    imageOffset: initialPos,
                    pointerLocation: event.globalPosition,
                    scale: scale,
                  ),
                  originalSize: _getCurrentResolution(),
                  boundingBox: Size(0, 0),
                );
                showCustomLabelUi = true;

                labels.add(lebel);
                currentLabelIndex = labels.length - 1;
                _labelBox.add(lebel);
              });
            }
          },
          onScaleUpdate: (ScaleUpdateDetails details) {
            const double dampingFactor = 0.02;
            double dampenedScaleChange =
                1.0 + (details.scale - 1.0) * dampingFactor;

            // _handleZoom(dampingFactor, details.focalPoint);
          },
          child: CustomPaint(
            painter: Painter(
              screenSize: screenSize,
              scale: scale,
              initialPos: initialPos,
              viewPortSize: viewPortSize,
              images: image![currentZoomLevel],
              viewportOffset: viewportOffset,
              zoomLevel: currentZoomLevel,
              onLoadTileRequest: (_) {},
              labels: labels,
              resolutionTable: resolutionTable,
              currentRes: _getCurrentResolution(),
              isShowLabel: isShowingLabel,
            ),
          ),
        ),
      ),
    );
  }

  Padding _buildZoomControllPanel() {
    return Padding(
      padding: const EdgeInsets.all(18.0),
      child: Align(
        alignment: Alignment.bottomRight,

        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Wrap(
            direction: Axis.horizontal,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            children: [
              IconButton(
                onPressed: _zoomIn,
                icon: Icon(Icons.zoom_in_sharp, color: Colors.white),
              ),
              IconButton(
                onPressed: _zoomOut,
                icon: Icon(Icons.zoom_out_sharp, color: Colors.white),
              ),
              Text(
                "${currentZoomLevel}x / ${_getMaxZoomLevel()}x",
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Padding _buildZoomLebelAndSearchPanel() {
    return // This is the main refactored widget snippet:
    Padding(
      padding: const EdgeInsets.all(18.0),
      child: Align(
        alignment: Alignment.topRight,
        child: Container(
          // Added padding around the controls for better visual spacing
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(10),
          ),
          // Used Row with mainAxisSize.min to wrap children tightly
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. "Add Label" Switch (Assumes 'isAddingLabel' is the state variable)
              _buildSwitchControl(
                label: 'Add Label',
                value: isLebelInput,
                onChanged: (v) {
                  setState(() {
                    isLebelInput = v;
                  });
                },
              ),

              const SizedBox(width: 10), // Separator
              // 2. "Show Label" Switch (New, assumes 'isShowingLabel' is the state variable)
              _buildSwitchControl(
                label: 'Show Label',
                value: isShowingLabel,
                onChanged: (v) {
                  setState(() {
                    isShowingLabel = v;
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildLabelOverlays() {
    List<Widget> overlays = [];
    for (int i = 0; i < labels.length; i++) {
      final label = labels[i];
      final currentImageRes = _getCurrentResolution();

      // Calculate screen position once
      final screenPosition = imageToScreenSpace(
        normalizedPos: label.pos,
        currentImageRes: currentImageRes,
      );
      final finalPosition = screenPosition + initialPos;
      // Add icon button
      overlays.add(
        Positioned(
          left: finalPosition.dx - 10.0,
          top: finalPosition.dy - 10.0,
          child: IconButton(
            tooltip: label.title,
            icon: Icon(
              label.category?.icon ?? Icons.location_on_sharp,
              color: label.category?.color ?? Colors.lightGreenAccent,
            ),
            onPressed: () {
              setState(() {
                currentLabelIndex = i;
                showCustomLabelUi = true;
              });
            },
          ),
        ),
      );
    }
    return overlays;
  }

  Padding _featuresCard() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Align(
        alignment: Alignment.bottomLeft,

        child: BlurryCard(
          editable: labels[currentLabelIndex].title == null,
          onFloatingClosePressed: () {
            setState(() {
              showCustomLabelUi = false;
            });
          },
          onClosePressed: () {
            setState(() {
              showCustomLabelUi = false;
              if (labels.isNotEmpty && labels.last.title == null) {
                labels.removeLast();
                _labelBox.deleteAt(_labelBox.length - 1);
              }
            });
          },
          onDeletePressed: () {
            setState(() {
              labels.removeAt(currentLabelIndex);
              _labelBox.deleteAt(currentLabelIndex);
              print(currentLabelIndex);
              currentLabelIndex = -1;
            });
          },
          boxValueChange: (width, height) {
            Lebel current = labels[currentLabelIndex];
            setState(() {
              final updatedLebel = Lebel(
                pos: current.pos,
                originalSize: current.originalSize,
                title: current.title,
                boundingBox: Size(width, height),
                description: current.description,
              );
              labels[currentLabelIndex] = updatedLebel;
              _labelBox.putAt(currentLabelIndex, updatedLebel);
            });
          },
          onAddLabel:
              (title, description, width, height, LabelCategory category) {
                Lebel current = labels[currentLabelIndex];
                setState(() {
                  final updatedLebel = Lebel(
                    pos: current.pos,
                    originalSize: current.originalSize,
                    title: title,
                    boundingBox: Size(width, height),
                    description: description,
                    category: category,
                  );
                  labels[currentLabelIndex] = updatedLebel;
                  _labelBox.putAt(currentLabelIndex, updatedLebel);
                  currentLabelIndex = -1;
                });
              },
          title: labels[currentLabelIndex].title ?? "",
          description: labels[currentLabelIndex].description ?? "",
        ),
      ),
    );
  }
}

Widget _buildSwitchControl({
  required String label,
  required bool value,
  required ValueChanged<bool> onChanged,
}) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
      Transform.scale(
        scale: 0.6,
        child: Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: Colors.blueAccent,
        ),
      ),
    ],
  );
}
