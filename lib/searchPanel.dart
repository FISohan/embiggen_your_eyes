import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class Searchpanel extends StatefulWidget {
  final Uint8List? image;
  const Searchpanel({super.key, required this.image});
  @override
  State<Searchpanel> createState() => _SearchpanelState();
}

class _SearchpanelState extends State<Searchpanel> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      height: 450, // Increased height for the new input
      child: Stack(
        children: [
          // The blurry, transparent background layer
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(100),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withAlpha(100),
                    width: 1,
                  ),
                ),
              ),
            ),
          ),
          widget.image == null
              ? Text("Wait..")
              : SizedBox(
                  width: 300, // The target width
                  height: 150, // The target height
                  child: Image.memory(
                    widget.image!,
                    // Use the appropriate fit property here
                    fit: BoxFit.contain,
                  ),
                ),
        ],
      ),
    );
  }
}
