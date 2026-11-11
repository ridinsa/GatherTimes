-- esES_help.lua : texto en español del panel Ayuda (un bloque por tema, ver UI/Panels/PanelHelp.lua)
local _, GT = ...
GT.locales = GT.locales or {}
GT.locales.esES = GT.locales.esES or {}
GT.helpText = GT.helpText or {}

-- topic tab captions (the buttons are ~54 px wide: keep them short)
GT.locales.esES["Start"] = "Inicio"
GT.locales.esES["Panels"] = "Paneles"
GT.locales.esES["Tips"] = "Consejos"
GT.locales.esES["HUD"] = "HUD"
GT.locales.esES["Cmds"] = "Cmds"
GT.locales.esES["Credits"] = "Créditos"

local H = "|cffffd100"      -- heading colour
local E = "|r"

local T = {}

T.hud = H .. "HUD del minimapa" .. E .. [[

Convierte el minimapa real en un gran mapa translúcido que ocupa la pantalla, con anillos opcionales, letras de brújula, rumbo e indicadores de nodos listos primero y progreso de ruta. Tus marcas de recolección siguen apareciendo.

]] .. H .. "Activarlo / desactivarlo" .. E .. [[

- Haz clic izquierdo en el botón HUD del minimapa de la ventana principal.
- Escribe /gt hud (o /gthud).
- Usa una tecla: Ajustes del HUD > Mapa > Asignación de tecla (pulsa el botón de tecla y luego una tecla; Esc cancela, Borrar la quita). También está en Asignación de teclas > AddOns > GatherTimes.
- Opcional: activarlo automáticamente cuando esté activa la recolección (Ajustes del HUD > Opciones).

]] .. H .. "Ajustes del HUD (clic derecho en el botón HUD)" .. E .. [[

- Mapa: tamaño del HUD, opacidad del mapa (0 % = mapa en blanco, solo se ven las marcas; 100 % = opaco; 10 niveles), zoom del minimapa, asignación de tecla.
- Anillos: radio del anillo, segundo anillo, grosor, suavidad, estilo del anillo (línea, rayas o puntos: el botón los recorre), densidad, colores de anillo (Color del anillo... abre el selector: deslizadores para cada anillo y un botón Color aleatorio para la pestaña del anillo abierta), letras de brújula (N E S O), indicador de rumbo, indicador de recolección con listos primero (nodo listo más cercano; si no, próxima reaparición) e indicador de progreso de ruta (paso planificado actual). Cada indicador se puede activar o desactivar.
- Seguimiento: botón de seguimiento cuando el HUD está activo (tamaño 20-80 px y posición) y qué hace cuando el HUD está desactivado (auto, own o stock).
- Opciones: girar el mapa con el jugador, flecha del jugador, ocultar HUD al montar, activarlo automáticamente con el seguimiento de recolección, restaurar HUD tras /reload o iniciar sesión, ocultar skins de addons del minimapa, diagnóstico.
- Perfil: guardar varios aspectos, cambiar entre ellos o borrarlos. Los perfiles se comparten entre todos los personajes; cada personaje recuerda el suyo.
- Restablecer perfil restaura los valores predeterminados.]]

T.credits = H .. "GatherTimes 0.24.3" .. E .. [[

Autor: miRidinsa
Web: https://github.com/ridinsa/
Licencia: GNU GPL v3 o posterior (consulta el archivo LICENSE en la carpeta del addon).

]] .. H .. "Bibliotecas" .. E .. [[

- HereBeDragons-2.0 y HereBeDragons-Pins-2.0 de Nevcairiel: posiciones de las marcas en el minimapa y el mapa mundial.
- LibStub y CallbackHandler-1.0 (bibliotecas WoW Ace): carga de bibliotecas y callbacks.

]] .. H .. "Nombre aleatorio" .. E .. [[

Una copia integrada del módulo HideUnitNames (también se admite el addon independiente con el mismo nombre: cuando está cargado, esta copia se desactiva).

]] .. H .. "Addons de apoyo" .. E .. [[

- HereBeDragons: necesario para las marcas.
- GatherMate2: se pueden importar sus datos de nodos.
- TomTom: waypoints para la flecha y las rutas.

]] .. H .. "Traducciones" .. E .. [[

Los archivos de idioma de la carpeta Locales. Gracias a todos los que ayudaron con ellos y a quienes enviaron informes de depuración.]]

