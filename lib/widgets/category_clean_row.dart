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

/// Extra vertical room added to the dock row so the magnified card is not
/// clipped by the dock's rounded container.
const double kDockMagnificationSlack = 34.0;

/// macOS-style magnification curve: the focused card grows the most and the
/// effect tapers off with the distance from it.
double dockMagnificationScale(int distance) {
  if (distance <= 0) return 1.35;
  if (distance == 1) return 1.18;
  if (distance == 2) return 1.06;
  return 1.0;
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
          final rowHeight = appCardRowExtentFromContentWidth(constraints.maxWidth) +
              (showAppNames ? kAppNameLabelHeight : 0) +
              (magnify ? kDockMagnificationSlack : 0);
          final highlightVisible =
              magnify && _focusedIndex >= 0 && _focusedIndex < widget.applications.length;
          return SizedBox(
            height: rowHeight,
            child: Stack(
              children: [
                // Shared focus highlight: the accent edge slides between slots
                // instead of blinking per icon, staying behind the icons.
                if (highlightVisible)
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    left: _focusedIndex * slotWidth + kAppCardHorizontalPadding,
                    width: slotWidth - kAppCardHorizontalPadding * 2,
                    top: kAppCardVerticalPadding,
                    height: rowHeight - kAppCardVerticalPadding * 2,
                    child: _DockHighlightBox(accentColor: accentColor),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: List.generate(Category.ColumnsCount, (index) {
                    if (index < widget.applications.length) {
                      return Expanded(
                        child: Padding(
                          key: ValueKey(widget.applications[index].packageName),
                          padding: const EdgeInsets.symmetric(
                            horizontal: kAppCardHorizontalPadding,
                            vertical: kAppCardVerticalPadding,
                          ),
                          child: AnimatedScale(
                            scale: magnify ? _scaleFor(index) : 1.0,
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOutCubic,
                            alignment: Alignment.center,
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
