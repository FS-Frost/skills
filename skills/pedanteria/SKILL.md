---
name: pedanteria
description: Interrogatorio para cerrar huecos de entendimiento antes de implementar. Úsalo cuando no tengas confianza en un plan, cuando un término sea ambiguo, cuando el alcance no esté cerrado, o cuando el usuario pida pedantería. Triggers: "no estoy seguro", plan con huecos, término ambiguo, alcance difuso, "hazlo" sin criterio de aceptación, síntoma sin causa confirmada, "/pedanteria", "sé pedante".
argument-hint: "[tema] [plan] [pedido a interrogar]"
---

# Skill: Pedantería

Objetivo único: que el usuario y tú describan **el mismo problema** antes de escribir una línea de código. No es una entrevista de requisitos. Es cerrar huecos que, si quedan abiertos, hacen que se construya lo incorrecto.

Idioma: español.

## Dos modos

Este skill corre en uno de dos modos. Determínalo antes de nada.

**Modo forzado** — el usuario lo invocó explícito (`/pedanteria`, "usa pedantería", "sé pedante") o pasó argumentos.

- TEMA: los argumentos recibidos. Si vienen vacíos, aplica al último plan o pedido de esta conversación.
- **Corre aunque tu confianza sea alta.** Acá tu trabajo es *buscar* el hueco, no declarar que no hay ninguno. Asume que hay al menos uno y encuéntralo.
- **La precondición read-only no aplica.** Invocarlo es la declaración de que hay una implementación pendiente que interrogar.
- **"No encontré huecos" solo es válido** si viene con el bloque Acuerdo, los siete puntos llenos y verificables contra el código. Sin eso, no terminaste.
- **No implementes nada.** El modo forzado termina en el Acuerdo, y su última línea es la del handoff.

**Modo automático** — te activaste por umbral, sin que el usuario lo pidiera. Rigen la precondición y el umbral de las dos secciones siguientes.

## Precondición (solo modo automático)

Aplica **solo a pedidos que van a mutar algo**: código, esquema, configuración, estado externo.

Si el pedido es read-only —analizar, explicar, comparar, revisar, buscar, opinar— **no actives**. Responde. Bloquear escritura en algo que no escribe es teatro.

## Cuándo activarte (solo modo automático)

Cumplida la precondición, **actívate siempre**. Todo pedido que muta algo pasa por pedantería antes de escribir.

Única excepción: pedidos triviales y precisos (typo en un archivo nombrado, rename mecánico, formateo). Pedantería sobre lo obvio es ruido. Este skill es la única autoridad del umbral de activación.

Al activarte, estas señales indican **qué huecos interrogar primero** (no son compuerta — la activación ya ocurrió):

- No puedes nombrar el archivo/función/tabla exacta que hay que cambiar → Términos y Alcance.
- El usuario usa un término que el código no usa, o que en este repo significa otra cosa → Términos.
- Hay ≥2 lecturas razonables del pedido que llevan a implementaciones distintas → Problema y Alcance.
- No sabes decir cómo se verifica que quedó bien → Criterio de aceptación.
- El pedido toca zonas peligrosas del repo sin detalle suficiente (`migrations/`, `alembic/`, `auth/`, `.env*`, `docker-compose*`, credenciales o conexiones de MySQL/Mongo, código vendorizado) → Riesgo.
- El plan tiene un paso cuyo "cómo" es una caja negra → Supuestos.
- El usuario describe un síntoma y la causa no está confirmada → Problema.

Si ninguna señal aplica y los siete huecos ya están cerrados por la propia conversación, emite el bloque Acuerdo directo, sin tandas — ser pedante no obliga a preguntar, obliga a cerrar los huecos por escrito.

## Regla de bloqueo

**Mientras haya un hueco abierto: cero escritura.** No `Edit`, no `Write`, no comandos que muten estado.

Permitido: leer, buscar, `glob`, comandos read-only, y actualizar el `CLAUDE.md` del repo con lo decidido en el Acuerdo (ver Cierre) — única escritura permitida.

Dile al usuario en una línea qué está bloqueado y qué falta exactamente para desbloquearlo. No lo dejes implícito.

Orden obligatorio: exploración read-only del repo → preguntas en tandas de ≤4, cuantas tandas hagan falta → bloque Acuerdo. Cero ediciones antes del Acuerdo.

## Primero el código, después el usuario

Toda pregunta que el repo puede responder, **se responde leyendo el repo** — no se pregunta.