T.start = H .. "Bienvenido a GatherTimes" .. E .. [[

Controla cuándo reaparecen hierbas y minerales en la zona en la que estás, recuerda dónde aparecen los nodos y los muestra en la ventana principal, en el minimapa y en el mapa del mundo.

]] .. H .. "Inicio rápido" .. E .. [[

1. Abre la ventana con /gt.
2. Pulsa Nodos (abajo) y marca las hierbas / minerales que recolectas.
3. Recolecta. Un timer empieza en cuanto saqueas un nodo.
4. Mira la tabla de la ventana principal. Cuando un nodo está listo recibes una alerta en pantalla, un sonido y un aviso sonoro si estás cerca.

]] .. H .. "La ventana principal" .. E .. [[

- Desplegable (arriba): muestra cada nodo marcado, o solo uno.
- Los recuentos del inventario aparecen alineados a la derecha en el desplegable de objetos abierto; el recuento se oculta en el objeto cerrado y seleccionado.
- Tabla: una fila por grupo de nodos cercanos. G1, G2... son los números de grupo que también ves en el mapa.
- Estado: Waiting = todos los nodos siguen en cuenta atrás. 2/3 up = algunos ya han vuelto. Ready = todos han vuelto. Idle = no hay ningún timer en marcha.
- Un nodo permanece Ready un rato después de reaparecer y luego pasa a Idle (tú eliges cuánto en Ajustes > General > Ready status lasts).
- Las alertas se envían solo una vez por timer. Usa Ajustes > General para la distancia mínima y máxima, y Nodos > Alert para activar o silenciar las alertas de cada recurso.
- Botón Minimap HUD On/Off: clic izquierdo activa o desactiva el HUD, clic derecho abre los ajustes del HUD. Su texto está en verde cuando el HUD está activo y en gris cuando está desactivado.
- La etiqueta del servidor y del modo de juego aparece debajo de la tabla de timers.
- Los 5 botones de abajo abren los paneles. Pulsa el mismo botón otra vez para cerrar su panel.
- Arrastra la barra del título para mover la ventana. El título muestra la zona en la que estás.
- El botón ? de la barra del título abre esta ayuda.
- El botón - de la barra del título minimiza la ventana a una barra fina a lo largo de la parte superior de la pantalla. Clic derecho para los ajustes de Minimizar. En la barra: el desplegable de objetos, un chip por grupo, el oro de la sesión y el botón "+", que devuelve la ventana. Dos clics derechos en el oro para reiniciar la sesión (el resumen se imprime antes en el chat).

]]

