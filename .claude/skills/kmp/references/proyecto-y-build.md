# Proyecto, versiones y build

Marcas: **[verificado]** probado en esta máquina el 2026-11-23, **[repo]** visto en un repo del profesor, **[propuesta]** sin probar. Decisión de pila: ADR 001 en `docs/decisiones/` del repo KMP.

## Módulo

Un solo módulo, como `kmp.cliente.producto` **[repo]**:

```kotlin
// settings.gradle.kts
include(":composeApp")
```

- `composeApp/build.gradle.kts` aplica `kotlinMultiplatform`, `com.android.application`, `composeMultiplatform`, `composeCompiler` y `kotlinxSerialization`. Declara `androidTarget { … }`, el bloque `android { namespace, compileSdk, defaultConfig, buildTypes }` y `sourceSets` con `commonMain`, `androidMain` y `commonTest`.
- El build raíz declara los plugins con `apply false`; todas las versiones viven en `gradle/libs.versions.toml`.
- **Por qué un módulo con AGP 8:** con AGP 9, `kotlinMultiplatform` y `com.android.application` en el mismo módulo fallan con «not compatible … since AGP 9.0» **[verificado]**. Alternativa descartada: `androidApp` + `shared` con AGP 9 (`kmp.navegacion.bottombar`).

## Targets

Solo `androidTarget()` **[propuesta]**. De la plantilla de `cliente.producto` se quita todo lo demás: `iosArm64`, `iosSimulatorArm64`, `jvm`, `js`, `wasmJs`, la carpeta `iosApp`, `webpack.config.d` y los `Platform.*.kt`. Ese repo conserva `actual` sin `expect` y su target **`jvm` no compila** **[verificado]**; al quitar un target se borran también sus archivos.

## Versiones (ADR 001)

Pila **verificada** (compila, arma el APK y se ejecutó en el emulador):

- Kotlin 2.2.20
- Compose Multiplatform 1.9.0
- AGP 8.13.0 y Gradle 8.14.3 (wrapper)
- `compileSdk` 36, `minSdk` 24, `targetSdk` 36
- Ktor 3.3.0 (`core`, `cio`, `content-negotiation`, `serialization-kotlinx-json`)
- Voyager 1.1.0-beta03 (`navigator`, `tab-navigator`)
- lifecycle (`ViewModel`) 2.9.4, coroutines 1.10.2
- JDK 21

Se suman en KMP-02 **[verificado]**: `ktor-client-content-negotiation`, `ktor-serialization-kotlinx-json`, `kotlinx-coroutines-core`, el plugin `kotlinx.serialization` y, para pruebas, `ktor-client-mock` y `kotlinx-coroutines-test`. **No** se usan el plugin `Auth` ni `Logging` de Ktor (ADR 005 del repo KMP).

Reglas:
- Kotlin, Compose Multiplatform, Ktor y Voyager se cambian **juntos** y se recompila; no mezclar versiones sueltas.
- Los otros repos del profesor usan combinaciones distintas (`bottombar`: Kotlin 2.4.20, Compose 1.12.1, AGP 9.4.1): no copiar versiones de uno a otro.
- AGP 8 termina en 8.13.2; no se puede pasar a AGP 9 sin separar los módulos.
- El wrapper de Gradle lo manda el proyecto (`gradle-wrapper.properties`); no subirlo a mano.

## Entorno de esta máquina

```bash
export JAVA_HOME=$HOME/.gradle/jdks/azul_systems__inc_-21-amd64-linux.2   # JDK 21; el del sistema es el 25
export ANDROID_HOME=$HOME/Android/Sdk
./gradlew :composeApp:assembleDebug        # APK debug [verificado en cliente.producto]
./gradlew :composeApp:installDebug         # instala en el teléfono virtual conectado
./gradlew :composeApp:testDebugUnitTest    # tests de commonTest [verificado en KMP-01]
```

- El wrapper de Gradle se genera con el Gradle 8.14.3 en caché: `~/.gradle/wrapper/dists/gradle-8.14.3-bin/*/gradle-8.14.3/bin/gradle wrapper --gradle-version 8.14.3 --distribution-type bin` **[verificado]**.

- Gradle 8.14.3 **no arranca con JDK 25** (`What went wrong: 25.0.2`) **[verificado]**. El JDK propio de Android Studio 2026.1.4 aquí es el 25: al abrir el proyecto, Studio ofrece usar el 21 (aceptar) o se elige en *Settings > Build Tools > Gradle > Gradle JDK*.
- AGP instala solo la plataforma `android-36` y las `build-tools 35.0.0` la primera vez que compila **[verificado]**.
- Un cambio en un archivo de Gradle exige «Sync Project» en Android Studio; hasta entonces el IDE deshabilita Run.
- El primer build baja Gradle y las dependencias (varios minutos); los siguientes tardan segundos.
- Caché que crece: `~/.gradle` (≈5 GB), `~/.konan` (compiladores de iOS; con solo Android no hace falta).

## Emulador

- El teléfono virtual es `Pixel_10_Pro` (Android 37). Si no está encendido, `installDebug` falla con «No connected devices!». Arrancarlo desde Android Studio o con `~/Android/Sdk/emulator/emulator -avd Pixel_10_Pro` **[verificado]**.
- Un teléfono recién arrancado puede quedar **dormido** (`dumpsys power` dice `mWakefulness=Asleep`) y se ve negro aunque la app corra. Se despierta con el botón de encendido o con `adb shell input keyevent KEYCODE_WAKEUP` **[verificado]**.
- `adb` está en `~/Android/Sdk/platform-tools/adb` (no está en el PATH). `adb exec-out screencap -p > captura.png` saca una captura; `adb shell uiautomator dump` lista los elementos en pantalla.

## URLs y red en Android

- `10.0.2.2` es la PC vista desde el emulador; un teléfono real usa la IP de la PC en la LAN **[repo: cliente.producto]**. Puertos por defecto: catálogo `8081`, turnos `8082` (D26).
- **[verificado en KMP-01]** `catalogUrl` y `turnosUrl` en `gradle.properties` (por defecto `10.0.2.2:8081` y `:8082`), `buildConfigField` en `defaultConfig` con `buildFeatures { buildConfig = true }`, y una clase `AppConfig` que `MainActivity` arma y entrega a `App`; el código común no lee `BuildConfig`. Se pisan con `-PcatalogUrl=...` y `-PturnosUrl=...`. `AppConfig` viaja por un `CompositionLocal` (`LocalAppConfig`) y no como campo de las pantallas, porque Voyager serializa las pantallas en Android.
- `INTERNET` va en el manifest principal **[repo]**. El texto plano (`http://`) lo bloquea Android 9 y posteriores por defecto: permitirlo solo en debug con `<application android:usesCleartextTraffic="true" />` en **`composeApp/src/debug/AndroidManifest.xml`** **[verificado en KMP-01]**: el de debug **no** se fusiona si está en `src/androidDebug/` aunque Gradle lo liste (lo muestra `build/outputs/logs/manifest-merger-debug-report.txt`), y el de release queda sin ese atributo. En producción, HTTPS.
- Sin secretos en el repo ni en el APK. El JWT del usuario vive en el almacenamiento seguro; el técnico de la cátedra no existe en la app.
