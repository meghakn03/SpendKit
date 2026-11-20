import plistlib
from pathlib import Path

activity = Path("android/app/src/main/kotlin/dev/spendkit/spendkit/MainActivity.kt")
activity.write_text(activity.read_text().replace("FlutterActivity", "FlutterFragmentActivity"))

manifest = Path("android/app/src/main/AndroidManifest.xml")
source = manifest.read_text().replace('android:label="spendkit"', 'android:label="SpendKit"')
if "android.permission.USE_BIOMETRIC" not in source:
    source = source.replace(
        "<application",
        '<uses-permission android:name="android.permission.USE_BIOMETRIC" />\n    <application',
        1,
    )
manifest.write_text(source)

for styles in Path("android/app/src/main/res").glob("values*/styles.xml"):
    source = styles.read_text()
    for parent in ("Theme.Light.NoTitleBar", "Theme.Black.NoTitleBar"):
        source = source.replace(f"@android:style/{parent}", "Theme.AppCompat.DayNight.NoActionBar")
    styles.write_text(source)

info = Path("ios/Runner/Info.plist")
with info.open("rb") as stream:
    settings = plistlib.load(stream)
settings["CFBundleDisplayName"] = "SpendKit"
settings["NSFaceIDUsageDescription"] = "Use Face ID to unlock SpendKit and verify card changes."
with info.open("wb") as stream:
    plistlib.dump(settings, stream, sort_keys=False)
