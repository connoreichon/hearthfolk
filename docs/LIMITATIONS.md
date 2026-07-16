# LIMITATIONS — limitaciones reales, sin maquillar

## Vigentes (Build 004, M0)

- **Runner: 4 instancias ObjectDB al salir** (2 `MeshInstance3D` sin ruta +
  2 `StandardMaterial3D`), estables entre corridas. Los `RID leaked` y los
  `resources still in use` están a CERO tras M0 (ResourceJanitor +
  AudioDirector.shutdown + drenaje del hilo de audio). No crece con el
  número de tests ni afecta al juego. Plan: rastrear instance_id en M5.
- **Vista de águila**: la falda de horizonte (disco r=1100) se percibe en
  ángulos rasantes desde el borde. Plan: fundido con niebla en M2.
- **Sombra falsa del águila con sol alto**: desde ≈460 m TODO el suelo cae
  fuera del alcance PSSM del sol (240 m) y la falda de horizonte, aplastada
  en el mapa de sombras, puede oscurecer el valle entero. En la SIEMBRA ya
  está resuelto (hotfix: sombra direccional apagada durante la fase); en la
  vista de águila del juego en marcha puede seguir pasando con el sol alto.
  Plan: M2/V5 (falda sin proyectar sombra o max_distance dinámico).
- **Agua poco legible desde el águila en mapas SEA**: el color/alpha del
  shader del agua se funde con la pradera visto desde ≈460 m (sin costas
  nítidas en la siembra). Plan: V2/V3 (contraste de agua a distancia).
- **Sombra blob**: quad plano que no sigue la pendiente. Plan: M2 (decal o
  raycast de 3 puntos, como pide la orden 004).
- **Música**: aún omitida; buses listos. Plan: M6 (generativa por capas).

## Históricas (Build 001, las que siguen aplicando)

- **Necesidades descanso/seguridad/vínculo**: seguridad y vínculo ya alimentan la moral (Q4); descanso sigue inerte en datos.
- **Necesidades descanso/seguridad/vínculo inertes**: existen en datos, guardado y panel de depuración, pero no alteran la IA (así lo pide §7.1 para esta build).
- **Ritmo de necesidades del contrato**: con los valores literales de §3 (hambre 1.4/min de simulación), el primer "comer por hambre" tarda varios días in-game. El descanso nocturno sí ocurre cada día. El cheat F3 «Vaciar necesidades» permite ver el ciclo comer/dormir al momento. Decisión documentada en DECISIONS.md.
- **Demoler**: cancela obras (con reembolso) y zonas, y desmarca árboles; la cabaña TERMINADA no se puede demoler en esta build.
- **Cursor de zona**: la herramienta de tala tiene cursor de hacha pixel-art propio; la de zona usa el cursor en cruz del sistema, no un icono propio.
- **Tooltip "Demasiado joven"**: es un Label3D flotante sobre el árbol, no un tooltip de UI anclado al cursor.
- **UI construida por código**: `hud.tscn`/`panel_selection.tscn`/`debug_overlay.tscn` del árbol §2.1 no existen como escenas; la UI vive en `scripts/ui/hud.gd` y `autoload/debug_console.gd` (misma razón que el input map: una sola fuente de verdad tipada). El resto de la estructura §2.1 se respeta.
- ~~Avisos "RID leaked at exit" en el runner~~ — RESUELTO en Build 004 M0.
- **El agua es un plano visual** (así lo pide §4): sin simulación ni interacción.
- **Guardado**: 1 slot, como pide §14. La cámara restaurada puede derivar milímetros por el suavizado del pivot (semánticamente irrelevante, verificado con tolerancia en el test).
