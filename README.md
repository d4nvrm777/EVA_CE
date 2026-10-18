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
| Corte (combo de 3) | Clic izquierdo | X / Cuadrado |
| Estocada | Clic derecho | Y / Triángulo |
| AT Field (mantener) | Q | LB / L1 |
| Fijar objetivo | Tab / rueda | R3 |
| Conectar / soltar cable | E | B / Círculo |
| Soltar ratón | Esc | |

Corre (Shift) contra un edificio para derribarlo (a partir de 25 m/s).

## Combate (paso 2)

- **Cuchillo**: tres cortes encadenables y una estocada lenta que también sirve de remate del combo. Al atacar, el Eva gira solo hacia el enemigo más cercano.
- **AT Field**: mantenido bloquea golpes frontales sin daño. Si lo levantas justo antes del impacto (0,18 s) haces **parry**: el Ángel queda aturdido y pierde mucho AT Field.
- **Ángel de prueba**: en el centro de la plaza. Su AT Field absorbe todo el daño; rómpelo a cortes, con parry o **neutralizándolo** (tu AT Field levantado cerca le drena el suyo). Con el campo roto el núcleo brilla y recibe daño doble durante 5 s. Cada 3 s carga un golpe: se pone rojo antes de golpear.

## Recursos (paso 3)

- **Cable umbilical**: empiezas conectado al enchufe de la plaza (torres con luz verde por la ciudad). Conectado tienes energía infinita pero no puedes alejarte más de 300 m. Con E sueltas el cable; cerca de un enchufe (45 m), E te conecta en 0,8 s, quieto y vulnerable.
- **Batería interna**: desconectado tienes 75 s (contador abajo a la izquierda). Correr gasta el doble, el AT Field x1,6 y atacar x1,3. A 0 el Eva se apaga 6 s y vuelve con 20 s de emergencia (el berserk lo sustituirá).
- **Cortar el cable**: si el Ángel te golpea sin que bloquees, te corta el cable.
- **Sincronización**: empieza en 50 % y tiende a 40 %. Sube al golpear (+2,5), bloquear (+1) y hacer parry (+12); baja al recibir daño. Multiplica el daño (x0,6 a x1,6) y la velocidad (x0,85 a x1,15).

## Estructura

```
scenes/
  main.tscn          ciudad de prueba, cámara y HUD
  eva.tscn           Eva placeholder (cápsula, ~40 m)
scripts/
  angel_dummy.tscn   Ángel de prueba
  eva/
    eva_input.gd     snapshot de input de un frame
    local_input.gd   lee teclado/mando y genera EvaInput
    eva_controller.gd  movimiento pesado (sólo lee EvaInput)
    eva_camera.gd    cámara sobre el hombro, temblor y fijar objetivo
    eva_combat.gd    ataques, AT Field/parry, vida y aturdimiento
    eva_visuals.gd   cuchillo, AT Field y caída (sólo presentación)
    eva_power.gd     cable umbilical, batería interna y apagado
    umbilical_cable.gd  dibujo del cable
  combat/
    attack_data.gd   definición de un ataque (datos en data/attacks/*.tres)
    hit_info.gd      golpe recibido y su resultado
    hit_spark.gd     chispa de impacto
  enemies/
    angel_dummy.gd   Ángel de prueba: AT Field, núcleo, ataque telegrafiado
  world/
    building.gd      edificio que se rompe en bloques con física
    city_generator.gd  cuadrícula de edificios alrededor de una plaza, y enchufes
    power_socket.gd  enchufe para el cable umbilical
  ui/debug_hud.gd    velocidad, FPS y controles
  ui/combat_hud.gd   vida del Eva, vida y AT Field del Ángel
data/attacks/        valores de cada ataque (editables en el inspector)
tests/
  smoke_test.gd      prueba sin ventana: el Eva corre y derriba un edificio
  combat_test.gd     prueba sin ventana: combo, parry, bloqueo y neutralización
  power_test.gd      prueba sin ventana: cable, batería, apagado y sincronización
```

La lógica del Eva nunca lee `Input` directamente: recibe un `EvaInput` por frame. Así el mismo controlador sirve para jugador local, IA y, más adelante, PvP en red.

Los parámetros de sensación (velocidades, giro, salto, temblor de cámara) están exportados: se ajustan desde el inspector seleccionando `Eva` o `CameraRig`.

## Prueba rápida

```
godot --headless --path . --script res://tests/smoke_test.gd
godot --headless --path . --script res://tests/combat_test.gd
godot --headless --path . --script res://tests/power_test.gd
```

## Capas de física

1 mundo · 2 eva · 3 escombros · 4 edificios · 5 enemigos
