#!/usr/bin/env bash
# Genera las carpetas android/ e ios/ y añade los permisos de Bluetooth.
# Se ejecuta en Bitrise antes de compilar (también sirve en tu ordenador).
set -euo pipefail

flutter create . --org com.mx5diag --project-name mx5diag --platforms android,ios
rm -f test/widget_test.dart   # prueba de ejemplo de Flutter que no aplica a esta app

python3 - <<'PY'
import re, pathlib

# --- Android: permisos Bluetooth ---
m = pathlib.Path('android/app/src/main/AndroidManifest.xml')
s = m.read_text()
if 'BLUETOOTH_SCAN' not in s:
    perms = '''
    <uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation" />
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" android:maxSdkVersion="30" />
    <uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />'''
    s = re.sub(r'(<manifest[^>]*>)', r'\1' + perms, s, count=1)
    m.write_text(s)

# --- Android: nombre bajo el icono ---
NOMBRE = 'Diagnóstico de Averías Fácil'
m = pathlib.Path('android/app/src/main/AndroidManifest.xml')
s = m.read_text()
s = re.sub(r'android:label="[^"]*"', 'android:label="%s"' % NOMBRE, s, count=1)
m.write_text(s)

# --- Android: minSdk 21 como mínimo ---
for g in [pathlib.Path('android/app/build.gradle.kts'), pathlib.Path('android/app/build.gradle')]:
    if g.exists():
        t = g.read_text()
        t = re.sub(r'minSdk\s*=\s*(\d+)', lambda x: 'minSdk = %d' % max(21, int(x.group(1))), t)
        t = re.sub(r'minSdkVersion\s+(\d+)', lambda x: 'minSdkVersion %d' % max(21, int(x.group(1))), t)
        g.write_text(t)

# --- iPhone: texto del permiso Bluetooth ---
p = pathlib.Path('ios/Runner/Info.plist')
if p.exists():
    t = p.read_text()
    t = re.sub(r'(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)', lambda x: x.group(1) + NOMBRE + x.group(2), t)
    t = re.sub(r'(<key>CFBundleName</key>\s*<string>)[^<]*(</string>)', lambda x: x.group(1) + NOMBRE + x.group(2), t)
    p.write_text(t)
    if 'NSBluetoothAlwaysUsageDescription' not in t:
        t = t.replace('<dict>', '<dict>\n\t<key>NSBluetoothAlwaysUsageDescription</key>\n\t<string>Para conectar con el adaptador OBD-II del coche.</string>', 1)
        p.write_text(t)
print('Plataformas preparadas')
PY
