import 'dart:ui';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_downloader_web/image_downloader_web.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'dart:async';
import 'dart:math';
import 'package:stellar_zoom/ai.dart';
import 'package:stellar_zoom/facts.dart';

// Removed: import 'tts_service.dart';

// --- Modular Text Widget ---
/// Renders a scrollable text area for potentially lengthy results.
class _ScrollableResultText extends StatelessWidget {
  final String? text;
  final bool showAddButton;
  final VoidCallback? onAddLabel;

  const _ScrollableResultText({
    required this.text,
    this.showAddButton = false,
    this.onAddLabel,
  });

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
            child: MarkdownBlock(
              data: text ?? "Wait..",
              config: MarkdownConfig(
                configs: [PConfig(textStyle: TextStyle(color: Colors.white))],
              ),
            ),
          ),
        ),
        if (showAddButton)
          Positioned(
            top: 4,
            right: 4,
            child: Tooltip(
              message: 'Create Label from Result',
              child: _ActionButton(
                icon: Icons.label_outline,
                onTap: onAddLabel,
                size: 20,
                padding: const EdgeInsets.all(10.0),
              ),
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

  const Searchpanel({
    super.key,
    required this.image,
    this.onClose,
    this.creditLink,
    this.onAddLabel,
  });

  @override
  State<Searchpanel> createState() => _SearchpanelState();
}

class _SearchpanelState extends State<Searchpanel> {
  Stream<GenerateContentResponse>? contentTextStream;
  StringBuffer responseText = StringBuffer();
  bool _isDownloading = false;
  bool _isSearching = false;
  String? _randomFact;
  String _selectedLanguage = 'English';
  bool _isLabelAdded = false;
  final List<String> _languages = [
    'English',
    'Spanish',
    'Hindi',
    'Arabic',
    'French',
    'Bengali',
    'Russian',
    'Portuguese',
    'German',
    'Chinese (Simplified)',
  ];

  @override
  void initState() {
    super.initState();
    _randomFact = _getNewFact();
  }

  String _getNewFact() {
    final random = Random();
    return spaceFacts[random.nextInt(spaceFacts.length)];
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return SizedBox(
      width: min(400, screenWidth * 0.9),
      height: MediaQuery.of(context).size.height * 0.95,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(30),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withAlpha(150),
                    width: 1,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 150,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.black.withOpacity(0.3),
                  ),
                  child: Center(
                    child: widget.image == null
                        ? const Text(
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ActionButton(
                      icon: Icons.search,
                      onTap: _isSearching
                          ? null
                          : () {
                              final prompt =
                                  '''
**ROLE AND TASK:**
You are a Senior Research Astronomer and Astrophysicist. Your task is to analyze the provided astronomical image and its accompanying context link. Your goal is to produce a scientifically accurate and accessible description.

**INPUT DATA:**
1.  **IMAGE:** [An astronomical photograph.]
2.  **CONTEXT LINK (CRITICAL):** ${widget.creditLink} - You MUST base your analysis on the information found at this link.
3.  **LANGUAGE:** $_selectedLanguage

**GUIDELINES:**
*   **Accuracy is Paramount:** Base all claims EXCLUSIVELY on the provided image and the context link. Do not use outside knowledge.
*   **Cite Your Sources:** When you state a fact (like name, distance, or scientific process), quote or paraphrase from the context link to show where you got the information.
*   **Handle Uncertainty:** If the context link doesn't provide enough information to answer something, explicitly state that the information is not available in the source. For example, "The source does not specify the object's distance." Do not invent information.
*   **Tone:** Write for an educated but non-specialist audience. Be clear and engaging.
*   **Flexibility:** The image and context will vary. Adapt your response to what is available. You don't need to follow a rigid structure if the information isn't there.

**SUGGESTED RESPONSE STRUCTURE:**
Your response must start with a title in Markdown heading format (e.g., `### Title of Analysis`).

Then, try to cover the following points, if the information is available in the context link:

*   **Identification and Overview:** What is the main object or region in the image? (e.g., spiral galaxy, star-forming region).
*   **Visual Details:** Describe the most interesting features you can see in the zoomed-in image.
*   **Scientific Significance:** Why is this object important for astronomers? What can we learn from it?
*   **Key Facts:** Share 1-3 interesting, confirmed facts about the object from the context link.
*   **Reference:** If the context link provides an official reference link (e.g., from NASA, ESA), please include it.

Remember, this is a flexible guide. Focus on creating an informative and accurate description based on the provided materials.
''';
                              setState(() {
                                _isSearching = true;
                                _randomFact = _getNewFact();
                                responseText.clear();
                                _isLabelAdded = false; // Reset here
                                contentTextStream = askAI(
                                  prompt,
                                  widget.image!,
                                );
                              });
                            },
                    ),
                    _isDownloading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.0,
                              color: Colors.white,
                            ),
                          )
                        : _ActionButton(
                            icon: Icons.download,
                            onTap: () async {
                              if (widget.image == null) return;
                              setState(() {
                                _isDownloading = true;
                              });
                              try {
                                await WebImageDownloader.downloadImageFromUInt8List(
                                  uInt8List: widget.image!,
                                  name: 'stellar_zoom_crop',
                                );
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Download failed: $e'),
                                    ),
                                  );
                                }
                              } finally {
                                if (mounted) {
                                  setState(() {
                                    _isDownloading = false;
                                  });
                                }
                              }
                            },
                          ),
                    PopupMenuButton<String>(
                      onSelected: (String newValue) {
                        setState(() {
                          _selectedLanguage = newValue;
                        });
                      },
                      color: Colors.grey[850]?.withOpacity(0.9),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      tooltip: 'Select Language ($_selectedLanguage)',
                      offset: const Offset(0, 40),
                      itemBuilder: (BuildContext context) {
                        return _languages.map((String language) {
                          return PopupMenuItem<String>(
                            value: language,
                            child: Text(
                              language,
                              style: const TextStyle(color: Colors.white),
                            ),
                          );
                        }).toList();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.language,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    _ActionButton(icon: Icons.close, onTap: widget.onClose),
                  ],
                ),
                const SizedBox(height: 16),
                if (contentTextStream != null)
                  Expanded(
                    child: StreamBuilder(
                      stream: contentTextStream,
                      builder: (context, asyncSnapshot) {
                        if (asyncSnapshot.connectionState !=
                                ConnectionState.done &&
                            asyncSnapshot.connectionState !=
                                ConnectionState.none) {
                          // Stream is running
                        } else {
                          // Stream is done, has error, or is null
                          if (_isSearching) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) {
                                setState(() {
                                  _isSearching = false;
                                });
                              }
                            });
                          }
                        }

                        if (asyncSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const CircularProgressIndicator(),
                                  const SizedBox(height: 24),
                                  Text(
                                    _randomFact ?? 'Did you know...',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        if (asyncSnapshot.hasError) {
                          return Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              "Something went wrong. ${asyncSnapshot.error}.Please Search Again.",
                              style: const TextStyle(color: Colors.red),
                            ),
                          );
                        }
                        if (asyncSnapshot.hasData) {
                          responseText.write(asyncSnapshot.data!.text);
                        }

                        bool isDone =
                            asyncSnapshot.connectionState ==
                            ConnectionState.done;
                        final sanitizedText = responseText
                            .toString()
                            .replaceAll('\$', r'\$');

                        return _ScrollableResultText(
                          text: sanitizedText,
                          showAddButton: isDone && responseText.isNotEmpty,
                          onAddLabel: _isLabelAdded
                              ? null
                              : () {
                                  widget.onAddLabel?.call(
                                    responseText.toString(),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        "Label added successfully!",
                                      ),
                                    ),
                                  );
                                  setState(() {
                                    _isLabelAdded = true;
                                  });
                                },
                        );
                      },
                    ),
                  )
                else
                  Expanded(
                    child: Center(
                      child: Text(
                        "Search results will appear here.",
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                const Text(
                  "AI-generated content may be inaccurate. Please verify critical information.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
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
