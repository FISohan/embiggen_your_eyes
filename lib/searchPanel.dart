import 'dart:ui';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:stellar_zoom/ai.dart';
// Removed: import 'tts_service.dart';

// --- Modular Text Widget ---
/// Renders a scrollable text area for potentially lengthy results.
class _ScrollableResultText extends StatelessWidget {
  final String? text;

  const _ScrollableResultText({required this.text});

  @override
  Widget build(BuildContext context) {
    // Padding adjusted to create space for the overlaid button in the top right corner
    return Container(
      padding: const EdgeInsets.only(
        top: 8.0,
        bottom: 8.0,
        left: 8.0,
        right: 40.0,
      ),
      // A slight, subtle border for visual separation
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        child: Text(
          text ?? "Wait..",
          style: TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
        ),
      ),
    );
  }
}

// --- Modular Action Button Widget (Compact) ---
// Simplified to just an icon button without a text label
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final EdgeInsets padding;

  const _ActionButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 20, // Default size for row buttons
    this.padding = const EdgeInsets.all(8.0), // Default padding for row buttons
  });

  @override
  Widget build(BuildContext context) {
    // Use an Opacity widget to visually indicate when a button is disabled (no onTap)
    final double opacity = onTap == null ? 0.4 : 1.0;

    return Opacity(
      opacity: opacity,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(50),
        child: Container(
          padding: padding, // Using the custom padding
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: size),
        ),
      ),
    );
  }
}

// --- Main Searchpanel Widget ---
class Searchpanel extends StatefulWidget {
  final Uint8List? image;
  // Callback to notify the parent when the panel should close
  final VoidCallback? onClose;
  // The result text to be displayed and scrolled

  const Searchpanel({super.key, required this.image, this.onClose});

  @override
  State<Searchpanel> createState() => _SearchpanelState();
}

class _SearchpanelState extends State<Searchpanel> {
  Stream<GenerateContentResponse>? contentTextStream;
  StringBuffer responseText = StringBuffer();

  @override
  Widget build(BuildContext context) {
    // Determine the text content for the panel.
    return SizedBox(
      width: 300,
      height: 450,
      child: Stack(
        children: [
          // 1. The blurry, transparent background layer (Glassmorphism effect)
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(
                    100,
                  ), // Slightly darker for better contrast
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withAlpha(150),
                    width: 1,
                  ),
                ),
              ),
            ),
          ),

          // 2. Content (Image, Buttons, Text)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- Image Section (1st Element) ---
                Container(
                  height: 150,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.black.withOpacity(0.3),
                  ),
                  child: Center(
                    child: widget.image == null
                        ? Text(
                            "Waiting for image...",
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 16,
                            ),
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(
                              widget.image!,
                              fit: BoxFit.contain,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 16),

                // --- Action Button Row (2nd Element - Search, Save, Close) ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Search Button
                    _ActionButton(
                      icon: Icons.search,
                      onTap: () {
                        setState(() {
                          responseText.clear();
                          contentTextStream = askAI(
                            "What's in the picture?",
                            widget.image!,
                          );
                        });
                      },
                    ),
                    // Save (Download) Button
                    _ActionButton(
                      icon: Icons.download,
                      onTap: () {
                        if (kDebugMode) print('Save action triggered!');
                      },
                    ),
                    // Close Button
                    _ActionButton(
                      icon: Icons.close,
                      onTap: widget.onClose, // Calls the parent's function
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // --- Scrollable Text Widget Section (3rd Element, takes remaining space) ---
                if (contentTextStream != null) // Check for content existence
                  Expanded(
                    child: Stack(
                      children: [
                        // Modular text widget for conditional rendering and scrolling
                        StreamBuilder(
                          stream: contentTextStream,
                          builder: (context, asyncSnapshot) {
                            if (asyncSnapshot.connectionState ==
                                ConnectionState.waiting) {
                              return Center(child: CircularProgressIndicator());
                            }

                            if (asyncSnapshot.hasError) {
                              return Text(
                                "Something went wrong:: ${asyncSnapshot.error}",
                                style: TextStyle(color: Colors.red),
                              );
                            }
                            if (asyncSnapshot.hasData) {
                              responseText.write(asyncSnapshot.data!.text);
                            }
                            return _ScrollableResultText(
                              text: responseText.toString(),
                            );
                          },
                        ),

                        // Play/Pause Audio Button (Overlaid on the top right corner of the text widget)
                        Positioned(
                          top: 4, // Compact position
                          right: 4, // Compact position
                          child: _ActionButton(
                            icon: Icons
                                .play_circle_filled, // Hardcoded icon (no state logic)
                            size: 24, // Compact size
                            padding: const EdgeInsets.all(
                              4.0,
                            ), // Compact padding
                            // Placeholder onTap to show UI is functional but implementation is removed
                            onTap: () {
                              if (kDebugMode)
                                print(
                                  'Play/Pause UI button tapped (Implementation needed)',
                                );
                            },
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  // Placeholder/Spacer if no text result is present
                  Expanded(
                    child: Center(
                      child: Text(
                        "Search results will appear here.",
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
