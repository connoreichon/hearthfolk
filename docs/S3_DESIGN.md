# S3 — Caminos emergentes: diseño sobre papel

> Regla de la build: el tuning emergente se simula en papel ANTES de
> codificar. El diseño original no producía senda visible; estos números sí.

## TrafficGrid

- Rejilla de tráfico que cubre el mapa (1024×1024 m). Textura **512×512**
  (2 m por texel): una senda pisada mide 2–4 m, se lee bien y la subida a
  GPU es barata (256 KB, L8).
- **Pisada**: el gancho de pasos del colono ya salta cada 1.1 m recorridos
  (`citizen.gd`). Cada pisada estampa un pincel pequeño: centro `+0.03`,
  4 vecinos `+0.015`. Acumula hasta 1.0.
- **Decaimiento**: cada día de sim la rejilla se multiplica por `0.96`. Una
  ruta usada a diario se mantiene saturada; una abandonada se difumina en
  ~2-3 semanas. (El diseño pedía «estacional»; por día es más suave y no da
  saltos bruscos al cambiar de estación.)
- **Subida a GPU**: la imagen se sube a la `ImageTexture` como mucho cada
  0.5 s reales (no en cada pisada), y solo si hubo cambios.

### Simulación en papel (¿emerge la senda?)

Un colono que hace una ruta de ~20 m ida y vuelta 10 veces al día recorre
~400 m, es decir ~360 pisadas diarias concentradas en ese corredor. La ruta
de 20 m son ~10 texels; cada texel de la línea recibe ~18 pisadas/día ×
0.03 = **0.54/día**. En ~2-3 días de uso la senda satura a 1.0 y se ve
clara. Con decaimiento 0.96/día, una senda diaria se mantiene (0.54 de
aporte >> 0.04 de pérdida); una abandonada cae a 0.5 en ~17 días. Emergencia
gradual y satisfactoria, borrado lento. GATE (senda visible tras 1 año):
holgado.

## Shader

El terreno ya reserva `COLOR.r` para el camino, pero pintar vértices en vivo
es caro. En su lugar el shader muestrea una `traffic_tex` global por posición
de mundo: `path = texture(traffic_tex, world.xz / mapa + 0.5).r`, y
`dirt_amount = clamp(smoothstep(0.12, 0.55, path) + pendiente, 0, 1)`. Así la
senda es tierra pisada, sin rehornear mallas. Sin bonus de velocidad en v1.

## Ambiente vivo (S3, ligero)

- Peces del río (partículas GPU bajo el agua), pájaros posados en rocas
  (no en árboles talables), luciérnagas de noche, hojas de otoño cayendo,
  niebla del amanecer (ya hay niebla base; se intensifica al alba).
- Presupuesto: todo GPU o muy barato; nada que pese en el tick de sim.

## Puerta S3

Soak 1 año: las rutas diarias se VEN como sendas de tierra (captura antes
vs después). Suite + humo release.
