# Dirección de arte — Build 003 «Las Culturas del Fuego»

## Filosofía

**Cuento ilustrado cálido.** Low-poly de libro de cuentos: saturación moderada,
nada de neón, contraste por **temperatura** — la naturaleza es fresca y serena,
lo humano es cálido. El acento sagrado de todo el juego es la **brasa** `#E8703A`:
hogueras, ventanas de noche, tótems, la UI del «espíritu del hogar». De noche,
una aldea debe leerse como una constelación de hogares encendidos en un mundo azul.

Regla de oro: ningún color se elige suelto — todo sale de estas rampas, y cada
material mezcla ±6 % de ruido de tono para que nada sea plano.

## Biomas (2–3 por mapa, fronteras por ruido suave, sin bordes duros)

### 1. Pradera del Hogar (base, la actual evolucionada)
- Hierba `#7FA05A` → claro `#94B86A` (parches por ruido)
- Tierra `#9B7048` · flores dispersas: blanco `#F2EFE1`, amapola `#C96F4A`
- Árboles frondosos actuales; conejos, ciervos de paso

### 2. Bosque Umbrío
- Hierba fría `#5E7F4D` · musgo sobre rocas `#6E8B5E`
- Pinos altos copa `#4F7248` tronco `#6B4A36`; setas `#C97B4A`
- Más ciervos, lobos en invierno; luz más tamizada (ambiente −10 %)

### 3. Ribera de Juncos
- Hierba jugosa `#82A968` · juncos `#8FA05F` · arcilla de orilla `#B08968`
- Agua `#5C91A6` con espuma de orilla `#DCE8E4`; peces, libélulas
- Sauces de copa clara `#9CB877`

### 4. Colinas de Piedra
- Hierba seca `#A5A46B` · roca `#8B8F8C` con líquenes `#9DA86E`
- Tierra pedregosa `#8A7355`; pinos ralos; cabras (futuro)

### 5. Claro Florido (micro-bioma raro, 0–1 por mapa)
- Alfombra multicolor (amapola/lavanda `#9B85B5`/blanco), abejas
- Lugar «sagrado natural»: las culturas lo veneran; no se tala solo

## Estaciones (multiplican encima, sistema ya existente)

Primavera brotes + flores · Verano saturado +5 % · Otoño ámbar `#C98F4A`
en copas y hojas cayendo · Invierno nieve `#EDF2F4` con sombras azuladas.

## Luz del día

- Amanecer `#FFD9A0` con niebla baja suave (el momento más bello del juego)
- Mediodía neutro cálido `#FFF4E0` (actual)
- Atardecer `#E8A45C` sombras largas
- Noche `#28364B` + acentos de fuego `#FFB35C`

## Culturas del Fuego (ropa, tótems, estandartes)

Cada cultura deriva su paleta del bioma de su hoguera madre + la brasa común:

- **Gente del Río**: azul apagado `#6E93A3` + lino crudo `#D9C59C`
- **Gente del Bosque**: verde musgo `#708455` + corteza `#795238`
- **Gente de la Piedra**: gris cálido `#8E8B84` + ocre `#C29B5A`

Acento sagrado compartido: brasa `#E8703A` (bordados, cuentas, puntas de tótem).
Las eras suben la riqueza del tejido, no el brillo: primitivo = tintes apagados
y pieles; madera = tintes vegetales; piedra = bordados y cenefas.

## Implementación (contrato procedural)

- `PaletteData` crece con rampas por bioma (no colores sueltos por el código).
- Shader de terreno: splat de bioma (ruido de dominio) × estación (ya existe)
  × senda emergente (rejilla de tráfico) — un solo shader, tres máscaras.
- Viento en vertex shader (árboles/hierba/juncos), espuma de orilla por
  distancia al agua, luciérnagas GPUParticles de noche, hojas en otoño.
- Nada de texturas descargadas: variación por ruido y vértice pintado.
