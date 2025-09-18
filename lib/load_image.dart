import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

Future<ui.Image> loadNetworkImage(int x, int y, int z) async {
  String url =
      "https://res.cloudinary.com/difzsueph/image/upload/galaxies_img_${z}_${y}_${x}.png";
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
