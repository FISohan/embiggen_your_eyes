import 'dart:ui';
import 'package:flutter/material.dart';

// The BlurryCard widget is now a StatefulWidget to manage the state of the input fields.
class BlurryCard extends StatefulWidget {
  final String title;
  final String description;
  final VoidCallback? onClosePressed;
  final VoidCallback? onDeletePressed;
  final bool editable;
  final void Function(
    String title,
    String description,
    double width,
    double height,
  )? onAddLabel;

  final void Function(double width, double height)? boxValueChange;

  const BlurryCard({
    super.key,
    this.title = 'Title',
    this.description = 'Description',
    this.onClosePressed,
    this.onDeletePressed,
    this.editable = false,
    this.onAddLabel,
    this.boxValueChange,
  });

  @override
  State<BlurryCard> createState() => _BlurryCardState();
}

class _BlurryCardState extends State<BlurryCard> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _widthController = TextEditingController();
  final _heightController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Initialize controllers with default values if not in editable mode.
    if (!widget.editable) {
      _titleController.text = widget.title;
      _descriptionController.text = widget.description;
    } else {
      // Set default values to 0 when in editable mode.
      _widthController.text = '0';
      _heightController.text = '0';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      height: widget.editable ? 400 : 400,
      child: Stack(
        children: [
          // The blurry, transparent background layer
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
              ),
            ),
          ),

          // Conditional rendering based on the 'editable' parameter
          if (widget.editable) _buildEditableForm(widget.boxValueChange) else _buildDisplayCard(),
        ],
      ),
    );
  }

  Widget _buildEditableForm(
    final void Function(double width, double height)? boxValueChange,
  ) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            20.0,
            48.0,
            20.0,
            20.0,
          ), // Added top padding to prevent overlap with the close button
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title input
                _buildTextField(
                  _titleController,
                  'Title',
                  onChange: (value) {},
                ),
                const SizedBox(height: 12),
                // Description input
                _buildTextField(
                  onChange: (value) {},
                  _descriptionController,
                  'Description',
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // Width input
                    Expanded(
                      child: _buildTextField(
                        onChange: (value) {
                          final double? width = double.tryParse(value);
                          final double? height = double.tryParse(_heightController.text);
                          if (width != null && height != null && boxValueChange != null) {
                            boxValueChange(width, height);
                          }
                        },
                        _widthController,
                        'Box Width',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Height input
                    Expanded(
                      child: _buildTextField(
                        _heightController,
                        'Box Height',
                        keyboardType: TextInputType.number,
                        onChange: (value) {
                          final double? width = double.tryParse(_widthController.text);
                          final double? height = double.tryParse(value);
                          if (width != null && height != null && boxValueChange != null) {
                            boxValueChange(width, height);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Add Label button
                ElevatedButton(
                  onPressed: () {
                    if (widget.onAddLabel != null) {
                      final double? width = double.tryParse(
                        _widthController.text,
                      );
                      final double? height = double.tryParse(
                        _heightController.text,
                      );

                      if (width != null && height != null) {
                        widget.onAddLabel!(
                          _titleController.text,
                          _descriptionController.text,
                          width,
                          height,
                        );
                      } else {
                        // Handle invalid number input, e.g., show a snackbar or dialog
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please enter valid numbers for width and height.',
                            ),
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black.withOpacity(0.2),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Add Label'),
                ),
              ],
            ),
          ),
        ),
        // Close button for editable form
        Positioned(
          top: 8.0,
          right: 8.0,
          child: IconButton(
            onPressed: widget.onClosePressed,
            icon: const Icon(Icons.close, color: Colors.white),
            tooltip: 'Close',
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    int? maxLines,
    TextInputType? keyboardType,
    required void Function(String value) onChange,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      keyboardType: keyboardType,
      maxLines: maxLines,
      onChanged: onChange,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
        filled: true,
        fillColor: Colors.black.withOpacity(0.2),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildDisplayCard() {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            20.0,
            48.0,
            20.0,
            20.0,
          ), // Added top padding to prevent overlap
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    widget.description,
                    style: const TextStyle(fontSize: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Action buttons positioned in the top-right corner
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Align(
            alignment: Alignment.topRight,
            child: Row(
              children: [
                IconButton(
                  onPressed: widget.onClosePressed,
                  icon: const Icon(Icons.close, color: Colors.white),
                  tooltip: 'Close',
                ),
                IconButton(
                  onPressed: widget.onDeletePressed,
                  icon: const Icon(Icons.delete_outline, color: Colors.white),
                  tooltip: 'Delete',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
