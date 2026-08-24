# Jarvis / Amanda — Servidor MCP

Este repo está configurado para conectarse al servidor **MCP** de Amanda
(motor de razonamiento «IVZ Global») vía `.mcp.json`.

- **Endpoint:** `https://amdlabs.blogdns.org/Jarvis/api/mcp`
- **Transporte:** HTTP (streamable), protocolo MCP `2024-11-05`
- **Autenticación:** header `Authorization: Bearer <token>`
- **Servidor:** `Amanda (IVZ Global)` v1.0
- **Voz en tiempo real** (misma credencial): `wss://amdlabs.blogdns.org/Jarvis/api/live?token=<token>`

## El token va por variable de entorno

Para no dejar la credencial escrita en el repo, `.mcp.json` referencia
`${JARVIS_MCP_TOKEN}`. Antes de arrancar Claude Code, exportá el token:

```bash
export JARVIS_MCP_TOKEN="amcp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
```

- **Claude Code (escritorio/CLI):** ponelo en tu shell (`~/.bashrc`, `~/.zshrc`)
  o en un `.env` local que cargues antes de lanzar `claude`.
- **Claude Code en la web:** definí `JARVIS_MCP_TOKEN` en las variables de
  entorno del *environment* de la sesión.

Claude Code lee `.mcp.json` **al iniciar la sesión**. Si agregás o cambiás la
configuración, reiniciá la sesión y aprobá el servidor MCP cuando lo pida.

## Herramientas que expone Amanda

| Herramienta          | Qué hace |
|----------------------|----------|
| `razonar`            | Le hace una pregunta a Amanda y devuelve su respuesta razonada (usa persona, estilo, base de conocimiento y memoria de la sesión). Args: `pregunta` (requerido), `sesion`. |
| `aportar_contexto`   | Le entrega datos a Amanda sin pedir respuesta (fichas, estados, registros). Quedan en la memoria de la sesión. Args: `datos` (requerido), `sesion`. |
| `buscar_conocimiento`| Busca en la base de conocimiento (manuales, documentos, bitácoras) y devuelve los fragmentos relevantes. Args: `consulta` (requerido). |
| `estado_sesion`      | Devuelve los últimos turnos de una sesión del canal. Args: `sesion`. |
| `borrar_sesion`      | Vacía la memoria de una sesión del canal. Args: `sesion`. |

> El argumento `sesion` separa hilos de conversación; cada canal tiene su
> memoria aislada. Omitirlo usa la sesión por defecto del canal.

## Verificar la conexión a mano

```bash
curl -sS -X POST "https://amdlabs.blogdns.org/Jarvis/api/mcp" \
  -H "Authorization: Bearer $JARVIS_MCP_TOKEN" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"cli","version":"1.0"}}}'
```

Debe responder `200` con `serverInfo.name = "Amanda (IVZ Global)"`.
