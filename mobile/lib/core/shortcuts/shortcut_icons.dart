import 'package:flutter/material.dart';

/// Icons a shortcut can use. The key is what gets stored, so never rename an existing key.
abstract final class ShortcutIcons {
  static const Map<String, IconData> all = {
    'bolt': Icons.bolt_rounded,
    'lock': Icons.lock_rounded,
    'screenshot': Icons.crop_free_rounded,
    'crop': Icons.crop_rounded,
    'desktop': Icons.desktop_windows_rounded,
    'apps': Icons.apps_rounded,
    'minimize': Icons.minimize_rounded,
    'close': Icons.close_rounded,
    'window': Icons.web_asset_rounded,
    'mission': Icons.dashboard_rounded,
    'arrow_left': Icons.arrow_back_rounded,
    'arrow_right': Icons.arrow_forward_rounded,
    'tab': Icons.tab_rounded,
    'undo': Icons.undo_rounded,
    'search': Icons.search_rounded,
    'refresh': Icons.refresh_rounded,
    'terminal': Icons.terminal_rounded,
    'code': Icons.code_rounded,
    'build': Icons.build_rounded,
    'play': Icons.play_arrow_rounded,
    'keyboard': Icons.keyboard_rounded,
    'star': Icons.star_rounded,
    'folder': Icons.folder_rounded,
    'mail': Icons.mail_rounded,
    'music': Icons.music_note_rounded,
    'volume': Icons.volume_up_rounded,
    'copy': Icons.content_copy_rounded,
    'paste': Icons.content_paste_rounded,
    'swap': Icons.swap_horiz_rounded,
    'camera': Icons.photo_camera_rounded,
  };

  static IconData of(String key) => all[key] ?? Icons.bolt_rounded;
}
