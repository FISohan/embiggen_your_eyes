import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
//https://sohan.sgp1.digitaloceanspaces.com/tiles/galaxies_img_7_9_93.png
Future<ui.Image> loadNetworkImage(int x, int y, int z, String key) async {
  String url =
      "https://sohan.sgp1.digitaloceanspaces.com/tiles/${key}_${z}_${y}_${x}.png";
  final completer = Completer<ui.Image>();
  final NetworkImage networkImage = NetworkImage(url);
  final ImageStream stream = networkImage.resolve(ImageConfiguration());
  late ImageStreamListener listener;
  listener = ImageStreamListener((ImageInfo info, bool _) {
    completer.complete(info.image);
    stream.removeListener(listener);
  });
  stream.addListener(listener);
  return completer.future;
}
