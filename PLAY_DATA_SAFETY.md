# Preparación de Data Safety — VaniDaxi y VaniReparte

Guía de trabajo para completar el formulario de Seguridad de los datos de Google Play. Debe revisarse contra la configuración final de producción.

## Categorías observadas

- Información personal: nombre, correo, teléfono y datos de perfil.
- Ubicación: ubicación precisa/aproximada utilizada para direcciones y reparto, cuando corresponde.
- Actividad financiera/comercial: pedidos, ventas, inventario, comisiones y registros relacionados.
- Información de la aplicación: tickets de soporte, estados de entrega y datos operativos.
- Autenticación: credenciales gestionadas por Supabase Auth; no guardar contraseñas en tablas propias.
- Pagos: procesamiento mediante proveedor externo; no almacenar secretos bancarios.

## Finalidades

Cuenta y autenticación, funcionamiento de la plataforma, pedidos y entrega, atención al cliente, seguridad, prevención de fraude y obligaciones operativas/contables.

## Eliminación

Existe un recurso web para solicitar eliminación de cuenta y una tabla interna de solicitudes para su gestión. Antes de publicar se debe confirmar la política exacta de retención/anonymización de registros transaccionales y completar el formulario de Play Console con esa política.
