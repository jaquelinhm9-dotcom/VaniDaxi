# VaniDaxi

Repositorio del ecosistema VaniDaxi.

## Aplicaciones públicas

- **VaniDaxi 4.1.0** — compradores y vendedores.
- **VaniReparte 4.1.0** — repartidores.

La línea pública actual es **4.1.0**. El workflow `.github/workflows/build-apks.yml` construye las dos APK con Android SDK 36 y publica los instaladores en GitHub Releases y GitHub Pages.

## Preparación para Google Play

El workflow `.github/workflows/play-store-aab.yml` genera los AAB 4.1.0 y queda conectado al éxito del build público. No existe publicación automática a Google Play.

## Herramienta empresarial

El **Panel Principal VaniDaxi** es una herramienta web privada para la empresa. No se publica como APK pública.

Las claves privadas de release no se almacenan en el repositorio.