T.panels = H .. "Timers" .. E .. [[

Cada timer en marcha, primero los listos (Grp, Node, Time), más los totales de tu sesión. Clear waypoint quita la flecha. Show summary abre el resumen de la sesión (objetos, valor en oro y oro por hora) en una caja que puedes copiar. Reset session imprime primero el resumen, luego reinicia el reloj de la sesión y borra los recuentos.

]] .. H .. "Nodos" .. E .. [[

Elige qué rastreas y cómo.
- On: marca para rastrear una hierba / mineral.
- Min: tiempo de reaparición en minutos. Escribe un número nuevo y pulsa Enter.
- Col: color del nodo en el mapa y en las listas. Clic izquierdo = siguiente color, clic derecho = anterior.
- Alert: activa o silencia las alertas de listo para este recurso. La comprobación no depende de si el recurso se muestra en el desplegable principal.
- Sound: sonido de la alerta. Clic = siguiente (reproduce una vista previa), clic derecho = anterior.
- Dropdown: All / Herbs / Ore. List all: muestra cada nodo, no solo los de tu zona actual.
- Nodes per group: cuántos nodos cercanos forman un grupo (G1, G2...).
- Nodes up per group: cuántos deben haber reaparecido para que el grupo cuente como listo.
- Select All, Select None, Reset (vuelve a los tiempos por defecto).
- El desplegable de objetos abierto de la ventana principal también muestra cuántos de ese recurso tienes en las bolsas; el botón seleccionado no muestra recuento.

]] .. H .. "Ruta" .. E .. [[

- Ruta: elige un recurso de hierba / mineral activado o todos los activados, luego Build route traza un camino por los timers activos. Next step pasa al siguiente paso, Clear route lo elimina. Las opciones incluyen solo nodos listos, dibujar en el mapa, flecha automática, número máximo de nodos y ventana de tiempo. Prioriza los recursos con poco inventario para favorecer los que están por debajo del objetivo de stock (solo bolsas).
- Marcas: muestra los pines de aparición en el mapa y el minimapa, las etiquetas de grupo (G1, G2...), puntos para otros objetos, oculta los puntos recolectados en esta sesión, clic derecho en un punto para el menú de grupo, desplazamiento de nodos al recolectar y Refresh pins. El filtro de puntos recolectados se borra al reiniciar la sesión.
- Flecha: integración con TomTom, flecha al nodo más cercano, avance automático al siguiente nodo de la ruta, distancia de la flecha, Waypoint to nearest. Necesita el addon TomTom.

]] .. H .. "Tiempos" .. E .. [[

Por nodo: Now = el tiempo de reaparición en uso. Learned (n) = el rango medido en tus propias visitas, el típico rápido (por ejemplo 10.5-12.0), n = número de muestras (naranja con menos de 5, amarillo 5-9, verde 10 o más; un tiempo aprendido en verde significa que el valor típico es más rápido que Now; * = valor de todo el objeto que se muestra en el modo Per zone). Las reapariciones varían, así que espera cualquier valor de ese rango. Apply / auto-apply usan el valor típico (el de la derecha). Taken = con qué frecuencia se encontró vacío un punto.
- Learned times: Per item (un tiempo aprendido por hierba / mineral, por defecto) o Per zone (la zona en la que estás, una vez tiene 5 muestras).
- One shared timer per group, Detect empty nodes, Use game messages, Auto-adjust learned times (más corto o más largo, nunca más del doble del tiempo de fábrica). El interruptor de zona está en Ajustes > General.
- Apply all faster copia los tiempos aprendidos a Now. Reset learned timings los borra.

]] .. H .. "Ajustes" .. E .. [[

- General: alerta en pantalla y Alert time, distancia mínima y máxima para la alerta de listo (0 desactiva ese límite), alerta cuando el chat anuncia mantenimiento (color del destello 1-7), aviso de salud baja (Hardcore), Ready status lasts, y Solo mostrar timers y pines de la zona en la que estoy.
- Pantalla: tamaño del texto del mapa, tamaño de la ventana, semitransparente al mover, mantener ventanas visibles (ESC no las cierra), y tooltip de objeto al pasar el ratón. El desplegable de idioma está en Look; se aplica tras recargar la interfaz (se muestra como "w/reload").
- Look: Idioma, Frame skin (temas de color para ventanas y tooltips; Pastel Pink y Sakura usan texto oscuro con un borde fino), Font (Friz Quadrata, Arial Narrow, Skurri, Morpheus, o Friends si el cliente la tiene) y Font size (de 80% a 130%). Coreano, chino, japonés y ruso mantienen su propia fuente, así que en su lugar se muestra una nota.
- Herram.: estado del addon y sus ayudantes, Import GatherMate2, Clear learned spawn points, Export my spots / Import spots (compartir puntos con amigos), Copy debug report (un bloque de texto para un informe de error), Reset timers, Start a new session at login, y el registro de errores.

]] .. H .. "Inventario y resumen de sesión" .. E .. [[

El desplegable de recursos abierto muestra tu recuento en las bolsas junto a cada objeto; el botón del objeto seleccionado oculta su recuento. El panel Timers muestra los totales de la sesión. Show summary abre el mismo resumen; Reset session los imprime primero, y luego borra los recuentos y reinicia el reloj. Solo cuenta el botín de recolección reconocido. Reset session también borra el filtro de puntos recolectados que solo vale para la sesión.

]] .. H .. "Nombre aleatorio" .. E .. [[

Clic derecho en el botón Settings de la ventana principal para abrirlo (otro clic derecho lo cierra). Oculta tu propio nombre en tu pantalla, para streaming o capturas. Los demás jugadores siguen viendo tu nombre real.
- Disguise names: activa o desactiva el disfraz. Mientras está activo, los nombres de otros jugadores también se ocultan (mediante los ajustes de nombres del juego, que se restauran al desactivarlo).
- Hide party / raid names: oculta por separado las etiquetas de nombre de grupo y de banda en tu pantalla.
- Fake player name / Fake pet name: los nombres que se muestran en su lugar. Escribe un nombre y pulsa Enter o Apply. Hasta 12 caracteres.
- Randomize Names: elige nombres aleatorios nuevos y un nivel falso. El deslizador Random level range fija el nivel máximo. Opacity atenúa el fondo de la ventana manteniendo legible el texto.
- Se muestra en: tus marcos de unidad (también cuando te seleccionas a ti mismo o a tu mascota), el tooltip de unidad, el título de la ventana de personaje y el chat. Con el disfraz activo, los nombres de personaje coincidentes también se ocultan en los tooltips de objetos.
- Comandos: /hun (activa o desactiva el disfraz), /hun player <n>, /hun pet <n>, /hun random, /hun status, /hun help.
- Si el addon independiente HideUnitNames está cargado, Nombre aleatorio de aquí se desactiva. Usa ese addon.

]]

