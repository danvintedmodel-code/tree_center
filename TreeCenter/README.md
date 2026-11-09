# Tree Center — proyecto iOS

Primer corte en SwiftUI: el sistema de diseño en código y la pantalla de **Acceso**
funcionando de verdad (trazo invisible, comparación con tolerancia, Keychain y Face ID),
más el **Home** con sus widgets.

El código está montado como **paquete Swift**, no como proyecto de Xcode. Así se puede
compilar en un Mac de GitHub en cada push, sin que nadie tenga que estar delante del
Mac, y el proyecto de Xcode se crea una sola vez cuando haga falta ejecutarlo.

## Qué hay

```
Package.swift                  declara los dos módulos
.github/workflows/build.yml    compila y prueba en un Mac de GitHub

TreeCenterCore/                lógica pura, sin UIKit ni SwiftUI
└── StrokeMatcher.swift        normalizar y comparar trazos hechos a mano

TreeCenter/                    todo lo visual (módulo TreeCenterKit)
├── RootView.swift             o la puerta, o el centro del árbol
├── TreeCenterApp.swift        el @main — fuera del paquete, va en el target de la app
├── DesignSystem/
│   ├── Theme.swift            paleta en claro y oscuro, radios, espaciado
│   ├── Typography.swift       escala tipográfica, con fallback a San Francisco
│   └── Components.swift       tarjeta, botones, chip, barra, anillo, la marca
├── Lock/
│   ├── StrokeCanvas.swift     el lienzo que no dibuja nada
│   ├── LockStore.swift        Keychain
│   ├── BiometricAuth.swift    Face ID
│   ├── LockController.swift   estado de la puerta, intentos, espera
│   └── LockView.swift         la pantalla de Acceso
└── Home/
    └── HomeView.swift         widgets, barra de secciones y los cuatro botones

Tests/TreeCenterCoreTests/     pruebas del comparador de trazos
```

## Compilarlo sin estar delante del Mac

Sube el repo a GitHub y el workflow hace el resto en cada push.

