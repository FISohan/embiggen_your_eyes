import 'dart:ui';
import 'package:flutter/material.dart';

// 1. Define the enum for the categories based on the image
enum LabelCategory {
  stars,
  galaxies,
  nebula,
  exotic,
  exoplanet,
}

// Extension to provide display details for the enum
extension LabelCategoryDetails on LabelCategory {
  String get name {
    switch (this) {
      case LabelCategory.stars:
        return 'STARS';
      case LabelCategory.galaxies:
        return 'GALAXIES';
      case LabelCategory.nebula:
        return 'NEBULA';
      case LabelCategory.exotic:
        return 'EXOTIC';
      case LabelCategory.exoplanet:
        return 'EXOPLANET';
    }
  }

  IconData get icon {
    switch (this) {
      case LabelCategory.stars:
        return Icons.star; // Closest material icon for star
      case LabelCategory.galaxies:
        return Icons.radar; // Stylized concentric circles
      case LabelCategory.nebula:
        return Icons.cloud; // Cloud/nebulous shape
      case LabelCategory.exotic:
        return Icons.all_inclusive; // Swirl/infinity-like
      case LabelCategory.exoplanet:
        return Icons.circle; // Simple planet/dot
    }
  }

  Color get color {
    switch (this) {
      case LabelCategory.stars:
        return Colors.deepPurple;
      case LabelCategory.galaxies:
        return Colors.orange;
      case LabelCategory.nebula:
        return Colors.pink;
      case LabelCategory.exotic:
        return Colors.yellow;
      case LabelCategory.exoplanet:
        return Colors.teal;
    }
  }
}

// The BlurryCard widget is now a StatefulWidget to manage the state of the input fields.
class BlurryCard extends StatefulWidget {
  final String title;
  final String description;
  final VoidCallback? onClosePressed; // Used for the button next to 'Add Label'
  final VoidCallback? onFloatingClosePressed; // NEW: For the top-right 'X' button
  final VoidCallback? onDeletePressed;
  final bool editable;
  // 2. Updated onAddLabel to include LabelCategory
  final void Function(
    String title,
    String description,
    double width,
    double height,
    LabelCategory category, // NEW: Category input
  )? onAddLabel;

  final void Function(double width, double height)? boxValueChange;

  const BlurryCard({
    super.key,
    this.title = 'Title',
    this.description = 'Description',
    this.onClosePressed,
    this.onFloatingClosePressed,
    this.onDeletePressed,
    this.editable = false,
    this.onAddLabel,
    this.boxValueChange,
  });

  @override
  State<BlurryCard> createState() => _BlurryCardState();
}

class _BlurryCardState extends State<BlurryCard> {
  final _formKey = GlobalKey<FormState>(); // Key for form validation

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _widthController = TextEditingController();
  final _heightController = TextEditingController();
  
  // 3. State variable for the selected category
  LabelCategory? _selectedCategory;

  @override
  void initState() {
    super.initState();
    // Initialize controllers with default values if not in editable mode.
    if (!widget.editable) {
      _titleController.text = widget.title;
      _descriptionController.text = widget.description;
    } else {
      // Set default values and default category when in editable mode.
      _widthController.text = '0';
      _heightController.text = '0';
      _selectedCategory = LabelCategory.stars; // Default selection
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
      height: widget.editable ? 450 : 400, // Increased height for the new input
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

  // New widget for the category dropdown
  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<LabelCategory>(
      value: _selectedCategory,
      hint: Text(
        'Select Category',
        style: TextStyle(color: Colors.white.withOpacity(0.7)),
      ),
      validator: (value) {
        if (value == null) {
          return 'Please select a category';
        }
        return null;
      },
      onChanged: (LabelCategory? newValue) {
        setState(() {
          _selectedCategory = newValue;
        });
      },
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.black.withOpacity(0.2),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        // Match the error style of other TextFormFields
        errorStyle: const TextStyle(color: Colors.redAccent),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.redAccent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1),
        ),
      ),
      dropdownColor: Colors.grey.shade900.withOpacity(0.9), // Dark background for dropdown
      style: const TextStyle(color: Colors.white),
      items: LabelCategory.values.map((category) {
        return DropdownMenuItem<LabelCategory>(
          value: category,
          child: Row(
            children: [
              Icon(category.icon, color: category.color),
              const SizedBox(width: 8),
              Text(
                category.name,
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        );
      }).toList(),
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
          ),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Category Dropdown
                  _buildCategoryDropdown(),
                  const SizedBox(height: 12),
                  // Title input
                  _buildTextFormField(
                    _titleController,
                    'Title',
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Title cannot be empty';
                      }
                      return null;
                    },
                    onChange: (value) {},
                  ),
                  const SizedBox(height: 12),
                  // Description input
                  _buildTextFormField(
                    onChange: (value) {},
                    _descriptionController,
                    'Description',
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Description cannot be empty';
                      }
                      return null;
                    },
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Width input
                      Expanded(
                        child: _buildTextFormField(
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
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Required';
                            }
                            if (double.tryParse(value) == null) {
                              return 'Invalid number';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Height input
                      Expanded(
                        child: _buildTextFormField(
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
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Required';
                            }
                            if (double.tryParse(value) == null) {
                              return 'Invalid number';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Buttons Row: Close (secondary) and Add Label (primary)
                  Row(
                    children: [
                      // Close button (uses existing onClosePressed)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: widget.onClosePressed, // Uses onClosePressed
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(color: Colors.white.withOpacity(0.5)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Close'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Add Label button
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            // Validate all form fields
                            if (_formKey.currentState?.validate() ?? false) {
                              // 4. Update onAddLabel logic to pass the category
                              if (widget.onAddLabel != null && _selectedCategory != null) {
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
                                    _selectedCategory!, // Pass the selected category
                                  );
                                }
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.3),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Add Label'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        // Floating Close button for editable form
        Positioned(
          top: 8.0,
          right: 8.0,
          child: IconButton(
            onPressed: widget.onFloatingClosePressed,
            icon: const Icon(Icons.close, color: Colors.white),
            tooltip: 'Close Card',
          ),
        ),
      ],
    );
  }

  // Renamed and updated to TextFormField for validation
  Widget _buildTextFormField(
    TextEditingController controller,
    String hint, {
    int? maxLines,
    TextInputType? keyboardType,
    required void Function(String value) onChange,
    String? Function(String? value)? validator, // Added validator
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      keyboardType: keyboardType,
      maxLines: maxLines,
      onChanged: onChange,
      validator: validator, // Applied validator
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
        errorStyle: const TextStyle(color: Colors.redAccent), // Style for error text
        filled: true,
        fillColor: Colors.black.withOpacity(0.2),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedErrorBorder: OutlineInputBorder(
          // Ensures error state is visible
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.redAccent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          // Ensures error state is visible
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1),
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