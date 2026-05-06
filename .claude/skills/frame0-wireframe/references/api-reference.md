# Frame0 HTTP API Reference

Frame0 exposes a local HTTP API when the desktop app is running.

## Endpoint

```
POST http://localhost:{port}/execute_command
Content-Type: application/json
```

Default port: **58320** (override via `FRAME0_PORT` env var or `--port` flag).

## Request / Response

```json
{"command": "namespace:action", "args": { ... }}
```

```json
{"success": true, "data": { ... }}
{"success": false, "error": "description"}
```

---

## Type Mapping

Frame0 uses different type names for create vs get:

| Create API (`type`) | Get API (internal) | Description |
|--------------------|--------------------|-------------|
| `Rectangle` | `Box` | Rectangle with optional corners |
| `Ellipse` | `Ellipse` | Circle/ellipse |
| `Text` | `Text` | Text label |
| `Line` | `Line` | Line/polyline |
| `Frame` | `Frame` | Container from library |
| `Freehand` | `Freehand` | Freehand drawing |
| `Highlighter` | `Highlighter` | Highlighter stroke |

The sync script handles this mapping transparently.

## Color Tokens

Frame0 maps hex colors to theme tokens on creation (`convertColors: true`):

| Hex | Token | Role |
|-----|-------|------|
| `#1a1e24` | `$sage3` | Background |
| `#2a3040` | `$slate5` | Fill |
| `#333340` | `$slate6` | Stroke |
| `#c8d0e0` | `$mint12` | Text |
| `#c8d8f0` | `$blue12` | Accent |

Both hex and token strings work in the API. Tokens are preserved on round-trip.

---

## Commands

### shape:create-shape

```json
{
  "command": "shape:create-shape",
  "args": {
    "type": "Rectangle",
    "shapeProps": {
      "name": "my-button",
      "left": 100, "top": 200, "width": 120, "height": 36,
      "fillColor": "#2a3040",
      "strokeColor": "#c8d8f0",
      "corners": [4, 4, 4, 4]
    },
    "parentId": "optional-parent-shape-id",
    "convertColors": true
  }
}
```

Returns: shape ID (string).

### shape:get-shape

```json
{"command": "shape:get-shape", "args": {"shapeId": "id"}}
```

### shape:update-shape

```json
{
  "command": "shape:update-shape",
  "args": {
    "shapeId": "id",
    "shapeProps": {"fillColor": "#1a1e24", "text": "Updated"},
    "convertColors": true
  }
}
```

### shape:move

```json
{"command": "shape:move", "args": {"shapeId": "id", "dx": 50, "dy": -20}}
```

### shape:create-connector

```json
{
  "command": "shape:create-connector",
  "args": {
    "tailId": "source-id",
    "headId": "target-id",
    "shapeProps": {"strokeColor": "#c8d8f0"},
    "convertColors": true
  }
}
```

### shape:create-icon

```json
{
  "command": "shape:create-icon",
  "args": {
    "iconName": "search",
    "shapeProps": {"left": 100, "top": 100, "width": 24, "height": 24}
  }
}
```

### shape:get-available-icons

```json
{"command": "shape:get-available-icons", "args": {}}
```

### shape:group / shape:ungroup

```json
{"command": "shape:group", "args": {"shapeIdArray": ["id1", "id2"]}}
{"command": "shape:ungroup", "args": {"shapeIdArray": ["group-id"]}}
```

### edit:delete / edit:duplicate

```json
{"command": "edit:delete", "args": {"shapeIdArray": ["id1", "id2"]}}
{"command": "edit:duplicate", "args": {"shapeIdArray": ["id"], "dx": 20, "dy": 0}}
```

### page:add

```json
{"command": "page:add", "args": {"pageProps": {"name": "Page Name"}}}
```

Returns: `{id, type, name}`.

### page:get

```json
{"command": "page:get", "args": {"pageId": "id", "exportShapes": true}}
```

### page:get-current-page

```json
{"command": "page:get-current-page", "args": {}}
```

Returns: page ID string.

### page:set-current-page

```json
{"command": "page:set-current-page", "args": {"pageId": "id"}}
```

### doc:get (list all pages)

```json
{"command": "doc:get", "args": {"exportPages": true, "exportShapes": false}}
```

### page:delete

```json
{"command": "page:delete", "args": {"pageId": "id"}}
```

### file:export-image

```json
{
  "command": "file:export-image",
  "args": {
    "pageId": "optional-page-id",
    "format": "image/png",
    "fillBackground": true
  }
}
```

Formats: `image/png`, `image/jpeg`, `image/webp`, `image/svg+xml`.
Returns: base64-encoded image data.

### view:fit-to-screen

```json
{"command": "view:fit-to-screen", "args": {}}
```

---

## Shape Properties

| Property | Type | Notes |
|----------|------|-------|
| `name` | string | Shape identifier/label |
| `left` | number | X position (origin: top-left) |
| `top` | number | Y position |
| `width` | number | Width in pixels |
| `height` | number | Height in pixels |
| `fillColor` | string | Hex or `$token` |
| `strokeColor` | string | Hex or `$token` |
| `strokeWidth` | number | Border width |
| `fontColor` | string | Text color (hex or `$token`) |
| `fontSize` | number | Font size in pixels |
| `fontFamily` | string | Font name (Frame0 default: `Loranthus`) |
| `text` | string | Text content |
| `wordWrap` | boolean | Enable word wrapping |
| `corners` | number[4] | Border radius [TL, TR, BR, BL] |
| `roughness` | number | Sketch roughness (Frame0 default: 1) |
| `constraints` | array | Auto-sizing constraints |
| `horzAlign` | string | Horizontal text alignment |
| `vertAlign` | string | Vertical text alignment |
| `fillStyle` | string | Fill style (`none` for transparent) |
| `path` | array | Coordinate pairs for lines |
