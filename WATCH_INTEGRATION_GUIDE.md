# Integración de la App de Apple Watch

Este directorio contiene el código fuente para la app de Apple Watch de SnapTask. Sigue los siguientes pasos para integrarla en el proyecto principal de Xcode.

## Configuración del proyecto

1. Abre el proyecto `SnapTask.xcodeproj` en Xcode.

2. Agrega un nuevo target de tipo watchOS:
   - En Xcode, selecciona `File > New > Target...`
   - Elige `watchOS > App`
   - Nombra el target como "SnapTask Watch App"
   - Asegúrate de que la casilla "Include Notification Scene" esté desmarcada (a menos que quieras integrar notificaciones personalizadas)
   - En "Team", selecciona tu equipo de desarrollo
   - En "Bundle Identifier", usa `com.yourdomain.SnapTask.watchkitapp` (ajusta el dominio según tu configuración)
   - Haz clic en "Finish" para crear el target

3. Configura las dependencias:
   - Selecciona el proyecto SnapTask en el navegador de archivos
   - Ve a la pestaña de "Build Phases" para el target de watch app
   - En "Dependencies", agrega el target de iOS (`SnapTask`)

## Importando los archivos

1. En el Finder, copia todos los archivos de la carpeta `SnapTask Watch App` al grupo "SnapTask Watch App" recién creado en tu proyecto de Xcode.

2. Asegúrate de que todos los archivos estén asignados al target de watchOS correcto.

3. Agrega los modelos compartidos:
   - Selecciona los archivos de modelo en el grupo "SnapTask/Models" (Recurrence.swift, TodoTask.swift, etc.)
   - En el inspector de archivos, asegúrate de que tanto el target de iOS como el de watchOS estén seleccionados
   - Haz lo mismo para los managers y servicios compartidos (TaskManager.swift, QuoteManager.swift, etc.)

## Configuración de la conectividad entre dispositivos

Si necesitas sincronizar datos entre la app de iOS y la de watchOS, asegúrate de configurar el marco de trabajo WatchConnectivity:

1. Agrega un archivo WatchConnectivityManager.swift tanto al target de iOS como al de watchOS.
2. Implementa la sincronización de tareas y configuraciones entre dispositivos.

## Personalización adicional

- Reemplaza los marcadores de posición del ícono en `Assets.xcassets/AppIcon.appiconset/` con tus propios íconos
- Ajusta las configuraciones en Info.plist según sea necesario

## Pruebas

1. Selecciona el target "SnapTask Watch App" y elige un simulador de watchOS
2. Ejecuta la app para probar la funcionalidad
3. Para probar la conectividad, ejecuta ambas apps (iOS y watchOS) simultáneamente

## Notas importantes

- Los archivos modelo (TodoTask, Recurrence, etc.) deben ser idénticos entre ambos targets
- Cualquier cambio en las estructuras de datos debe hacerse en ambos lugares
- Si utilizas CoreData, deberás configurar un contenedor de datos compartido

## Resolución de problemas

Si encuentras problemas con la compilación o ejecución:

1. Verifica que todos los archivos estén asignados al target correcto
2. Asegúrate de que las dependencias estén correctamente configuradas
3. Limpia la carpeta de construcción (Cmd+Shift+K) y reconstruye el proyecto
4. Verifica que los modelos compartidos sean accesibles desde ambos targets 