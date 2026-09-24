# Preparación para Google Play — VaniDaxi y VaniReparte

Estado: **preparadas para continuar con la publicación cuando la propietaria decida hacerlo. No se ha publicado ninguna app en Google Play.**

## Ya preparado

- VaniDaxi y VaniReparte usan Android SDK 36 como compile/target.
- Línea de versión prevista para Play: **4.0.0**.
- versionCode previsto: **40**.
- Existe workflow separado `.github/workflows/play-store-aab.yml` para generar AAB.
- La compilación automática de validación de los dos AAB 4.0.0 terminó correctamente.
- La compilación pública APK 3.1 continúa separada del flujo de Play.
- No existe ningún paso de publicación automática hacia Google Play.
- La función de descarga alternativa apunta a los APK 3.1 correctos.
- La configuración de firma de subida está preparada para usar secrets de GitHub sin guardar contraseñas en el código.

## Antes de publicar

1. Configurar la cuenta de Play Console de VaniDaxi.
2. Crear/configurar la aplicación de cada app en Play Console.
3. Configurar la clave de subida/Play App Signing y sus secrets de GitHub.
4. Completar política de privacidad y URL pública.
5. Completar Data Safety y la información de eliminación de datos.
6. Incorporar y verificar el flujo de solicitud de eliminación de cuenta dentro de las apps y mediante recurso web.
7. Completar ficha de Play Store, clasificación de contenido, contacto, icono, capturas y descripción.
8. Realizar las pruebas exigidas por Play Console según el tipo de cuenta.
9. Subir los AAB y pasar las revisiones de Google Play.
10. Publicar únicamente después de la aprobación de la propietaria.

## Importante

Los AAB 4.0.0 generados durante la preparación actual son de **validación** y no representan una publicación en Play Store. La firma final debe configurarse con la clave de subida correspondiente antes del envío.

La versión 4.0.0 es la versión objetivo para el lanzamiento completo; las versiones 3.1.x quedan como línea de distribución/pruebas previa.
