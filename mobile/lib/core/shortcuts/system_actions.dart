/// macOS system actions the Mac app can run (see desktop SystemActions.swift). Ids are protocol values.
abstract final class SystemActionIds {
  static const missionControl = 'mission_control';
  static const appExpose = 'app_expose';
  static const desktopLeft = 'desktop_left';
  static const desktopRight = 'desktop_right';
  static const showDesktop = 'show_desktop';

  static const all = [missionControl, appExpose, desktopLeft, desktopRight, showDesktop];

  static bool isValid(String id) => all.contains(id);

  static String label(String id) => switch (id) {
        missionControl => 'Mission Control',
        appExpose => 'App Expos\u00e9',
        desktopLeft => 'Previous desktop',
        desktopRight => 'Next desktop',
        showDesktop => 'Show desktop',
        _ => 'Unknown action',
      };

  /// Shown wherever the action can be chosen. Null = nothing to set up.
  static String? requirement(String id) => switch (id) {
        appExpose =>
          'Needs the \u201cApplication windows\u201d shortcut (Control-Down) enabled in System Settings > Keyboard > Keyboard Shortcuts > Mission Control.',
        desktopLeft || desktopRight =>
          'Needs the \u201cMove left/right a space\u201d shortcuts (Control-Left/Right) enabled in System Settings > Keyboard > Keyboard Shortcuts > Mission Control, and at least two desktops.',
        showDesktop =>
          'Needs the \u201cShow Desktop\u201d shortcut (F11 by default) enabled in System Settings > Keyboard > Keyboard Shortcuts > Mission Control.',
        _ => null,
      };
}
