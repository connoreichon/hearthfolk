# HEARTHFOLK — ORDEN DE PRODUCCIÓN 002

## De prototipo a juego: «un año en la colina»

Hereda TODO el contrato técnico de la orden 001 (tick fijo, TaskBoard, IDs
estables, tipado como error, arte/audio procedural, gdformat+gdlint+tests
por fase, un commit y push por fase). Los valores de balance dejan de ser
sagrados: se ajustan al servicio de la diversión y se documentan.

## La fantasía ampliada

Un año completo. Llegas en primavera con 4 colonos y un carro. Cultivas,
talas, construyes. En otoño acumulas; los días se acortan. El invierno no
mata, pero muerde: el huerto duerme, la comida baja, la moral depende del
fuego y del techo. Si preparaste bien el asentamiento, en el deshielo
llegan caminantes por el camino del sur pidiendo quedarse. El pueblo crece.

## Fases

* **Q0 — Cara de juego.** Menú principal (título procedural + escena de
  fondo viva), opciones persistentes (volumen por bus, resolución/vsync,
  pantalla completa), pausa con menú, 3 slots de guardado + semilla
  elegible en partida nueva, icono de ventana/exe procedural.
  *Puerta: flujo menú→partida→guardar→menú→cargar sin errores.*
* **Q1 — Estaciones.** Año = 8 días (2 por estación). Primavera/verano/
  otoño/invierno: luz, paleta del terreno y copas viran por estación
  (shader + gradientes .tres), nieve visual en invierno, los árboles
  jóvenes crecen a adultos en primavera. HUD muestra estación.
  *Puerta: soak 1 año completo sin errores, transiciones visibles.*
* **Q2 — Huerto.** Zona de cultivo (herramienta nueva): parcelas 1×1,
  estados semilla→brote→madura (meshes procedurales), estados IA
  Plant/Tend/HarvestCrop, la comida pasa a ser producible y el hambre
  se acelera (comer 2×/día): la economía de comida importa. El huerto
  duerme en invierno.
  *Puerta: colonia autosuficiente en comida durante un año, test.*
* **Q3 — El pueblo crece.** Caminantes llegan por el camino del sur en
  primavera/verano si hay cama libre y excedente de comida (aparición,
  caminata, toast de bienvenida). Generador procedural de colonos
  (nombre, colores, altura, velocidad). Límite = camas. Cottage_B
  (variante 2 camas + huerto propio opcional) para variedad.
  *Puerta: de 4 a 10+ colonos en un año, sin romper rendimiento.*
* **Q4 — Moral.** Seguridad y vínculo se activan: comer caliente, dormir
  bajo techo, fogata encendida y compañía suben la moral; invierno a la
  intemperie la baja. La moral escala la velocidad de trabajo (0.6–1.15)
  y se ve en el panel del habitante (texto legible, no números crudos).
  *Puerta: tests de decaimiento/recuperación; visible en el panel.*
* **Q5 — Metas, eventos y música.** Panel de hitos (primer invierno
  superado, 5 colonos, 3 casas, granero lleno…) con recompensa de moral;
  eventos suaves con toast (helada temprana, bandada de pájaros, viajero
  que regala semillas). Música generativa por capas (gen_audio.py:
  drones + arpegios pentatónicos por estación) en el bus Music.
  *Puerta: un año jugado a ×2 produce ≥4 hitos y ≥2 eventos.*
* **Q6 — Equilibrio y entrega.** Pase de balance con soak de 40 min ×4
  (2 años), pulido de fricciones detectadas por el probador humano,
  export exe + zip listo para itch.io con página de texto redactada.
  *Puerta: checklist propio + soak verde + zip reproducible.*

## Reglas nuevas

1. La diversión manda: cualquier valor de la orden 001 puede cambiar,
   anotándolo en DECISIONS.md.
2. El probador humano (tú) es la puerta final de cada fase: entrego build
   y lista de «qué mirar»; su feedback puede reordenar fases.
3. Nada de assets de terceros salvo CC0 documentado; por defecto, todo
   sigue siendo procedural.
4. Sin muerte ni fracaso duro en esta build: la presión es económica y
   de moral.
