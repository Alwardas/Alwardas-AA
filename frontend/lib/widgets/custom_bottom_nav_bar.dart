import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/providers/theme_provider.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final List<BottomNavigationBarItem> items;
  final Color? selectedItemColor;
  final Color? unselectedItemColor;
  final Color? backgroundColor;

  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.selectedItemColor,
    this.unselectedItemColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    bool isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    if (isKeyboardVisible) return const SizedBox.shrink(); // Hide if keyboard is up

    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final theme = Theme.of(context);

    // Increase Base Height
    const double barHeight = 80.0; 
    const double circleSize = 60.0; 

    final Color effectiveBgColor = backgroundColor ?? (isDark ? const Color(0xFF1E293B) : Colors.white);
    final Color activeColor = selectedItemColor ?? theme.primaryColor;
    final Color inactiveColor = unselectedItemColor ?? (isDark ? Colors.grey[400] : Colors.grey[500])!;

    return Padding(
      // Floating margins
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10), 
      child: SafeArea(
        top: false,
        child: Container(
          height: barHeight,
          decoration: BoxDecoration(
            color: effectiveBgColor,
            borderRadius: BorderRadius.circular(40), // More rounded
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.4 : 0.15),
                blurRadius: 25,
                spreadRadius: 2,
                offset: const Offset(0, 10),
              ),
            ],
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: items.asMap().entries.map((entry) {
              final int index = entry.key;
              final BottomNavigationBarItem item = entry.value;
              final bool isSelected = index == currentIndex;
              
              return Tooltip(
                message: item.label ?? '',
                child: GestureDetector(
                  onTap: () => onTap(index),
                  behavior: HitTestBehavior.opaque,
                  child: TweenAnimationBuilder<double>(
                     tween: Tween(begin: 0.0, end: isSelected ? 1.0 : 0.0),
                     duration: const Duration(milliseconds: 400),
                     curve: Curves.easeOutBack, // Bouncy "popup" effect
                     builder: (context, value, child) {
                        return Transform.translate(
                          // Popup logic: Move UP (-Y) when selected.
                          // Value 1 => -5 offset (keeps it mostly inside)
                          offset: Offset(0, -5 * value), 
                          child: Container(
                            width: circleSize, 
                            height: circleSize,
                            decoration: BoxDecoration(
                              color: isSelected ? activeColor : Colors.transparent,
                              shape: BoxShape.circle,
                              boxShadow: isSelected 
                                ? [
                                    BoxShadow(
                                      color: activeColor.withOpacity(0.4 * value),
                                      blurRadius: 15,
                                      offset: const Offset(0, 8),
                                    )
                                  ] 
                                : null,
                            ),
                            child: Center(
                              child: IconTheme( // Ensure icon style updates
                                data: IconThemeData(
                                  color: isSelected ? Colors.white : inactiveColor,
                                  size: 28 + (4 * value), 
                                ),
                                child: isSelected && item.activeIcon != null 
                                    ? item.activeIcon! 
                                    : item.icon,
                              ),
                            ),
                          ),
                        );
                     },
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
