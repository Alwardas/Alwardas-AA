import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BrandingSection extends StatelessWidget {
  final bool isTablet;
  final bool showLogo;

  const BrandingSection({
    super.key,
    this.isTablet = false,
    this.showLogo = true,
  });

  @override
  Widget build(BuildContext context) {
    // Determine font sizes based on device type
    final double spacing = isTablet ? 16.0 : 32.0;
    final double featureSpacing = isTablet ? 12.0 : 20.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Main Branding Logo Image (contains wave curves and name)
        if (showLogo) ...[
          Image.asset(
            'assets/images/college logo.png',
            width: isTablet ? 280 : 360,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Image.asset(
                'assets/images/logo.png',
                width: isTablet ? 280 : 360,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  // Code fallback if both image assets fail to load
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Since 1979',
                        style: GoogleFonts.poppins(
                          fontSize: isTablet ? 14 : 18,
                          fontWeight: FontWeight.w400,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'alwar das group',
                        style: GoogleFonts.poppins(
                          fontSize: isTablet ? 36 : 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'free mind through education',
                        style: GoogleFonts.poppins(
                          fontSize: isTablet ? 18 : 24,
                          fontStyle: FontStyle.italic,
                          color: const Color(0xFFFFD6D6),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
          SizedBox(height: spacing * 1.5),
        ],

        // Features Row
        Wrap(
          spacing: featureSpacing,
          runSpacing: 16.0,
          children: [
            _buildFeatureItem(
              Icons.school_outlined,
              'Quality\nEducation',
            ),
            if (!isTablet)
              Container(
                width: 1.5,
                height: 48,
                color: Colors.white.withValues(alpha: 0.2),
              ),
            _buildFeatureItem(
              Icons.menu_book_outlined,
              'Holistic\nDevelopment',
            ),
            if (!isTablet)
              Container(
                width: 1.5,
                height: 48,
                color: Colors.white.withValues(alpha: 0.2),
              ),
            _buildFeatureItem(
              Icons.groups_outlined,
              'Bright\nFuture',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeatureItem(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: isTablet ? 50 : 64,
          width: isTablet ? 50 : 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.15),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: isTablet ? 24 : 28,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: isTablet ? 13 : 15,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}
