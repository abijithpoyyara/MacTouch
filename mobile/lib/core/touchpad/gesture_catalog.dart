import 'package:flutter/material.dart';

import 'gesture_config.dart';

/// Which controls a gesture's card shows, and what it is called. The *values* live in TouchpadSettings
/// (pointer speed, tap and scroll switches that already existed) or GestureConfig (everything new).
class GestureInfo {
  const GestureInfo({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    this.sensitivityLabel,
    this.hasDistance = false,
    this.hasHold = false,
    this.hasAction = false,
  });

  final GestureId id;
  final String title;
  final String description;
  final IconData icon;
  /// When set, the card has a sensitivity slider with this label.
  final String? sensitivityLabel;
  final bool hasDistance;
  final bool hasHold;
  final bool hasAction;
}

class GestureSection {
  const GestureSection(this.title, this.gestures);
  final String title;
  final List<GestureInfo> gestures;
}

abstract final class GestureCatalog {
  static const sections = <GestureSection>[
    GestureSection('One finger', [
      GestureInfo(id: GestureId.oneFingerMove, title: 'Move cursor', description: 'Slide one finger.',
          icon: Icons.mouse_rounded, sensitivityLabel: 'Pointer speed'),
      GestureInfo(id: GestureId.oneFingerTap, title: 'Tap to click', description: 'Tap once for a left click.',
          icon: Icons.touch_app_rounded, sensitivityLabel: 'Tap tolerance'),
      GestureInfo(id: GestureId.doubleTap, title: 'Double tap', description: 'Tap twice quickly for a double-click. Also enables tap-then-drag.',
          icon: Icons.ads_click_rounded, sensitivityLabel: 'Double-tap timing'),
      GestureInfo(id: GestureId.longPress, title: 'Long press to drag', description: 'Rest one finger, then move to drag.',
          icon: Icons.pan_tool_alt_rounded, hasHold: true),
    ]),
    GestureSection('Two fingers', [
      GestureInfo(id: GestureId.twoFingerTap, title: 'Two-finger tap', description: 'Tap with two fingers for a right click.',
          icon: Icons.mouse_rounded, sensitivityLabel: 'Tap tolerance'),
      GestureInfo(id: GestureId.scrollVertical, title: 'Vertical scroll', description: 'Slide two fingers up or down.',
          icon: Icons.swap_vert_rounded, sensitivityLabel: 'Scroll speed'),
      GestureInfo(id: GestureId.scrollHorizontal, title: 'Horizontal scroll', description: 'Slide two fingers left or right.',
          icon: Icons.swap_horiz_rounded, sensitivityLabel: 'Horizontal speed'),
    ]),
    GestureSection('Three fingers', [
      GestureInfo(id: GestureId.threeUp, title: 'Swipe up', description: 'Three fingers up.', icon: Icons.keyboard_double_arrow_up_rounded, hasDistance: true, hasAction: true),
      GestureInfo(id: GestureId.threeDown, title: 'Swipe down', description: 'Three fingers down.', icon: Icons.keyboard_double_arrow_down_rounded, hasDistance: true, hasAction: true),
      GestureInfo(id: GestureId.threeLeft, title: 'Swipe left', description: 'Three fingers left.', icon: Icons.keyboard_double_arrow_left_rounded, hasDistance: true, hasAction: true),
      GestureInfo(id: GestureId.threeRight, title: 'Swipe right', description: 'Three fingers right.', icon: Icons.keyboard_double_arrow_right_rounded, hasDistance: true, hasAction: true),
    ]),
    GestureSection('Four fingers', [
      GestureInfo(id: GestureId.fourUp, title: 'Swipe up', description: 'Four fingers up.', icon: Icons.keyboard_double_arrow_up_rounded, hasDistance: true, hasAction: true),
      GestureInfo(id: GestureId.fourDown, title: 'Swipe down', description: 'Four fingers down.', icon: Icons.keyboard_double_arrow_down_rounded, hasDistance: true, hasAction: true),
      GestureInfo(id: GestureId.fourLeft, title: 'Swipe left', description: 'Four fingers left.', icon: Icons.keyboard_double_arrow_left_rounded, hasDistance: true, hasAction: true),
      GestureInfo(id: GestureId.fourRight, title: 'Swipe right', description: 'Four fingers right.', icon: Icons.keyboard_double_arrow_right_rounded, hasDistance: true, hasAction: true),
    ]),
  ];
}
