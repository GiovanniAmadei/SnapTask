# SnapTask: Gestor de Tareas con Apple Watch

SnapTask es una aplicación completa de gestión de tareas con funcionalidades de temporizador Pomodoro, seguimiento de hábitos y estadísticas. Ahora incluye una app para Apple Watch que permite sincronizar y gestionar tareas desde la muñeca.

## Características

### Aplicación iOS
- Gestión de tareas con planificación diaria
- Temporizador Pomodoro integrado
- Sistema de seguimiento de hábitos recurrentes
- Estadísticas detalladas de productividad
- Categorización de tareas con iconos y colores
- Modo oscuro/claro
- Citas motivacionales

### Aplicación watchOS
- Visualización de tareas programadas para hoy
- Marcado de tareas como completadas
- Temporizador Pomodoro para tareas
- Vista rápida de estadísticas
- Sincronización bidireccional con la app de iOS

## Estructura del Proyecto

### Aplicación iOS (SnapTask/)
- **App/**: Punto de entrada de la aplicación
- **Models/**: Modelos de datos (TodoTask, TaskManager, etc.)
- **Views/**: Interfaces de usuario
- **ViewModels/**: Lógica de las vistas
- **Core/**: Componentes centrales como el temporizador
- **Extensions/**: Extensiones de tipos existentes
- **Services/**: Servicios como sincronización y notificaciones
- **Resources/**: Recursos localizados
- **Assets.xcassets/**: Recursos gráficos

### Aplicación watchOS (SnapTask Watch App/)
- **Models/**: Extensiones de modelos compartidos
- **Views/**: Interfaces de usuario específicas para watchOS
- **ViewModels/**: Lógica específica para watchOS
- **Assets.xcassets/**: Recursos gráficos para watch

## Sincronización iOS-watchOS

Las aplicaciones se sincronizan mediante el framework WatchConnectivity. Cuando ocurren cambios en iOS, estos se propagan automáticamente al Apple Watch. De igual manera, las acciones realizadas en el Apple Watch (como completar una tarea) se reflejan en la app de iOS.

## Configuración del Proyecto

Para configurar el proyecto correctamente, consulta el archivo `WATCH_INTEGRATION_GUIDE.md` que contiene instrucciones detalladas sobre cómo integrar la app de watchOS al proyecto Xcode.

## Requisitos

- iOS 16.0 o posterior
- watchOS 9.0 o posterior
- Xcode 15.0 o posterior

## Instalación

1. Clona este repositorio
2. Abre `SnapTask.xcodeproj` en Xcode
3. Configura los signing certificates para los targets de iOS y watchOS
4. Ejecuta la aplicación en un dispositivo o simulador

## Contacto

Para preguntas o sugerencias, por favor abrir un issue en este repositorio. 