# EVA_CE

Fanmade de combate de mechas estilo Evangelion. 3D, tercera persona, Godot 4.7.

## Abrir el proyecto

1. Instala [Godot 4.7](https://godotengine.org/download) (versión estándar, no .NET).
2. En el Project Manager: **Importar** y elige `project.godot` de esta carpeta.
3. F5 para jugar.

## Controles

| Acción | Teclado / ratón | Mando |
|---|---|---|
| Mover | WASD | Stick izquierdo |
| Cámara | Ratón | Stick derecho |
| Correr | Shift | L3 |
| Saltar | Espacio | A / Cruz |
| Soltar ratón | Esc | |

Corre (Shift) contra un edificio para derribarlo (a partir de 25 m/s).

## Estructura

```
scenes/
  main.tscn          ciudad de prueba, cámara y HUD
  eva.tscn           Eva placeholder (cápsula, ~40 m)
scripts/
  eva/
    eva_input.gd     snapshot de input de un frame
    local_input.gd   lee teclado/mando y genera EvaInput
    eva_controller.gd  movimiento pesado (sólo lee EvaInput)
    eva_camera.gd    cámara sobre el hombro con temblor por pisadas
  world/
    building.gd      edificio que se rompe en bloques con física
    city_generator.gd  cuadrícula de edificios alrededor de una plaza
  ui/debug_hud.gd    velocidad, FPS y controles
tests/
  smoke_test.gd      prueba sin ventana: el Eva corre y derriba un edificio
```

La lógica del Eva nunca lee `Input` directamente: recibe un `EvaInput` por frame. Así el mismo controlador sirve para jugador local, IA y, más adelante, PvP en red.

Los parámetros de sensación (velocidades, giro, salto, temblor de cámara) están exportados: se ajustan desde el inspector seleccionando `Eva` o `CameraRig`.

## Prueba rápida

```
godot --headless --path . --script res://tests/smoke_test.gd
```

## Capas de física

1 mundo · 2 eva · 3 escombros · 4 edificios
