PlotMetric Calculator-Only Icon Pack
=================================
Source: approved PlotMetric calculator-only icon (no plans/maps).

RECOMMENDED LOCATION IN YOUR FLUTTER PROJECT
<flutter-project>/assets/app_icon/

Copy assets/app_icon/plotmetric_icon.png from this pack to that path.

EASIEST FLUTTER INSTALLATION
1. In pubspec.yaml dev_dependencies, add flutter_launcher_icons (use version compatible with your Flutter SDK).
2. Configure:
flutter_launcher_icons:
  android: true
  ios: true
  image_path: assets/app_icon/plotmetric_icon.png
  remove_alpha_ios: true
  adaptive_icon_background: "#EAF7FF"
  adaptive_icon_foreground: assets/app_icon/plotmetric_adaptive_foreground.png
3. Copy android/adaptive/ic_launcher_foreground.png to assets/app_icon/plotmetric_adaptive_foreground.png.
4. Run flutter pub get then dart run flutter_launcher_icons.
5. Check Android launcher and iOS simulator/device.

MANUAL OPTIONS
android/mipmap-* : legacy Android launcher assets.
android/adaptive/ : Android adaptive foreground/background and optional themed monochrome.
ios/AppIcon.appiconset/ : iOS icon catalogue; replace Runner/Assets.xcassets/AppIcon.appiconset only after backing up.
web/ : web icons and favicon; update web/manifest.json paths as needed.
play_store/ : 512x512 PNG for Google Play store listing.

NOTE: Adaptive foreground intentionally has generous padding so text remains visible inside masks.
Icons with text may be difficult to read at tiny sizes.
