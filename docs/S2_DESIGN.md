# S2 — Rasgos y oficios: diseño sobre papel

> Regla de la build (riesgo #4): el tuning emergente se simula en papel ANTES de
> codificar. Este documento es esa simulación. Los números de aquí son los que
> van al código; si el soak los desmiente, se corrigen AQUÍ primero.

## 1. Atributos (5, rango 1–10, media 5.5)

| Atributo | Clave | Manda en |
|---|---|---|
| Fuerza | `str` | talar, acarrear |
| Destreza | `dex` | construir |
| Percepción | `per` | recolectar, forrajear (futuro: cazar S6) |
| Mano verde | `gre` | huerto (plantar/cosechar) |
| Diligencia | `dil` | multiplicador general de constancia |

Tirada: `3 + randi_range(0,3) + randi_range(0,4)` → 3–10, campana suave
centrada en ~6.5. RNG **sembrado por ciudadano** (`hash(semilla_mundo, id)`)
para que los tests sean deterministas.

## 2. Catálogo de rasgos

Estructura de cada entrada (constante en `TraitCatalog`):

```
id: StringName            # clave de guardado
nombre: String            # evocador, en español
detalle: String           # una frase con voz de crónica
tipo: VIRTUD | DEFECTO
hereditary: bool          # desde el día uno (genética en Build 004)
activo: bool              # false = definido pero sin mecánica todavía
attr_mod: {clave: ±n}     # modificador plano de atributos al nacer
work_mod: {familia: ×f}   # multiplicador de velocidad por familia de trabajo
```

Familias de trabajo v1: `chop`, `build`, `farm`, `haul`, `forage`, `walk`.

### Activos v1 (12 con mecánica real)

| id | Nombre | Tipo | Her. | Efecto |
|---|---|---|---|---|
| `brazos_de_roble` | Brazos de roble | V | sí | str +2, chop ×1.25 |
| `manos_de_jardinero` | Manos de jardinero | V | sí | gre +2, farm ×1.25 |
| `ojo_avizor` | Ojo avizor | V | sí | per +2, forage ×1.3 |
| `pulso_de_cantero` | Pulso de cantero | V | sí | dex +2, build ×1.25 |
| `zancada_larga` | Zancada larga | V | sí | walk ×1.12 |
| `espalda_de_mula` | Espalda de mula | V | no | haul ×1.3 |
| `madrugador` | Madrugador | V | no | dil +1 (empieza a trabajar antes: futuro) |
| `manos_de_madera` | Manos de madera | D | sí | dex −2, build ×0.8 (pero chop ×1.1: fuerza bruta) |
| `flojera_de_brazos` | Flojera de brazos | D | sí | str −2, chop ×0.8 |
| `pies_planos` | Pies planos | D | no | walk ×0.88 |
| `distraido` | Distraído | D | no | per −2, forage ×0.75 |
| `mal_de_espalda` | Mal de espalda | D | no | haul ×0.75 |

### Definidos, sin mecánica todavía (se activan en builds siguientes)

| id | Nombre | Tipo | Her. | Para |
|---|---|---|---|---|
| `buena_mano_al_timon` | Buena mano al timón | V | sí | marinero (puertos, 004+) |
| `voz_de_pastor` | Voz de pastor | V | sí | pastor (fauna domesticable 004) |
| `paciencia_de_pescador` | Paciencia de pescador | V | sí | pescador (004) |
| `levadura_en_las_venas` | Levadura en las venas | V | sí | panadero (eras) |
| `miedo_al_agua` | Miedo al agua | D | sí | marinero/pescador (004) |
| `alma_creativa` | Alma creativa | V | sí | decoración emergente (S8) |
| `punteria_de_lince` | Puntería de lince | V | sí | cazador (S6) |
| `torpe_con_el_arma` | Torpe con el arma | D | sí | cazador/guerra (S6/005) |
| `sangre_friolera` | Sangre friolera | D | sí | biomas fríos (004) |
| `piel_del_desierto` | Piel del desierto | V | sí | bioma desértico (004) |
| `memoria_de_anciano` | Memoria de anciano | V | no | crónica/peticiones (S4) |
| `duerme_poco` | Duerme poco | V | no | ritmo nocturno (S4) |

### Reparto al nacer

- 1 virtud garantizada (uniforme entre virtudes ACTIVAS).
- 70 % de un defecto (activo). 20 % de segunda virtud. Sin repetidos.
- Los rasgos inactivos NO se reparten todavía (nacerían muertos); el catálogo
  existe para que el guardado y la genética ya los conozcan.

## 3. Oficios v1 y aptitud

Oficios: `lenador`, `agricultor`, `constructor`, `recolector` (base).

Aptitud (0.3–2.0 aprox), con atributos normalizados a `attr/6.5`:

```
apt(lenador)     = 0.7·(str/6.5) + 0.3·(dil/6.5), × work_mod[chop]
apt(agricultor)  = 0.8·(gre/6.5) + 0.2·(dil/6.5), × work_mod[farm]
apt(constructor) = 0.7·(dex/6.5) + 0.3·(dil/6.5), × work_mod[build]
apt(recolector)  = 0.6·(per/6.5) + 0.4·(dil/6.5), × work_mod[forage]
```

## 4. La demanda manda: necesidad por aldea (0–1)

Con `stock` del inventario global y objetivos del campamento:

```
need(lenador)     = clamp(1 − wood/WOOD_TARGET, 0, 1) · 0.9 + 0.1
need(agricultor)  = clamp(1 − food/FOOD_TARGET, 0, 1) · 0.9 + 0.1   (0.05 si no hay huerto)
need(constructor) = 1.0 si hay obra pendiente de la banda; 0.05 si no
need(recolector)  = 0.35 fijo (línea base: siempre viene bien)
```

`FOOD_TARGET = 10 + 4·población`. El `+0.1` evita necesidad cero absoluta
(nadie debe quedar sin vocación posible).

## 5. Elección de oficio (utilidad con histéresis)

```
score(oficio) = need(oficio en MI aldea) × apt(oficio)
score(mi oficio actual) ×= 1.35        # histéresis anti-flapping
elegir el máximo
```

Reevaluación: **al cambiar la estación** (+ al nacer, + al cargar partida sin
oficio). Nada de reevaluar cada tick: el flapping muere por diseño.

### Simulación en papel (aldea de 4, semilla cualquiera)

Colonos: A(str 8, brazos_de_roble→chop×1.25), B(gre 8, manos_de_jardinero),
C(dex 7), D(per 6, todo mediano).

**Primavera año 1** (wood 0/24 → need_leñ 1.0; sin huerto → need_agr 0.05;
sin obra → need_con 0.05; need_rec 0.35):
- A: leñ 1.0×1.54=1.54 · agr 0.05 · con 0.05 · rec ~0.3 → **leñador**
- B: leñ 1.0×0.9=0.9 · rec 0.35×0.9=0.32 → **leñador** (¡la demanda manda!)
- C: leñ 1.0×0.95 → **leñador** · D: leñ 1.0×0.9 → **leñador**
- 4 leñadores con madera a cero: correcto según la orden del dueño
  («si la aldea necesita mucha leña, habrá VARIOS leñadores»).

**Verano** (wood 20/24 → need_leñ 0.25; comida floja 8/26 → el planificador
ya habrá pedido huerto → need_agr 0.72; obra del huerto → need_con 1.0):
- A: leñ 0.25×1.54=0.39·(×1.35 hist)=0.52 · con 1.0×0.7=0.7 → **constructor**
- B: agr 0.72×1.11=0.8 · leñ 0.25×0.9(hist ×1.35)=0.3 → **agricultor**
- C: con 1.0×0.86=0.86 → **constructor** · D: rec 0.35×0.9=0.32 vs leñ
  0.25×0.9×1.35=0.3 → **recolector**
- Cambios: 4/4 colonos, 1 cambio cada uno. Dentro de puerta (≤1/estación).

**Otoño** (huerto hecho → need_con 0.05; comida 18/26 → agr 0.38; wood 24 →
leñ 0.1): A vuelve a leñador o pasa a recolector (0.35×~0.9=0.31 vs leñ
0.1×1.54=0.15 → **recolector**)… B sigue **agricultor** (0.38×1.11×1.35=0.57).
C → recolector. D sigue recolector (hist). Cambios: A 1, B 0, C 1, D 0. OK.

Conclusión de papel: con histéresis ×1.35 y reevaluación estacional, el
flapping queda estructuralmente ≤1 cambio/colono/estación. GATE alcanzable.

## 6. El oficio pesa en el tablón (retrocompatible)

`best_task_for` ya puntúa por prioridad+distancia+banda. S2 añade PESO POR
OFICIO sin romper nada: cada tarea pertenece a una familia; si la familia es
la del oficio del ciudadano, su punto de corte de distancia y su puntuación
mejoran.

Implementación final (aditiva, no multiplicativa — así NUNCA salta un
bloque de prioridad): `score = prioridad×1000 + distancia − 400·(kind ∈
oficio)`. El bonus de 400 decide dentro de una misma prioridad y aplasta
cualquier desempate por distancia, pero una urgencia (prioridad menor)
sigue ganando siempre.

Nadie queda bloqueado: si no hay tareas de su oficio, toma cualquiera
(la utilidad manda, el oficio solo inclina).

## 7. Velocidad de trabajo por habilidad

`Citizen.work_speed(familia) = clamp(0.6, apt_norm × work_mod, 1.6)`
aplicado a: tiempo de tala, plantar/cosechar, velocidad de obra, y
`walk` a la velocidad de movimiento (±12 %). Visible sin ser ridículo.

## 8. Infraestructura autoconstruida (huerto y almacén)

Planificador por campamento (cadencia 1 comprobación/2 h de sim):

- **Huerto**: si `food < FOOD_TARGET·0.6` SOSTENIDO (≥6 pasadas de 15 s: un
  bajón puntual no rotura tierra) y no hay huerto de la banda → buscar
  parcela 6×6 llana y seca en el territorio (anillos desde la hoguera,
  misma validación que el jugador) → crear zona de huerto real.
- **Almacén**: si `población ≥ 6` y solo hay 1 punto de almacenaje de la banda
  → obra de cobertizo (receta pequeña: 8 madera) junto al montón original.
- Ambos respetan la maquinaria existente (zonas/ConstructionSite/TaskBoard);
  cero código de obra nuevo.
- Toast con voz de crónica: «Los del Hogar de X roturan su primer huerto».

## 9. Guardado

- Por ciudadano: `attrs: {str,dex,per,gre,dil}`, `traits: [ids]`,
  `profession: String`. FORMAT_VERSION sigue en 2 (aditivo con defaults):
  un save v2 sin estas claves tira atributos/rasgos al cargar (mismo RNG
  sembrado por id → estable entre cargas).

## 10. UI y presencia visible

- **Selección de colono**: oficio junto al estado + rasgos con nombre
  evocador y detalle en una línea. Nada de números pelados.
- **Panel Aldeas**: línea de resumen por aldea «2 leñadores · 1 agricultor
  · 1 recolector».
- **Consola de depuración (F3)**: recuento de oficios en vivo.
- **Herramienta de oficio A LA ESPALDA** (`ProfessionProp`): el leñador
  lleva hacha, el agricultor azada, el constructor maza, el recolector
  cesto con bayas — el oficio se LEE en la figura sin abrir menú («verlo
  todo»). Cambia sola cuando el colono cambia de oficio.

## 12. Herencia (lista desde el día uno)

Aunque las familias llegan en Build 004, `TraitCatalog.inherit()` y
`inherit_attributes()` ya existen y están testeados: SOLO pasan los rasgos
`hereditary` (50 % cada uno), con mutación configurable y virtud
garantizada; los atributos son la media de los padres ±1. Cuando se
enchufe la reproducción, la genética no necesita migrar nada.

## 11. Puerta S2

Soak 1 año, 3 bandas: (a) flapping medio ≤1 cambio/colono/estación,
(b) madera fluye sin tocar T (stock nunca clavado en 0 una estación entera
con árboles en territorio), (c) si la comida aprieta, nace un huerto solo,
(d) 0 atascos. + suite + humo release.
