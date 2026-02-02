import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CustomModalDropdown extends StatefulWidget {
  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  const CustomModalDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  State<CustomModalDropdown> createState() => _CustomModalDropdownState();
}

class _CustomModalDropdownState extends State<CustomModalDropdown> {
  void _showSelectionModal() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 5,
          backgroundColor: Colors.white,
          child: Container(
            padding: const EdgeInsets.all(20),
            width: double.maxFinite,
            constraints: const BoxConstraints(maxHeight: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Select ${widget.label}',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF333333),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF333333)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(height: 1, color: Color(0xFFEEEEEE)),
                const SizedBox(height: 10),
                // List
                Expanded(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: widget.options.length,
                    separatorBuilder: (ctx, i) => const Divider(height: 1, color: Color(0xFFF0F0F0)),
                    itemBuilder: (context, index) {
                      final option = widget.options[index];
                      return InkWell(
                        onTap: () {
                          widget.onChanged(option);
                          Navigator.pop(context);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          child: Text(
                            option,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: const Color(0xFF333333),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _showSelectionModal,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEEEEEE)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.value ?? 'Select ${widget.label}',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: widget.value != null ? const Color(0xFF333333) : const Color(0xFF999999),
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down, color: Color(0xFF666666)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
