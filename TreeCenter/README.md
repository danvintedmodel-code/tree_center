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
5. Ejecuta. En el simulador, Face ID se simula desde
   *Features → Face ID → Enrolled* y luego *Matching Face*.

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

## Lo que todavía no está

- Las otras 19 pantallas del diseño.
- El modelo de datos (SwiftData) y el guardado real: el Home enseña cifras de ejemplo.
- Los iconos propios de línea. El Home usa SF Symbols de momento; se cambian en
  `HomeSection.symbol` y `HomeTab.symbol` cuando el set esté dibujado.
- El libro 3D, el maniquí y las animaciones de ejercicios.

## Una nota sobre seguridad

El trazo se guarda como plantilla en el Keychain con
`kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly`: no sale del iPhone, no entra en la
copia de iCloud y desaparece si quitas el código del teléfono.

No es un hash, y no puede serlo: un trazo nunca sale igual dos veces, así que hay que
poder medir el parecido contra algo. Lo que protege el secreto es el Keychain. Para una
app personal que no sale de tu móvil es la decisión correcta; si algún día la publicas,
esta parte hay que volver a mirarla.
