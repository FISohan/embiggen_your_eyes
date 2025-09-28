import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
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
import 'package:stellar_zoom/searchPanel.dart';

class Viewer extends StatefulWidget {
  final Map<int, Size> resolutionTable;
  final String id;
  final String creditLink;
  final String creditTitle;
  const Viewer({
    super.key,
    required this.resolutionTable,
    required this.id,
    required this.creditLink,
    required this.creditTitle,
  });
  @override
  State<Viewer> createState() => _ViewerState();
}

class _ViewerState extends State<Viewer> with TickerProviderStateMixin {
  Timer? _debounceTimer;
  late Map<int, Size> resolutionTable;
  late Box<Lebel> _labelBox;

  double scale = 1;
  Offset delta = Offset(0.0, 0.0);
  double scaleFactor = 1.05;

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
  Map<int, List<List<ui.Image?>>>? image = {};
  final GlobalKey _repaintBoundaryKey = GlobalKey();

  // Cache management
  static const int maxCacheSizeInBytes = 256 * 1024 * 1024; // 256 MB

  late AnimationController _animationController;
  Animation<double>? _scaleAnimation;
  Animation<Offset>? _positionAnimation;
  late AnimationController _panAnimationController;
  Animation<Offset>? _panAnimation;
  bool _aiSearch = false;
  bool _showSearchPanel = false;

  Offset? _snapshotBoxStart;
  Size? _snapshotBoxSize;
  bool _shouldShow = true;

