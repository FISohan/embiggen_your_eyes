import 'dart:ui';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:stellar_zoom/ai.dart';
// Removed: import 'tts_service.dart';

// --- Modular Text Widget ---
/// Renders a scrollable text area for potentially lengthy results.
class _ScrollableResultText extends StatelessWidget {
  final String? text;
  final bool showAddButton;
  final VoidCallback? onAddLabel;

  const _ScrollableResultText(
      {required this.text, this.showAddButton = false, this.onAddLabel});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.only(
            top: 8.0,
            bottom: 8.0,
            left: 8.0,
            right: 38.0, // Make space for the button
          ),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SingleChildScrollView(
            child: MarkdownBlock(data: text ?? "Wait.."),
          ),
        ),
        if (showAddButton)
          Positioned(
            top: 0,
            right: 0,
            child: _ActionButton(
              icon: Icons.label_outline,
              onTap: onAddLabel,
              size: 18,
              padding: const EdgeInsets.all(6),
            ),
          ),
      ],
    );
  }
}

// --- Modular Action Button Widget (Compact) ---
// Simplified to just an icon button without a text label
class _ActionButton extends StatelessWidget {
// ... (rest of the file is unchanged)
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
  final VoidCallback? onClose;
  final String? creditLink;
  final Function(String responseText)? onAddLabel;

  const Searchpanel(
      {super.key,
      required this.image,
      this.onClose,
      this.creditLink,
      this.onAddLabel});

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
      height: 490,
      child: Stack(
        children: [
          // 1. The blurry, transparent background layer (Glassmorphism effect)
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(
                    30,
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
final prompt = '''
You are an expert astronomer and astrophysicist. Your goal is to analyze the provided image and explain it clearly.

**IMPORTANT INSTRUCTIONS:**
*   **Language:** Explain everything in simple, easy-to-understand English.
*   **Accuracy:** Prioritize scientific accuracy. If the image is unclear or you are not certain about an identification, clearly state your uncertainty rather than guessing. Do not invent information.

**CONTEXT:**
The image is a user-selected, zoomed-in region from a larger astronomical photograph. Use the context from this URL about the original, full image to inform your analysis: ${widget.creditLink}

**RESPONSE FORMAT:**
Your response must be formatted in Markdown as follows:

### [A CLEAR AND SIMPLE TITLE FOR THE ANALYSIS]

**1. What Am I Seeing?**
Based on the visual information and the provided context, identify the most likely celestial objects or phenomena visible. Describe the general type of object and its main characteristics.

**2. Scientific Context:**
If known, name the larger object this crop belongs to. Provide a concise, scientific explanation of what is being shown in this specific region.

**3. Key Features:**
Using a bulleted list, point out any notable features visible *within this cropped image*. This could include prominent stars, dust lanes, gas clouds, or unique shapes.

**4. Interesting Facts:**
Conclude with one or two fascinating and confirmed facts about the identified object or phenomenon.
''';
                        setState(() {
                          responseText.clear();
                          contentTextStream = askAI(prompt, widget.image!);
                        });
                      },
                    ),
                    // Save (Download) Button
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
                                    child: StreamBuilder(
                                      stream: contentTextStream,
                                      builder: (context, asyncSnapshot) {
                                        if (asyncSnapshot.connectionState ==
                                            ConnectionState.waiting) {
                                          return Center(child: CircularProgressIndicator());
                                        }
                
                                        if (asyncSnapshot.hasError) {
                                          return Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Text(
                                              "Something went wrong. ${asyncSnapshot.error}.Please Search Again.",
                                              style: TextStyle(color: Colors.red),
                                            ),
                                          );
                                        }
                                        if (asyncSnapshot.hasData) {
                                          responseText.write(asyncSnapshot.data!.text);
                                        }
                
                                        bool isDone = asyncSnapshot.connectionState == ConnectionState.done;
                
                                        return _ScrollableResultText(
                                          text: responseText.toString(),
                                          showAddButton: isDone && responseText.isNotEmpty,
                                          onAddLabel: () {
                                            widget.onAddLabel?.call(responseText.toString());
                                            widget.onClose?.call();
                                          },
                                        );
                                      },
                                    ),
                                  )                else
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
