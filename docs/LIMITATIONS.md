# LIMITATIONS — limitaciones reales de la Build 001, sin maquillar

- **Música omitida** (previsto en la orden §13): los buses y el sistema de audio están listos; no hay pista musical. Plan: pieza generativa por capas en `gen_audio.py` en una build futura.
- **Necesidades descanso/seguridad/vínculo inertes**: existen en datos, guardado y panel de depuración, pero no alteran la IA (así lo pide §7.1 para esta build).
- **Ritmo de necesidades del contrato**: con los valores literales de §3 (hambre 1.4/min de simulación), el primer "comer por hambre" tarda varios días in-game. El descanso nocturno sí ocurre cada día. El cheat F3 «Vaciar necesidades» permite ver el ciclo comer/dormir al momento. Decisión documentada en DECISIONS.md.
- **Demoler**: cancela obras (con reembolso) y zonas, y desmarca árboles; la cabaña TERMINADA no se puede demoler en esta build.
- **Cursor de zona**: la herramienta de tala tiene cursor de hacha pixel-art propio; la de zona usa el cursor en cruz del sistema, no un icono propio.
- **Tooltip "Demasiado joven"**: es un Label3D flotante sobre el árbol, no un tooltip de UI anclado al cursor.
- **UI construida por código**: `hud.tscn`/`panel_selection.tscn`/`debug_overlay.tscn` del árbol §2.1 no existen como escenas; la UI vive en `scripts/ui/hud.gd` y `autoload/debug_console.gd` (misma razón que el input map: una sola fuente de verdad tipada). El resto de la estructura §2.1 se respeta.
- **Avisos "RID leaked at exit" en el runner de tests**: solo al salir del proceso de tests (quit con escena viva y materiales estáticos cacheados). No ocurren en ejecución normal del juego ni en el export. Pendiente de limpieza fina.
- **Sombra blob**: quad estático bajo los pies; no se deforma con la pendiente del terreno.
- **El agua es un plano visual** (así lo pide §4): sin simulación ni interacción.
- **Guardado**: 1 slot, como pide §14. La cámara restaurada puede derivar milímetros por el suavizado del pivot (semánticamente irrelevante, verificado con tolerancia en el test).
