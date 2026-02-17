
  Widget _buildAnnouncementsLoadingState(bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(3, (index) {
          return Padding(
            padding: const EdgeInsets.only(right: 15),
            child: Shimmer.fromColors(
              baseColor: isDark ? const Color(0xFF1E293B) : Colors.grey[300]!,
              highlightColor: isDark ? const Color(0xFF334155) : Colors.grey[100]!,
              child: Container(
                width: 250,
                height: 90,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