Antes de preguntar nada: lee el repo con las herramientas de búsqueda y lectura disponibles (`Read`, `glob`, grep) — no te salteás la lectura.

Al usuario solo le preguntas lo que el código no sabe: intención, prioridad, trade-off, alcance, qué es "correcto" para el negocio.

## Protocolo de preguntas

- Tandas de **máximo 4** preguntas. Prefija cada tanda con `Tanda N — huecos abiertos: X/7` para que la convergencia sea visible y sobreviva a la compactación.
- **Forma de la pregunta según el hueco**:
  - Espacio de respuestas cerrado (elegir alcance, elegir estrategia, sí/no con consecuencias) → `AskUserQuestion`. Cada opción declara su consecuencia; la recomendada va primera y marcada `(Recomendado)`.
  - Espacio abierto (mapear términos, escenario concreto, XY) → pregunta en texto plano en el chat. No inventes 4 opciones falsas para forzar el widget.
- Si una respuesta cambia **qué** vas a preguntar después, esa pregunta va sola.
- **Sin tope de tandas**: corre cuantas sean necesarias hasta cerrar los siete huecos. La condición de avance es progreso, no cantidad. Progreso = cerrar un hueco **o** redefinirlo/invalidarlo (ej: XY revela que el pedido era otra cosa — cero huecos cerrados, pero avance real). Estancamiento = **dos tandas seguidas** sin ninguno de los dos → cierras con bloque Acuerdo — completo, o marcado incompleto (ver Cierre) — en vez de seguir preguntando.
- Si el usuario responde "no sé" (o equivalente), eso cuenta como hueco abierto: anótalo y no lo repreguntes. Se resuelve leyendo más código, proponiendo un escenario concreto, o queda vacío en el Acuerdo.
- Prohibido preguntar algo que el usuario ya respondió en esta conversación.
- Cada pregunta debe cambiar la implementación. Si la respuesta no cambia nada, no la preguntes.

## Los siete huecos

Checklist interno. Lista al usuario **solo los que faltan**, no los siete siempre.

1. **Problema** — qué duele hoy, con un caso concreto.
2. **Términos** — cada sustantivo del pedido mapeado a una tabla/clase/endpoint real.
3. **Alcance** — qué se toca.
4. **Fuera de alcance** — qué explícitamente NO.
5. **Criterio de aceptación** — cómo se verifica: comando, endpoint o pantalla.
6. **Supuestos** — lo que estás asumiendo y el usuario debe confirmar o corregir.
7. **Riesgo** — qué se rompe si un supuesto es falso.

## Técnicas

- **Escenario concreto**: propón un caso con datos ficticios (nunca PII real) y pide que el usuario diga qué debe pasar. Los abstractos esconden desacuerdos; los concretos los revelan.
- **Contradicción con el código**: si el usuario afirma algo que el repo desmiente, muestra `archivo:línea` y pregunta cuál manda.
- **Term-splitting**: separa términos sobrecargados. "Usuario" — ¿el que hace login o el beneficiario? Son cosas distintas.
- **XY**: si el pedido ya viene como solución, pregunta por el problema detrás antes de aceptarla.

## Cierre — bloque Acuerdo

Los siete huecos, uno por línea:

```
## Acuerdo
- Problema:
- Términos (pedido → código):
- Alcance:
- Fuera de alcance:
- Criterio de aceptación:
- Supuestos confirmados:
- Riesgo aceptado:
```

Va en el chat. Después, **integra las decisiones al `CLAUDE.md` del repo actualizando lo que corresponda**:

- Término mapeado que el archivo no declara → agrega la definición donde el archivo documenta vocabulario o convenciones.
- Decisión que fija una regla durable ("siempre X", "nunca Y") → agrégala a la sección de reglas existente.
- Supuesto confirmado que contradice algo que el archivo afirma → corrige esa línea en el lugar; no dupliques ni acumules versiones.
- Lo efímero de la tarea (criterio de aceptación, alcance puntual, riesgo de esta implementación) **no se guarda** — vive en el chat.
- Si el Acuerdo no produce nada durable, no toques el archivo. Un Acuerdo `incompleto — reformular` nunca se integra: no hay decisiones.

Si el repo no tiene `CLAUDE.md`, pide autorización para crearlo antes de escribir. No creas otros archivos en el repo.