  Uint8List? _snapShot;

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
    if (currentSize < maxCacheSizeInBytes) return;

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
    _initAnimation();
  }

  void _initAnimation() {
    _animationController =
        AnimationController(vsync: this, duration: Duration(milliseconds: 250))
          ..addListener(() {
            if (_scaleAnimation != null && _positionAnimation != null) {
              setState(() {
                // set animated value
                initialPos = _positionAnimation!.value;
                scale = _scaleAnimation!.value;
              });

              if (_scaleAnimation!.isCompleted ||
                  _positionAnimation!.isCompleted) {
                // after completed load tiles
                _startDebounceTimer();
              }
            }
          });

    _panAnimationController =
        AnimationController(vsync: this, duration: Duration(milliseconds: 250))
          ..addListener(() {
            if (_panAnimation != null) {
              setState(() {
                initialPos = _panAnimation!.value;
              });

              if (_panAnimation!.status == AnimationStatus.completed ||
                  _panAnimation!.status == AnimationStatus.dismissed) {
                _startDebounceTimer();
              }
            }
          });
  }

  void _startAnimatedTrasition({
    required double targatedScale,
    required Offset targatedPos,
    Duration duration = const Duration(milliseconds: 250),
  }) {
    // stop running animation
    _animationController.stop();

    _scaleAnimation = Tween<double>(begin: scale, end: targatedScale).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOutCubic,
      ),
    );

    _positionAnimation = Tween<Offset>(begin: initialPos, end: targatedPos)
        .animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeInOutCubic,
          ),
        );
    _animationController.duration = duration;
    _animationController.reset();
    _animationController.forward();
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
    if (currentZoomLevel >= _getMaxZoomLevel() && scale >= 2.0) return;

    final oldScale = scale;
    final oldZoomLevel = currentZoomLevel;
    final focal = Offset(
      viewportOffset.dx + viewPortSize.width / 2.0,
      viewportOffset.dy + viewPortSize.height / 2.0,
    );

    // Update zoom level and scale
    int nextZoomLevel = oldZoomLevel;
    double nextScale = scale * 1.8;

    if (nextScale >= 2.0) {
      nextZoomLevel++;
      nextScale /= 2.0;
    }
    if (nextZoomLevel > _getMaxZoomLevel()) {
      nextZoomLevel = _getMaxZoomLevel();
      nextScale = min(nextScale, 2.0);
    }
    // Correct focal point calculation for discrete zoom levels
    final oldTotalScale = oldScale * resolutionTable[oldZoomLevel]!.width;
    final nextTotalScale = nextScale * resolutionTable[nextZoomLevel]!.width;
    final imagePoint = (focal - initialPos) / oldTotalScale;
    final newInitialPos = focal - (imagePoint * nextTotalScale);
    setState(() {
      currentZoomLevel = nextZoomLevel;
    });
    _loadTilesForCurrentViewport();

    if (currentZoomLevel == nextZoomLevel) {
      _startAnimatedTrasition(
        targatedScale: nextScale,
        targatedPos: newInitialPos,
      );
    } else {
      setState(() {
        initialPos = newInitialPos;
        scale = nextScale;
      });
    }
  }

  void _zoomOut() {
    if (currentZoomLevel <= 1 && scale <= 1.0) return;

    final oldScale = scale;
    final oldZoomLevel = currentZoomLevel;
    final focal = Offset(
      viewportOffset.dx + viewPortSize.width / 2,
      viewportOffset.dy + viewPortSize.height / 2,
    );

    // Update zoom level and scale
    int nextZoomLevel = oldZoomLevel;
    double nextScale = oldScale / 1.5;
    if (nextScale <= 1.0) {
      nextScale *= 2.0;
      nextZoomLevel--;
    }

    // if (nextZoomLevel < 1) {
    //   nextZoomLevel = 1;
    //   nextScale = max(nextScale, 0.4);
    // }

    // Correct focal point calculation for discrete zoom levels
    final oldTotalScale = oldScale * resolutionTable[oldZoomLevel]!.width;
    final nextTotalScale = nextScale * resolutionTable[nextZoomLevel]!.width;
    final imagePoint = (focal - initialPos) / oldTotalScale;
    final newInitialPos = focal - imagePoint * nextTotalScale;

    setState(() {
      currentZoomLevel = nextZoomLevel;
    });

    _loadTilesForCurrentViewport();

    if (currentZoomLevel == nextZoomLevel) {
      _startAnimatedTrasition(
        targatedScale: nextScale,
        targatedPos: newInitialPos,
      );
    } else {
      setState(() {
        initialPos = newInitialPos;
        scale = nextScale;
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
    if (nextZoomLevel == _getMaxZoomLevel()) {
      nextScale = min(nextScale, 2.0);
    } else if (nextZoomLevel == 1) {
      nextScale = max(nextScale, 0.3);
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
      currentZoomLevel = nextZoomLevel;
      _loadTilesForCurrentViewport();
    } else {
      final scaleRatio = nextScale / oldScale;
      newInitialPos = focalPoint - (focalPoint - initialPos) * scaleRatio;
      _startDebounceTimer();
    }

    setState(() {
      initialPos = newInitialPos;
      scale = nextScale;
    });
  }

  void _onPanMove(DragUpdateDetails event) {
    if (_aiSearch) {
      setState(() {
        _snapshotBoxSize = Size(
          event.localPosition.dx - _snapshotBoxStart!.dx,
          event.localPosition.dy - _snapshotBoxStart!.dy,
        );
      });
      return;
    }
    setState(() {
      initialPos += event.delta;
      _startDebounceTimer();
    });
  }

  Future<Uint8List?> _cropUiImage(
    ui.Image originalImage,
    double x,
    double y,
    double w,
    double h,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    final destRect = Rect.fromLTWH(0, 0, w, h);
    final srcRect = Rect.fromLTWH(x + 3.0, y + 3.0, w - 4.0, h - 4.0);
    canvas.drawImageRect(originalImage, srcRect, destRect, Paint());

    // 6. Stop recording and finalize the picture
    final picture = recorder.endRecording();

    final croppedImage = await picture.toImage(w.round(), h.round());

    picture.dispose(); // Clean up the picture

    final bytes = await croppedImage.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) return null;
    return bytes.buffer.asUint8List();
  }

  Future<Uint8List?> _capturePng() async {
    RenderRepaintBoundary? boundary =
        _repaintBoundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary;
    double pixelRatio = MediaQuery.devicePixelRatioOf(context);
    ui.Image img = await boundary.toImage(pixelRatio: pixelRatio);
    return await _cropUiImage(
      img,
      _snapshotBoxStart!.dx * pixelRatio,
      _snapshotBoxStart!.dy * pixelRatio,
      _snapshotBoxSize!.width * pixelRatio,
      _snapshotBoxSize!.height * pixelRatio,
    );
  }

  void _onPanEnd(DragEndDetails event) async {
    if (_aiSearch) {
      _snapShot = await _capturePng();
      setState(() {
        _showSearchPanel = true;
        _shouldShow = false;
        // _snapshotBoxSize = null;
        // _snapshotBoxStart = null;
      });
      return;
    }

    final Offset val = event.velocity.pixelsPerSecond;
    const double flingDampingFactor = 0.1;
    if (val.distanceSquared > 100.0) {
      final Offset targatedOffset = initialPos + (val * flingDampingFactor);
      _panAnimation = _panAnimationController.drive(
        Tween<Offset>(
          begin: initialPos,
          end: targatedOffset,
        ).chain(CurveTween(curve: Curves.decelerate)),
      );
      _panAnimationController.value = 0;
      _panAnimationController.forward();
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
                if (_snapShot != null && _showSearchPanel) _buildSearchPanel(),
                if (isShowingLabel) ..._buildLabelOverlays(),

                if (showCustomLabelUi && currentLabelIndex != -1)
                  _featuresCard(),
                _buildCreditLink(),
              ],
            ),
    );
  }

  Widget _buildSearchPanel() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Align(
        alignment: Alignment.topLeft,
        child: Searchpanel(
          image: _snapShot,
          creditLink: widget.creditLink,
          onAddLabel: (responseText) {
            if (_snapshotBoxStart == null || _snapshotBoxSize == null) return;

            // 1. Parse Title and Description
            final lines = responseText.split('\n');
            String title = 'Unknown';
            String description = responseText;
            final titleLineIndex = lines.indexWhere(
              (line) => line.startsWith('### '),
            );
            if (titleLineIndex != -1) {
              title = lines[titleLineIndex].substring(4);
              lines.removeAt(titleLineIndex);
              description = lines.join('\n');
            }
            Rect r = Rect.fromLTWH(
              _snapshotBoxStart!.dx,
              _snapshotBoxStart!.dy,
              _snapshotBoxSize!.width,
              _snapshotBoxSize!.height,
            );
            // 2. Calculate Position and Bounding Box
            final screenPosition =
                _snapshotBoxStart! +
                Offset(
                  _snapshotBoxSize!.width / 2,
                  _snapshotBoxSize!.height / 2,
                );
            final imageSpacePos = screenToImageSpace(
              imageCurrentRes: _getCurrentResolution(),
              imageOffset: initialPos,
              pointerLocation: r.center,
              scale: scale,
            );

            // 3. Create the Label
            final newLabel = Lebel(
              pos: imageSpacePos,
              originalSize: _getCurrentResolution(),
              title: title,
              description: description,
              boundingBox: _snapshotBoxSize!,
              category: LabelCategory.ai,
            );

            // 4. Save and Rebuild
            setState(() {
              labels.add(newLabel);
              _labelBox.add(newLabel);
            });
          },
          onClose: () {
            setState(() {
              _showSearchPanel = false;
            });
          },
        ),
      ),
    );
  }

  SizedBox _buildCanvas() {
    return SizedBox(
      width: viewPortSize.width,
      height: viewPortSize.height,
      child: Listener(
        onPointerSignal: (PointerSignalEvent event) async {
          if (event is PointerScrollEvent) {
            final scaleChange = event.scrollDelta.dy < 0
                ? scaleFactor
                : 1 / scaleFactor;
            _handleZoom(scaleChange, event.localPosition);
          }
        },
        child: GestureDetector(
          onPanStart: (event) {
            if (_aiSearch) {
              setState(() {
                _snapshotBoxStart = event.localPosition;
                _shouldShow = true;
              });
              return;
            }

            _panAnimationController.stop();
            _animationController.stop();
          },
          onPanEnd: _onPanEnd,
          onPanUpdate: _onPanMove,
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
          child: RepaintBoundary(
            key: _repaintBoundaryKey,
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
                isAiSearch: _aiSearch,
                snapshotBoxSize: _snapshotBoxSize,
                snapshotBoxStartPos: _snapshotBoxStart,
                shouldShow: _shouldShow,
              ),
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
          padding: EdgeInsets.only(right: 8),
          height: 40,
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Wrap(
            direction: Axis.horizontal,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
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
          height: 40,
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
              const SizedBox(width: 10), // Separator
              // 2. "Show Label" Switch (New, assumes 'isShowingLabel' is the state variable)
              _buildSwitchControl(
                label: 'AI Search',
                value: _aiSearch,
                onChanged: (v) {
                  setState(() {
                    _aiSearch = v;
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

  Align _buildCreditLink() {
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: InkWell(
          onTap: () => launchURL(widget.creditLink),
          child: Text(
            'Credit: ${widget.creditTitle}',
            style: TextStyle(
              fontSize: 12.0,
              color: Colors.blue[300],
              decoration: TextDecoration.underline,
            ),
          ),
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
