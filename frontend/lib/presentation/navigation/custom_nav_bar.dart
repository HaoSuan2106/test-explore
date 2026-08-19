import 'package:flutter/material.dart';

const Color kNavSelectedColor = Color(0xFFAB3510);
const Color kNavUnselectedColor = Color(0xFF5C382E);

class NavItemData {
  final IconData icon;
  final String label;

  const NavItemData({
    required this.icon,
    required this.label,
  });
}

class CustomNavBar extends StatelessWidget {
  final List<NavItemData> items;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const CustomNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
      ),
      child: Row(
        children: List.generate(items.length, (index) {
          final item = items[index];
          final isSelected = index == selectedIndex;
          final color = isSelected ? kNavSelectedColor : kNavUnselectedColor;

          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(index),
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(item.icon, color: color, size: 24),
                  const SizedBox(height: 4),
                  Text(
                    item.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: color,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}