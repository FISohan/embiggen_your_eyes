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
    'Chinese (Simplified)'
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
    return SizedBox(
      width: 300,
      height: 490,
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
                              final prompt = '''
**ROLE AND TASK:**
You are a Senior Research Astronomer and Astrophysicist specializing in deep-field imaging and star formation science. Your primary task is to conduct a detailed, scientifically rigorous analysis of the provided zoomed-in astronomical image. You must use the associated context link to ensure the object's identity, distance, and scientific significance are accurately reflected.

**INPUT DATA:**
1.  **IMAGE:** [The zoomed-in astronomical photograph to be analyzed is provided separately.]
2.  **CONTEXT LINK (CRITICAL):** ${widget.creditLink}
3.  **LANGUAGE:** $_selectedLanguage

**GOALS & CONSTRAINTS:**
* **Tone:** Professional, clear, and accessible to an educated layperson. Avoid overly technical jargon without immediate explanation.
* **Accuracy First:** All scientific claims must be based on confirmed astronomical data obtained via the context link or related searches. If the image features are ambiguous, state the most probable identity and explicitly mention the uncertainty.
* **Output Start:** **THE VERY FIRST LINE** of your response must be the title heading (###).
* **Output Format:** Adhere strictly to the following five-section Markdown structure.

**REQUIRED RESPONSE FORMAT:**

### [A CLEAR AND SIMPLE TITLE FOR THE ANALYSIS]

**1. Core Identification & Visual Context:**
Based on the input, name the most likely celestial object or phenomenon. Describe the object's general category (e.g., stellar nursery, interacting galaxy pair, stellar jet) and its apparent scale or size relative to the full original image.

**2. Scientific Foundation & Formation Context:**
Use information from the original source (implied by `${widget.creditLink}`) to provide the official scientific catalog designation (e.g., NGC, Messier, or IC number) and the object's confirmed astronomical distance or redshift value. **Explain the object's formation, evolution, or origin in concise detail** (e.g., created by a supernova, formed via galactic merger, or carved by UV radiation from hot stars).

**3. Detailed Feature Analysis (Within Crop):**
Use a bulleted list to identify and explain at least three distinct, fine-scale features visible **only in the provided zoomed image**.
* [Feature 1: Descriptive Name] - [Scientific Explanation/Significance]
* [Feature 2: Descriptive Name] - [Scientific Explanation/Significance]
* [Feature 3: Descriptive Name] - [Scientific Explanation/Significance]

**4. Astrophysical Significance:**
Explain, in a concise paragraph, why this region or object is important to the broader field of astrophysics (e.g., What specific cosmological or stellar evolution models does it support? What new data does it provide?).

**5. Confirmed Facts:**
Conclude with two confirmed and compelling facts about the celestial body. (Do not repeat the distance, official designation, or primary object name.).
''';
                              setState(() {
                                _isSearching = true;
                                _randomFact = _getNewFact();
                                responseText.clear();
                                contentTextStream = askAI(prompt, widget.image!);
                              });
                            },
                    ),
                    _isDownloading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.0, color: Colors.white),
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
                                    SnackBar(content: Text('Download failed: $e')),
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
                          borderRadius: BorderRadius.circular(8)),
                      tooltip: 'Select Language ($_selectedLanguage)',
                      offset: const Offset(0, 40),
                      itemBuilder: (BuildContext context) {
                        return _languages.map((String language) {
                          return PopupMenuItem<String>(
                            value: language,
                            child: Text(language,
                                style: const TextStyle(color: Colors.white)),
                          );
                        }).toList();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.language,
                            color: Colors.white, size: 20),
                      ),
                    ),
                    _ActionButton(
                      icon: Icons.close,
                      onTap: widget.onClose,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (contentTextStream != null)
                  Expanded(
                    child: StreamBuilder(
                      stream: contentTextStream,
                      builder: (context, asyncSnapshot) {
                        if (asyncSnapshot.connectionState != ConnectionState.done &&
                            asyncSnapshot.connectionState != ConnectionState.none) {
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

                        if (asyncSnapshot.connectionState == ConnectionState.waiting) {
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
                                    style: const TextStyle(color: Colors.white, fontSize: 16),
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

                        bool isDone = asyncSnapshot.connectionState == ConnectionState.done;
                        final sanitizedText = responseText.toString().replaceAll('\$', r'\$');

                        return _ScrollableResultText(
                          text: sanitizedText,
                          showAddButton: isDone && responseText.isNotEmpty,
                          onAddLabel: () {
                            widget.onAddLabel?.call(responseText.toString());
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
