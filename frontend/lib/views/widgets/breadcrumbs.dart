import 'package:flutter/material.dart';

class BreadcrumbItem {
  final String label;
  final VoidCallback? onTap;

  const BreadcrumbItem({
    required this.label,
    this.onTap,
  });
}

class Breadcrumbs extends StatelessWidget {
  final List<BreadcrumbItem> items;

  const Breadcrumbs({
    super.key,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(items.length * 2 - 1, (index) {
          if (index.isOdd) {
            return const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6.0),
              child: Icon(
                Icons.chevron_right_rounded,
                color: Colors.white70,
                size: 16,
              ),
            );
          }

          final itemIndex = index ~/ 2;
          final item = items[itemIndex];
          final isLast = itemIndex == items.length - 1;

          if (isLast || item.onTap == null) {
            return Text(
              item.label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            );
          }

          return _ClickableBreadcrumbItem(
            label: item.label,
            onTap: item.onTap!,
          );
        }),
      ),
    );
  }
}

class _ClickableBreadcrumbItem extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _ClickableBreadcrumbItem({
    required this.label,
    required this.onTap,
  });

  @override
  State<_ClickableBreadcrumbItem> createState() => _ClickableBreadcrumbItemState();
}

class _ClickableBreadcrumbItemState extends State<_ClickableBreadcrumbItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 150),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: _isHovered ? Colors.white : Colors.white.withOpacity(0.85),
            decoration: _isHovered ? TextDecoration.underline : TextDecoration.none,
            decorationColor: Colors.white,
          ),
          child: Text(widget.label),
        ),
      ),
    );
  }
}