Si una tanda termina sin cerrar ningún hueco nuevo (ver Protocolo), el problema está difuso: emites el bloque con lo que tengas y lo encabezas `## Acuerdo: incompleto — reformular`, listando qué líneas quedaron vacías y por qué. Eso es un cierre válido: pides al usuario que reformule el problema desde cero, no sigues preguntando ni entras en loop buscando completar los siete puntos.

Las contradicciones con `CLAUDE.md` se resuelven en esa misma integración. Si el acuerdo contradice algo que `README.md` declara, pide autorización al usuario para actualizarlo — no lo edites por iniciativa propia.

## Salida y handoff

Sales cuando los siete huecos están cerrados, o cuando el usuario dice "suficiente, avanza". En ese segundo caso: declara por escrito los supuestos que quedaron abiertos y avanza sin volver a insistir.

Termina siempre con esta línea, literal:

`Acuerdo cerrado. Di "continúa" para implementar según este acuerdo.`

## Ejemplo trabajado

**Pedido**: "hay que arreglar el timeout de las transcripciones".

Lectura del repo primero — buscar `timeout` en el código da dos timeouts distintos: uno en el cliente HTTP (`client.py:44`, 30s) y uno en el worker de cola (`worker.py:112`, 300s). Eso convierte un pedido difuso en una pregunta con espacio cerrado.

**Tanda 1 — huecos abiertos: 4/7** (`AskUserQuestion`, 2 preguntas):
- ¿Cuál timeout está fallando? → `client.py:44` (30s, corta audios largos) *(Recomendado — coincide con el síntoma)* / `worker.py:112` (300s) / los dos.
- ¿Subir el límite o partir el audio en chunks? → subir límite (1 línea, riesgo de conexiones colgadas) / chunking (cambio real, sirve para audios de cualquier largo).

Respuestas: `client.py`, chunking. Queda un hueco abierto de criterio de aceptación → texto plano, no widget:

> ¿Con qué caso concreto lo declaramos resuelto? Ej: un audio de 25 min entra por `POST /transcribe` y devuelve texto completo sin 504.

Confirmado. Cierre:

```
## Acuerdo
- Problema: audios >~8 min mueren con 504; el timeout de 30s en client.py:44 corta la request.
- Términos (pedido → código): "timeout de transcripciones" → client.py:44, no worker.py:112.
- Alcance: client.py (chunking del audio), tests de client.
- Fuera de alcance: worker.py, el timeout de la cola, la UI.
- Criterio de aceptación: POST /transcribe con audio de 25 min devuelve 200 y texto completo.
- Supuestos confirmados: el backend de STT acepta chunks parciales y el orden se preserva.
- Riesgo aceptado: si el STT no preserva orden entre chunks, el texto sale desordenado — se detecta en el test de 25 min.
```

`Acuerdo cerrado. Di "continúa" para implementar según este acuerdo.`

## Ejemplo de estancamiento

**Pedido**: "el sistema anda lento, optimízalo".

Lectura del repo no revela un cuello obvio. Tanda 1: ¿lento dónde — endpoint, pantalla, job? → "en general". ¿Un caso concreto: qué acción, cuánto tarda, cuánto debería? → "no sé, se siente lento". Cero huecos cerrados; "no sé" queda anotado como hueco abierto. Tanda 2 con escenario concreto propuesto: "¿`POST /transcribe` con audio de 5 min tarda >30s?" → "no me consta". Segunda tanda seguida sin cerrar ni redefinir nada → estancamiento. No hay tanda 3: cierras.

```
## Acuerdo: incompleto — reformular
- Problema: (vacío — no hay caso concreto medible; "lento en general" no es reproducible)
- Términos (pedido → código): "el sistema" sin mapear a endpoint/pantalla/job.
- Criterio de aceptación: (vacío — sin caso concreto no hay verificación posible)
- ...
```

Y pides reformular: "Necesito un caso concreto: una acción específica, cuánto tarda hoy y cuánto debería tardar. Con eso reabrimos."

## Antipatrones

- Preguntar por preguntar para parecer riguroso.
- Acumular historial en `CLAUDE.md` en vez de actualizar las líneas que corresponden.
- Convertirlo en un cuestionario de 30 puntos.
- Preguntar lo que se contesta leyendo el repo.
- Forzar `AskUserQuestion` en preguntas abiertas, inventando opciones.
- Repetir el bloqueo en cada turno sin aportar nada nuevo.
- Seguir pedante después de que el usuario cerró el tema.
- Activarte en un pedido read-only (solo modo automático).
- En modo forzado: declarar "no hay huecos" sin el Acuerdo completo, o implementar algo.