T.tips = H .. "Grupos" .. E .. [[

Los nodos cercanos se tratan como un solo grupo, así ves cuándo ha vuelto todo el grupo en vez de cada nodo por separado. Con One shared timer per group (panel Tiempos), el grupo tiene un único timer.

]] .. H .. "Corregir un punto (mapa del mundo)" .. E .. [[

Clic derecho en un texto de timer o en un pin de punto del mapa del mundo para abrir un pequeño menú (actívalo en Nav > Marcas):
- Este punto está vacío: alguien más lo ha cogido.
- Grupo cogido por alguien: todo el grupo ya se había recolectado.
- Mover este punto a grupo: ponlo en otro grupo (1, 2, 3... o New).
- Escribe una nota corta y pulsa Save note para adjuntar un recordatorio a ese punto. Pasa el ratón sobre el punto para ver su nota. Las notas se guardan con el punto.
El minimapa nunca abre este menú. Puedes desactivarlo en Nav > Marcas.

]] .. H .. "Cómo se aprenden los tiempos de reaparición" .. E .. [[

Cada vez que un nodo ha vuelto y lo saqueas, se guarda el tiempo desde el botín del que es la reaparición (en un grupo con varios nodos arriba a la vez, es el más antiguo de los botines recientes, no el más nuevo). El addon ignora los intervalos muy cortos y muy largos, y luego muestra el valor del cuarto más rápido hasta la mediana (típico) de tus muestras, redondeado a 15 segundos, en Tiempos. Apply y auto-apply usan la mediana. Necesita 3 muestras para mostrar un valor y 5 para aplicarlo automáticamente.

]] .. H .. "Compartir puntos con amigos" .. E .. [[

Ajustes > Herram. > Export my spots (o /gt export) muestra tus propios puntos como una línea de texto. Haz clic en la caja, pulsa Ctrl+C y envíalo a un amigo. Tu amigo usa Import spots (o /gt import), lo pega con Ctrl+V y pulsa Import. Solo se comparten objeto, zona y posición, sin timers ni recuentos. Los puntos que ya tiene se dejan como están, y un texto cortado por el camino se rechaza en vez de importarlo a medias.

]] .. H .. "Addons auxiliares" .. E .. [[

- HereBeDragons: necesario para los pines en el mapa y el minimapa. Instálalo.
- GatherMate2: Ajustes > Herram. > Import GatherMate2 añade las ubicaciones de nodos que conoce.
- TomTom: permite que la flecha y los waypoints de ruta se muestren.

]] .. H .. "¿Algo va mal?" .. E .. [[

- Sin pines: instala HereBeDragons. Ajustes > Herram. muestra lo que se ha encontrado.
- Los timers no empiezan: escribe /gt debug y saquea un nodo; mostrará lo que ve el addon.
- Los errores aparecen en Ajustes > Herram. > Error log (haz clic, Ctrl+A, Ctrl+C para copiar).
- Para informar de un problema o de un conflicto con otro addon: Ajustes > Herram. > Copy debug report (o /gt report), copia el texto y pégalo en el informe.
- Punto o grupo incorrecto: haz clic derecho en él en el mapa del mundo.]]

