import 'dart:io';

enum ScreenshotScene {
  none,
  home,
  prayer,
  quranRead,
  quranListen,
  quranSync,
  libraryAdhkarRead,
  libraryAdhkarListen,
  libraryHisn,
  more,
}

class AppScreenshotScene {
  static const _compileTime = String.fromEnvironment('APP_SCREENSHOT_SCENE');
  static String get _raw =>
      _compileTime.isNotEmpty
          ? _compileTime
          : Platform.environment['APP_SCREENSHOT_SCENE'] ?? '';

  static ScreenshotScene get current {
    switch (_raw) {
      case 'home':
        return ScreenshotScene.home;
      case 'prayer':
        return ScreenshotScene.prayer;
      case 'quran-read':
        return ScreenshotScene.quranRead;
      case 'quran-listen':
        return ScreenshotScene.quranListen;
      case 'quran-sync':
        return ScreenshotScene.quranSync;
      case 'library-adhkar-read':
        return ScreenshotScene.libraryAdhkarRead;
      case 'library-adhkar-listen':
        return ScreenshotScene.libraryAdhkarListen;
      case 'library-hisn':
        return ScreenshotScene.libraryHisn;
      case 'more':
        return ScreenshotScene.more;
      default:
        return ScreenshotScene.none;
    }
  }

  static bool get enabled => current != ScreenshotScene.none;

  static int get initialTabIndex {
    switch (current) {
      case ScreenshotScene.prayer:
        return 1;
      case ScreenshotScene.quranRead:
      case ScreenshotScene.quranListen:
      case ScreenshotScene.quranSync:
        return 2;
      case ScreenshotScene.libraryAdhkarRead:
      case ScreenshotScene.libraryAdhkarListen:
      case ScreenshotScene.libraryHisn:
        return 3;
      case ScreenshotScene.more:
        return 4;
      case ScreenshotScene.none:
      case ScreenshotScene.home:
        return 0;
    }
  }

  static String? get quranMode {
    switch (current) {
      case ScreenshotScene.quranRead:
        return 'read';
      case ScreenshotScene.quranListen:
        return 'listen';
      case ScreenshotScene.quranSync:
        return 'read_listen';
      default:
        return null;
    }
  }

  static String? get librarySection {
    switch (current) {
      case ScreenshotScene.libraryAdhkarRead:
      case ScreenshotScene.libraryAdhkarListen:
        return 'adhkar';
      case ScreenshotScene.libraryHisn:
        return 'hisn';
      default:
        return null;
    }
  }

  static String? get adhkarMode {
    switch (current) {
      case ScreenshotScene.libraryAdhkarRead:
        return 'read';
      case ScreenshotScene.libraryAdhkarListen:
        return 'read_listen';
      default:
        return null;
    }
  }

  static String? get adhkarCategory {
    switch (current) {
      case ScreenshotScene.libraryAdhkarRead:
        return 'أذكار الصباح';
      case ScreenshotScene.libraryAdhkarListen:
        return 'أذكار المساء';
      default:
        return null;
    }
  }
}