En este PC no hay git instalado todavía, así que el repo aún no existe. Dos caminos:
instalar [Git para Windows](https://git-scm.com/download/win) y hacerlo aquí, o copiar
la carpeta al Mac y hacerlo allí. En cualquiera de los dos, desde la raíz del proyecto:

```bash
git init -b main
git add -A
git commit -m "Primer corte de Tree Center"
git remote add origin https://github.com/TU-USUARIO/tree-center.git
git push -u origin main
```

(Crea antes el repo vacío en GitHub, sin README ni .gitignore: este ya los trae.)

En la pestaña **Actions** sale el resultado. Compila `TreeCenterKit` para iOS y ejecuta
las pruebas de `TreeCenterCore` en un simulador. Si algo no compila, ahí está el archivo
y la línea, y se arregla sin tocar el Mac.

Si prefieres el repo privado, también funciona: los minutos de macOS gratis bastan de
sobra para un proyecto de este tamaño.

### Lo que prueban los tests

No prueban "que el código corre". Prueban la promesa de seguridad del Acceso:

- La misma forma, más grande y movida de sitio, **sí** abre.
- Un pulso tembloroso **sí** abre. Si no, no podrías entrar en tu propia app.
- La misma forma **girada 90°** no abre.
- La misma forma **dibujada al revés** no abre.
- La misma forma **partida en dos trazos** no abre.

Si alguna de las tres últimas se pone en verde al revés, el trazo ha dejado de ser una
contraseña y se ha convertido en un gesto cualquiera.

## Montarlo en Xcode (cuando llegues al Mac)

1. **Xcode → File → New → Project → iOS → App.**
   Product Name `TreeCenter`, Interface **SwiftUI**, Storage **None**, mínimo **iOS 17.0**.
   Guárdalo en una carpeta `App/` dentro de este mismo repo.
2. **File → Add Package Dependencies… → Add Local…** y elige la carpeta raíz del repo
   (la que tiene `Package.swift`). Añade **TreeCenterKit** al target de la app.
3. Borra el `ContentView.swift` y el `TreeCenterApp.swift` que ha generado Xcode, y
   arrastra al target el `TreeCenter/TreeCenterApp.swift` de este repo
   (**sin** marcar *Copy items if needed*: es el mismo archivo).
4. En el target → **Info**, añade la clave
   `Privacy - Face ID Usage Description` (`NSFaceIDUsageDescription`) con el texto:
   `Para entrar en Tree Center sin dibujar el trazo.`
   **Sin esa clave iOS mata la app** en el momento de pedir Face ID, sin error claro.
   Es el fallo más tonto y el que más tiempo se come.
5. En el mismo sitio, añade las otras dos claves de permiso. Son del mismo tipo que la
   de Face ID: sin ellas la app **se cierra** al abrir la cámara o la galería.

   | Clave | Qué poner |
   |---|---|
   | `Privacy - Camera Usage Description`<br>(`NSCameraUsageDescription`) | `Para hacerle una foto al plato, a la prenda o al recibo.` |
   | `Privacy - Photo Library Usage Description`<br>(`NSPhotoLibraryUsageDescription`) | `Para elegir fotos de recetas, prendas, caprichos y lugares.` |

   La de la galería es por si acaso: `PhotosPicker` corre fuera de la app y en teoría
   no la necesita, pero cuesta nada y evita un cierre si algún día se cambia por el
   selector antiguo.
6. Ejecuta. En el simulador, Face ID se simula desde
   *Features → Face ID → Enrolled* y luego *Matching Face*.
   **La cámara no existe en el simulador**: el botón no se dibuja allí (lo decide
   `CameraPicker.isAvailable`), así que para probarla hace falta el iPhone de verdad.
   La galería sí funciona, con las fotos de muestra que trae el simulador.

## Las fuentes

El sistema está escrito para **Instrument Sans**, pero funciona sin ella: si no está
instalada cae en San Francisco y no se rompe nada. Para ponerla:

1. Descarga la familia en <https://fonts.google.com/specimen/Instrument+Sans>.
2. Arrastra los `.ttf` al target de la app.
3. En **Info**, añade `Fonts provided by application` (`UIAppFonts`) con un elemento
   por archivo: `InstrumentSans-Regular.ttf`, `-Medium`, `-SemiBold`, `-Bold`.
4. Comprueba el nombre PostScript real de cada peso; si no coincide con el que espera
   `Typography.swift`, cámbialo allí (son cuatro constantes arriba del archivo).

## Cómo probar el trazo

La primera vez que abras la app no hay trazo guardado, así que te pide grabarlo:
lo dibujas, lo repites, y entra. A partir de ahí te lo pide al abrir.

- **No se dibuja nada.** Es lo buscado. Si parece que no responde, está respondiendo.
- Se da el trazo por terminado **0,9 s después de levantar el dedo**. Ese margen es el
  que te deja hacer una X en dos trazos. Está en `StrokeCanvas.idleDelay`.
- **Da igual el tamaño y dónde lo dibujes.** No da igual la rotación, ni el orden, ni
  en cuántos trazos lo partas.
- Tres fallos y 30 s de espera. En `LockController`.
- Para empezar de cero: `LockController.resetPattern()`, o borra la app.

## Copia, exportación e iCloud

Está en **Ajustes → Datos**. Tres cosas distintas que conviene no confundir:

**Guardar una copia.** Escribe un `.aar` con los cuatro trozos del almacén (la base, el
`-wal`, el `-shm` y la carpeta de las fotos) y lo pasa a la hoja de compartir. Es `.aar`
de Apple Archive y no un `.zip` por un motivo concreto: **Foundation sabe hacer un zip
pero no sabe deshacerlo**, no hay API pública para descomprimir en iOS, así que una copia
en zip no se podría restaurar sin una dependencia de terceros. En el Mac se abre con:

```
aa extract -i TreeCenter-copia-2026-11-09.aar -d carpeta
```

**Exportar los gastos.** Un CSV de los movimientos, con punto decimal y BOM de UTF-8
para que Excel en Windows no se coma los acentos. Esto es lo que se quiere de verdad
cuando se dice «exportar»: algo que se abre y se lee.

**Restaurar una copia.** Eliges el `.aar`, se descomprime en
`Application Support/restauracion-pendiente/`, se comprueba que dentro hay un
`TreeCenter.store` de verdad… y ahí se queda. **La restauración se aplica en el siguiente
arranque**, no al pedirla: `StoreFiles.applyPendingRestore()` corre en `RootView.init`
antes de que exista el `ModelContainer`. Sustituir los archivos de una base abierta no da
un error, da una base a medias, que es mucho peor.

**iCloud.** El interruptor guarda una preferencia y se aplica al reiniciar, porque el
contenedor se monta una sola vez en el arranque. Para que funcione hace falta, en Xcode:

1. Target → **Signing & Capabilities → + Capability → iCloud**, con **CloudKit** marcado
   y un contenedor (`iCloud.lo-que-sea.TreeCenter`).
2. **+ Capability → Background Modes → Remote notifications**, que es lo que despierta la
   app cuando otro dispositivo cambia algo.

Sin eso, encender el interruptor no rompe nada: el contenedor de iCloud no abre, la app
cae al almacén local y sale un aviso en el inicio diciéndolo.

El modelo ya cumple lo que CloudKit exige, y está comprobado campo a campo: ningún
atributo sin valor por defecto, ninguna relación a-uno obligatoria, ningún `.unique` y
todas las inversas declaradas a mano. No es suerte: es lo que quedó después de que el CI
se cayera seis veces seguidas por el modelo de datos.

## Lo que todavía no está

- Las animaciones de los ejercicios. Hace falta Lottie **y** los archivos dibujados;
  `ExerciseView` tiene el hueco reservado y dicho.
- El maniquí en 3D y la ropa como malla. Hasta que exista el modelado, el armario usa la
  figura de línea de `Mannequin.swift`, que marca en musgo lo que llevas puesto.
- Los iconos propios de línea. El inicio usa SF Symbols de momento; se cambian en
  `symbol(for:)` y `HomeTab.symbol` cuando el set esté dibujado.
- El mapa de los lugares de Viajes (MapKit).
- **Nada de esto se ha ejecutado nunca en un simulador.** Todo lo que hay compila en el
  CI; que compile y que funcione no son lo mismo.

## Una nota sobre seguridad

El trazo se guarda como plantilla en el Keychain con
`kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly`: no sale del iPhone, no entra en la
copia de iCloud y desaparece si quitas el código del teléfono.

No es un hash, y no puede serlo: un trazo nunca sale igual dos veces, así que hay que
poder medir el parecido contra algo. Lo que protege el secreto es el Keychain. Para una
app personal que no sale de tu móvil es la decisión correcta; si algún día la publicas,
esta parte hay que volver a mirarla.