T.cmds = H .. "Comandos slash" .. E .. [[

/gt - abre o cierra la ventana principal
/gt list - timers activos en el chat
/gt stats - totales de la sesión en el chat
/gt yield - rendimientos guardados por zona y objeto (las 10 zonas principales)
/gt yield current - totales de rendimiento de la zona actual
/gt debug - mensajes de detección de botín activados / desactivados
/gt profile start | stop | report - perfila el bucle de timers
/gt hud - minimapa HUD (ver abajo)
/gt min - minimiza a la barra, o devuelve la ventana
/gt dock - la barra empuja los marcos superiores del juego hacia abajo (activado) o solo los tapa (desactivado)
/gt export - muestra tus propios puntos como texto para compartir
/gt import - importa puntos desde el texto de un amigo
/gt report - informe de depuración para copiar en un informe de error
/gthud - igual que /gt hud
/hun - Nombre aleatorio (ver Paneles > Ajustes > Nombre aleatorio)

]] .. H .. "Comandos del HUD" .. E .. [[

/gthud - activa o desactiva el HUD
/gthud on | off
/gthud config - abre los ajustes del HUD
/gthud size 800 - tamaño del HUD (de 150 a 1400)
/gthud alpha 0.5 - opacidad del mapa (de 0 a 1)
/gthud zoom 3 - zoom del minimapa (de 0 a 5)
/gthud rotate - girar con el jugador activado / desactivado
/gthud ring 150 - radio del anillo en px (0 = desactivado)
/gthud ring2 300 - segundo anillo
/gthud ringthick 2 - grosor del anillo (de 1 a 10)
/gthud ringseg 96 - suavidad del anillo (de 8 a 256)
/gthud ringstyle solid | stripes | dots - estilo del anillo
/gthud ringdensity 24 - rayas o puntos alrededor del anillo (de 4 a 128)
/gthud ringcolor 1 1 1 0.8 - rojo verde azul opacidad
/gthud ringcolor2 1 1 1 0.8 - color del segundo anillo
/gthud dirs - letras de la brújula activadas / desactivadas
/gthud heading - lectura de rumbo activada / desactivada
/gthud tracking - botón de seguimiento activado / desactivado
/gthud tracksize 50 - tamaño del botón de seguimiento (de 20 a 80)
/gthud trackpos 0 0 - desplazamiento del botón de seguimiento para el estado actual del HUD
/gthud trackmode auto | own | stock - botón de seguimiento con el HUD desactivado
/gthud arrow - flecha del jugador activada / desactivada
/gthud addons - ocultar pieles / botones de addons del minimapa activado / desactivado
/gthud scan - análisis profundo de addons del minimapa activado / desactivado
/gthud mountfade - ocultar el HUD montado activado / desactivado
/gthud autogather - activar automáticamente con el seguimiento de recolección activado / desactivado
/gthud restore - restaurar el HUD tras /reload o login activado / desactivado
/gthud profile - lista perfiles; /gthud profile <n> cambia o crea uno
/gthud profile delete <n> - borra un perfil (Default y el perfil activo no se pueden borrar)
/gthud status | info | frames | debug - estado, diagnóstico o mensajes de depuración
/gthud reset - restablece el perfil actual
/gthud help - muestra la ayuda de comandos]]

GT.helpText.esES = T
