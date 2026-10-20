/*
 * FLauncher
 * Copyright (C) 2021  Étienne Fesser
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/app_card.dart';
import 'package:flauncher/widgets/category_container_common.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app.dart';
import '../models/category.dart';

/// Fraction of a dock slot's width used by an icon box. The remainder becomes
/// the dynamic gap that lets icons grow and shrink without overlapping.
const double kDockIconWidthRatio = 0.75;

/// Breathing room around the sliding highlight so its border stays visible
/// next to the icon it surrounds.
const double kDockHighlightPad = 6.0;

/// macOS-style magnification curve: the focused icon grows the most, the
/// effect tapers with distance, and distant icons shrink slightly so the
/// focused one stands out.
double dockMagnificationScale(int distance) {
  if (distance <= 0) return 1.25;
  if (distance == 1) return 1.10;
  if (distance == 2) return 1.00;
  return 0.92;
}

class CategoryCleanRow extends StatefulWidget {
  final Category category;
  final List<App> applications;

  final bool isFirstSection;
  final double scrollAlignment;
  final VoidCallback? onAppFocused;

  CategoryCleanRow({
    Key? key,
    required this.category,
    required this.applications,
    this.isFirstSection = false,
    this.scrollAlignment = 0.5,
    this.onAppFocused,
  }) : super(key: key);

  @override
  State<CategoryCleanRow> createState() => _CategoryCleanRowState();
}

class _CategoryCleanRowState extends State<CategoryCleanRow> {
  int _focusedIndex = -1;

  double _scaleFor(int index) {
    if (_focusedIndex < 0) return 1.0;
    final distance = (index - _focusedIndex).abs();
    return dockMagnificationScale(distance);
  }

  @override
  Widget build(BuildContext context) {
    final showAppNames = context.select<SettingsService, bool>((s) => s.showAppNamesBelowIcons);
    final magnify = context.select<SettingsService, bool>((s) => s.dockMagnificationEnabled);
    final accentColor = context.select<SettingsService, Color>((s) => s.accentColor);

    Widget categoryContent;
    if (widget.applications.isEmpty) {
      categoryContent = categoryContainerEmptyState(context);
    } else {
      categoryContent = LayoutBuilder(
        builder: (context, constraints) {
          final slotWidth = constraints.maxWidth / Category.ColumnsCount;
          // The dock box keeps a fixed height: icons grow and shrink inside
          // their slots instead of stretching the container.
          final rowHeight = appCardRowExtentFromContentWidth(constraints.maxWidth) +
              (showAppNames ? kAppNameLabelHeight : 0);
          final availWidth = slotWidth - kAppCardHorizontalPadding * 2;
          final availHeight = rowHeight - kAppCardVerticalPadding * 2;
          // Icon boxes keep the card aspect ratio so images are never cropped.
          // With magnification off they simply fill the slot as before.
          final iconWidth = magnify ? availWidth * kDockIconWidthRatio : availWidth;
          final iconHeight = magnify ? iconWidth / kAppCardAspectRatio : availHeight;
          final highlightVisible =
              magnify && _focusedIndex >= 0 && _focusedIndex < widget.applications.length;
          final focusedScale = dockMagnificationScale(0);
          final highlightWidth = iconWidth * focusedScale + kDockHighlightPad * 2;
          final highlightHeight = iconHeight * focusedScale + kDockHighlightPad * 2;
          return SizedBox(
            height: rowHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Shared focus highlight: the accent edge slides between slots
                // instead of blinking per icon, staying behind the icons.
                if (highlightVisible)
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    left: _focusedIndex * slotWidth + (slotWidth - highlightWidth) / 2,
                    width: highlightWidth,
                    bottom: kAppCardVerticalPadding - kDockHighlightPad,
                    height: highlightHeight,
                    child: _DockHighlightBox(accentColor: accentColor),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(Category.ColumnsCount, (index) {
                    if (index < widget.applications.length) {
                      return Expanded(
                        child: Padding(
                          key: ValueKey(widget.applications[index].packageName),
                          padding: const EdgeInsets.symmetric(
                            horizontal: kAppCardHorizontalPadding,
                            vertical: kAppCardVerticalPadding,
                          ),
                          child: Center(
                            child: SizedBox(
                              width: iconWidth,
                              height: iconHeight,
                              child: AnimatedScale(
                                // bottomCenter keeps the icon's bottom edge
                                // fixed: it grows upward without triggering the
                                // focus reveal-scroll, and the dock box never
                                // changes size.
                                scale: magnify ? _scaleFor(index) : 1.0,
                                duration: const Duration(milliseconds: 180),
                                curve: Curves.easeOutCubic,
                                alignment: Alignment.bottomCenter,
                                child: AppCard(
                                  category: widget.category,
                                  application: widget.applications[index],
                                  autofocus: index == 0,
                                  handleUpNavigationToSettings: widget.isFirstSection,
                                  scrollAlignment: widget.scrollAlignment,
                                  enforceAspectRatio: false,
                                  disableInternalFocusScale: magnify,
                                  suppressInternalHighlight: magnify,
                                  onFocused: () {
                                    widget.onAppFocused?.call();
                                    if (_focusedIndex != index) {
                                      setState(() => _focusedIndex = index);
                                    }
                                  },
                                  onMove: (direction) => _onMove(context, direction, index),
                                  onMoveEnd: () => _onMoveEnd(context),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    } else {
                      return const Expanded(child: SizedBox.shrink());
                    }
                  }),
                ),
              ],
            ),
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [categoryContent],
    );
  }

  // TO DO : refractor duplicate _onMove code
  void _onMove(BuildContext context, AxisDirection direction, int index) {
    int newIndex = 0;

    if (direction == AxisDirection.right && index < widget.applications.length - 1) {
      newIndex = index + 1;
    } else if (direction == AxisDirection.left && index > 0) {
      newIndex = index - 1;
    } else {
      // Ignore UP/DOWN or at boundaries
      return;
    }

    final appsService = context.read<AppsService>();
    final movingApp = widget.applications[index];
    final realOldIndex = widget.category.applications.indexOf(movingApp);
    final realNewIndex = widget.category.applications.indexOf(widget.applications[newIndex]);
    if (realOldIndex >= 0 && realNewIndex >= 0) {
      appsService.reorderApplication(widget.category, realOldIndex, realNewIndex);
      // Set pending focus so the app at the new position will request focus
      appsService.setPendingReorderFocus(movingApp.packageName, widget.category.id);
    }
  }

  void _onMoveEnd(BuildContext context) {
    final appsService = context.read<AppsService>();
    appsService.saveApplicationOrderInCategory(widget.category);
  }
}

/// Accent edge + halo drawn behind the focused dock icon.
class _DockHighlightBox extends StatelessWidget {
  final Color accentColor;

  const _DockHighlightBox({required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accentColor, width: 2),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.35),
              blurRadius: 16,
              spreadRadius: 2,
            ),
          ],
        ),
      ),
    );
  }
}
