# Plano de diagnóstico (Flutter · Android + iPhone)

App de diagnóstico visual del coche: plano 3D tipo blueprint con zonas en rojo, amarillo y verde,
lectura OBD-II con adaptador ELM327 Bluetooth LE y base de datos **100 % offline**.

## Qué incluye

| Pantalla | Qué hace |
|---|---|
| **Plano** | Coche wireframe en 3D (arrastrar para girar), vistas 3D / lateral / planta / frente / trasera con cotas, mecánica en gris, cableado, puntos de estado y etiquetas. Ficha por zona, revisión manual y acceso a recambios. |
| **Códigos** | Buscador offline de códigos de avería en español, con gravedad, zona del coche y qué hacer. Muestra primero los detectados en tu coche. |
| **Mantenimiento** | Plan de mantenimiento con avisos de vencimiento y botón "Hecho". Datos técnicos del MX-5 NC con enlace a su fuente y marca de "sin verificar". |
| **Recambios** | Batería original y equivalentes (Yuasa YBX5053, Bosch S4 021, Exide EA456, Varta B32), lámparas, neumáticos, aceite, refrigerante… con enlace de búsqueda en Oscaro. |
| **OBD-II** | Busca y conecta el ELM327 BLE, lee códigos (modo 03 y pendientes 07), los borra (modo 04, con confirmación), mide batería (ATRV) y muestra datos en vivo (rpm, temperaturas, correcciones de mezcla, MAF, tensión). Todo se guarda en el historial y el plano se actualiza solo. |

## Datos offline (`assets/data/`)

| Archivo | Contenido |
|---|---|
| `dtc_genericos.json` | 140 códigos genéricos OBD-II (P0xxx y U0xxx) en español, con sistema, zona, gravedad y consejo. |
| `zonas.json` | 12 zonas del coche con su posición 3D. |
| `especificaciones_nc.json` | Batería, aceite, refrigerante, neumáticos y lámparas del MX-5 NC, cada dato con su fuente. |
| `mantenimiento_nc.json` | Intervalos de mantenimiento (los no verificados van marcados). |
| `recambios_nc.json` | Recambios y equivalencias con enlace de búsqueda. |

Para ampliar la base, añade entradas al JSON y sube `AppDb.datosVersion` en `lib/data/db.dart`: la app recarga los datos de referencia sin tocar tu historial.

Los códigos que no estén en la base (p. ej. los propios de Mazda, P1xxx) se muestran igualmente como "específico del fabricante".

## Cómo compilarla

Necesitas Flutter 3.22 o superior.

```bash
cd mx5diag
flutter create . --org com.tuempresa --platforms android,ios   # genera las carpetas android/ e ios/
flutter pub get
flutter test                                                    # pruebas del lector OBD y de la batería
flutter run
```

### Permisos Android (`android/app/src/main/AndroidManifest.xml`, dentro de `<manifest>`)

```xml
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />
```

Y en `android/app/build.gradle`: `minSdkVersion 21`.

### Permisos iPhone (`ios/Runner/Info.plist`)

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Para conectar con el adaptador OBD-II del coche.</string>
```

Para compilar en iPhone necesitas un Mac con Xcode (o un servicio en la nube como Codemagic).

## Adaptador OBD

- **iPhone y Android:** adaptador **Bluetooth LE** (p. ej. Vgate iCar Pro BLE, OBDLink CX).
- Los ELM327 baratos de Bluetooth clásico solo funcionan en Android y necesitarían otro módulo de conexión (no incluido).
- El ELM327 con comandos estándar lee la centralita de motor/emisiones. ABS, airbag, luces o carrocería usan protocolos de Mazda: por eso esas zonas se alimentan con revisiones manuales.

## Estructura

```
lib/
  main.dart                    navegación inferior (Plano, Códigos, Mantenimiento, Recambios, OBD)
  data/models.dart             Zona, Dtc, Especificacion, TareaMantenimiento, Recambio
  data/db.dart                 SQLite: carga de datos de referencia + historial del usuario
  viewer/car_model.dart        modelo wireframe 3D (diseño propio de roadster genérico)
  viewer/plano_view.dart       proyección, pintado blueprint, puntos, etiquetas y miniaturas
  obd/obd_parser.dart          interpretación de respuestas ELM327 (DTC, PIDs, tensión)
  obd/elm327.dart              conexión BLE y comandos
  services/bateria.dart        valoración de batería (reposo, arranque, carga, edad)
  screens/                     pantallas
test/obd_parser_test.dart      pruebas
```

## Pendiente / siguientes pasos

- Medir la caída de tensión durante el arranque (requiere muestreo rápido de ATRV al arrancar).
- Gráfica de tendencia de batería y correcciones de mezcla con el historial guardado.
- Ampliar la base de códigos (lista genérica completa) y añadir códigos Mazda conocidos.
- Actualización de la base por internet (opcional), manteniendo el funcionamiento offline.
