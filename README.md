# Fuentes

Dos proyectos, cada uno en su carpeta:

- **[`BalaVa/`](BalaVa/)** — duelo del oeste para **ZX Spectrum 128K** en
  ensamblador Z80. El sheriff y el bandido se disparan de lado a lado y solo
  pueden moverse arriba y abajo; ocho balas cada uno, hasta cuatro en el aire a
  la vez, barriles de whisky y cactus que se van perforando a tiros, y un
  **caballo suelto** que pasea, pasta, se encabrita al oír un tiro y embiste al
  que le dispara. Al que le dan se lo llevan con cinemática a pantalla completa y
  funeral. Se juega a uno (con la máquina llevando al bandido) o a dos, con
  música de tres voces por el chip AY. Trae su propio emulador en JavaScript, así
  que se juega abriendo `BalaVa/dist/balava-web.html`. *(C) 2026 Kbza Soft.*
- **[`IVZApiFlowVisualBuilder/`](IVZApiFlowVisualBuilder/)** — el API Flow Tester
  que se describe aquí abajo.

## API Flow Tester

Herramienta web para **testear APIs de forma visual**: creás elementos en pantalla
(rectángulos, rombos, círculos), cada uno representa un llamado HTTP (GET / POST /
PUT / PATCH / DELETE) con su URL, headers y payload, y podés **encadenar la
respuesta de un llamado como entrada del siguiente** — por ejemplo, un login que
devuelve un token que luego viaja en el header `Authorization` de las siguientes
llamadas. Una especie de Postman visual con flujos conectables.

## Estructura

La aplicación vive en la carpeta **`IVZApiFlowVisualBuilder/`** (todas sus rutas son relativas),
pensada para publicarse como subcarpeta de un sitio con varias aplicaciones:

```
<raíz del sitio>/
    IVZApiFlowVisualBuilder/   ← esta aplicación
        index.html
        styles.css
        app.js
```

En IIS (u otro servidor) se accede como `https://<dominio>/IVZApiFlowVisualBuilder/`.

## Cómo usarla

Es una web estática, sin dependencias ni build. Opciones:

```bash
# Opción 1: abrir directamente
# (doble clic en IVZApiFlowVisualBuilder/index.html)

# Opción 2: servir localmente (recomendado)
python3 -m http.server 8080
# → http://localhost:8080/IVZApiFlowVisualBuilder/
```

## Funcionalidades

- **Nodos con forma**: rectángulo, rombo o círculo (elegible por nodo, cambiable
  desde el panel de propiedades).
- **Propiedades por nodo**: nombre, método HTTP, URL, headers (una línea por
  header, formato `Clave: Valor`) y payload/body para POST/PUT/PATCH/DELETE.
- **Conexiones**: arrastrá desde el puerto derecho (●) de un nodo y soltá sobre
  otro nodo para encadenarlos. Clic sobre una conexión para eliminarla. Se
  bloquean los ciclos automáticamente.
- **Variables entre llamadas**: en la URL, los headers o el body de un nodo podés
  referenciar la respuesta de cualquier nodo ya ejecutado:
  - `{{Login.body.accessToken}}` → campo del body JSON de la respuesta
  - `{{Login.body.usuario.id}}` → rutas anidadas (y `.0` para arrays)
  - `{{Login.status}}` → código HTTP
  - `{{Login.headers.content-type}}` → header de la respuesta
  El panel de propiedades sugiere las variables disponibles según los nodos
  conectados (clic para copiar).
- **Ejecución**: "▶ Ejecutar nodo" corre un llamado individual; "▶ Ejecutar
  flujo" corre todos los nodos en orden de dependencias (orden topológico) y se
  detiene si falla un nodo del que dependen otros.
- **Consola**: panel inferior con cada petición y respuesta (status, tiempo,
  headers y body formateado). Clic en una entrada para expandir el detalle.
- **Persistencia**: el flujo se guarda solo en `localStorage`, y se puede
  **exportar / importar** como JSON para compartirlo.
- **Ejemplo incluido**: el botón "Ejemplo" carga un flujo real contra la API
  pública [dummyjson.com](https://dummyjson.com):
  `Login (POST) → Perfil (GET con Bearer token) → Productos (GET con Bearer token)`.

## Ejemplo del caso de autenticación

1. Nodo **Login** (POST `https://dummyjson.com/auth/login`) con body
   `{"username": "emilys", "password": "emilyspass"}` → devuelve `accessToken`.
2. Nodo **Perfil** (GET `https://dummyjson.com/auth/me`) con header
   `Authorization: Bearer {{Login.body.accessToken}}`.
3. Conectás Login → Perfil y ejecutás el flujo: el token viaja automáticamente.

## Nota sobre CORS

Los llamados se hacen con `fetch` desde el navegador, por lo que el endpoint debe
permitir CORS (como cualquier API pública o tu propia API con CORS habilitado en
desarrollo). Si un llamado falla con "Failed to fetch" y el endpoint existe,
probablemente sea un bloqueo CORS: habilitá CORS en tu API, o usá un proxy local.
