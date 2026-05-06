# Component Library

Pre-built wireframe JSON templates for The Settled Reach UI. Copy the JSON,
adapt positions/sizes, save to `docs/design/wireframes/{category}/`, and push.

**Viewport:** 1140x780 (Godot project settings)
**Grid unit:** 8px
**Min touch target:** 36px height
**Font sizes:** 12 (label), 14 (body), 16 (subtitle), 18 (heading), 24 (title)

---

## 1. HUD Layout

Main gameplay overlay. Minimap top-right, monologue bottom-center,
insert display bottom-left, action hints bottom-right.

```json
{
  "name": "HUD Layout",
  "shapes": {
    "minimap": {
      "type": "Rectangle",
      "left": 880, "top": 20, "width": 240, "height": 240,
      "fillColor": "#1a1e24", "strokeColor": "#333340",
      "corners": [4, 4, 4, 4]
    },
    "minimap-label": {
      "type": "Text",
      "parent": "minimap",
      "left": 890, "top": 30,
      "text": "Minimap",
      "fontColor": "#c8d0e0", "fontSize": 14
    },
    "monologue": {
      "type": "Rectangle",
      "left": 300, "top": 680, "width": 520, "height": 80,
      "fillColor": "#1a1e24", "strokeColor": "#333340",
      "corners": [4, 4, 4, 4]
    },
    "monologue-text": {
      "type": "Text",
      "parent": "monologue",
      "left": 310, "top": 700, "width": 500,
      "text": "Internal monologue text appears here...",
      "fontColor": "#c8d0e0", "fontSize": 13, "wordWrap": true
    },
    "insert": {
      "type": "Rectangle",
      "left": 20, "top": 600, "width": 260, "height": 160,
      "fillColor": "#1a1e24", "strokeColor": "#333340",
      "corners": [4, 4, 4, 4]
    },
    "insert-label": {
      "type": "Text",
      "parent": "insert",
      "left": 30, "top": 620,
      "text": "Neural Insert Data",
      "fontColor": "#c8d0e0", "fontSize": 14
    },
    "hints": {
      "type": "Rectangle",
      "left": 880, "top": 700, "width": 240, "height": 60,
      "fillColor": "#1a1e24", "strokeColor": "#333340",
      "corners": [4, 4, 4, 4]
    },
    "hints-label": {
      "type": "Text",
      "parent": "hints",
      "left": 890, "top": 720,
      "text": "[E] Interact  [TAB] Insert",
      "fontColor": "#c8d0e0", "fontSize": 12
    }
  }
}
```

---

## 2. Dialogue Box

Speaker panel with response options. Anchored bottom-center during dialogue mode.

```json
{
  "name": "Dialogue Box",
  "shapes": {
    "panel": {
      "type": "Rectangle",
      "left": 170, "top": 500, "width": 800, "height": 260,
      "fillColor": "#1a1e24", "strokeColor": "#333340",
      "corners": [8, 8, 8, 8]
    },
    "speaker": {
      "type": "Text",
      "parent": "panel",
      "left": 190, "top": 520,
      "text": "LERA KONSTANTIN",
      "fontColor": "#c8d0e0", "fontSize": 16
    },
    "text-area": {
      "type": "Rectangle",
      "parent": "panel",
      "left": 190, "top": 550, "width": 760, "height": 100,
      "fillColor": "#2a3040", "strokeColor": "#333340",
      "corners": [4, 4, 4, 4]
    },
    "dialogue-text": {
      "type": "Text",
      "parent": "text-area",
      "left": 200, "top": 560, "width": 740,
      "text": "You look like you could use a drink. First time on the station?",
      "fontColor": "#c8d0e0", "fontSize": 14, "wordWrap": true
    },
    "btn-option1": {
      "type": "Rectangle",
      "parent": "panel",
      "left": 190, "top": 670, "width": 370, "height": 30,
      "fillColor": "#2a3040", "strokeColor": "#c8d8f0",
      "corners": [4, 4, 4, 4]
    },
    "btn-option1-label": {
      "type": "Text",
      "parent": "btn-option1",
      "left": 200, "top": 674,
      "text": "[1] Ask about the station",
      "fontColor": "#c8d8f0", "fontSize": 12
    },
    "btn-option2": {
      "type": "Rectangle",
      "parent": "panel",
      "left": 190, "top": 710, "width": 370, "height": 30,
      "fillColor": "#2a3040", "strokeColor": "#c8d8f0",
      "corners": [4, 4, 4, 4]
    },
    "btn-option2-label": {
      "type": "Text",
      "parent": "btn-option2",
      "left": 200, "top": 714,
      "text": "[2] Ask about recent events",
      "fontColor": "#c8d8f0", "fontSize": 12
    },
    "btn-leave": {
      "type": "Rectangle",
      "parent": "panel",
      "left": 580, "top": 670, "width": 180, "height": 30,
      "fillColor": "#2a3040", "strokeColor": "#c8d8f0",
      "corners": [4, 4, 4, 4]
    },
    "btn-leave-label": {
      "type": "Text",
      "parent": "btn-leave",
      "left": 590, "top": 674,
      "text": "[3] Leave",
      "fontColor": "#c8d8f0", "fontSize": 12
    }
  }
}
```

---

## 3. Menu Screen

Full-screen menu with sidebar navigation and content area.

```json
{
  "name": "Pause Menu",
  "shapes": {
    "bg": {
      "type": "Rectangle",
      "left": 0, "top": 0, "width": 1140, "height": 780,
      "fillColor": "#1a1e24"
    },
    "nav": {
      "type": "Rectangle",
      "parent": "bg",
      "left": 20, "top": 20, "width": 200, "height": 740,
      "fillColor": "#2a3040", "strokeColor": "#333340",
      "corners": [4, 4, 4, 4]
    },
    "btn-inventory": {
      "type": "Rectangle", "parent": "nav",
      "left": 30, "top": 40, "width": 180, "height": 36,
      "fillColor": "#2a3040", "strokeColor": "#c8d8f0", "corners": [4, 4, 4, 4]
    },
    "btn-inventory-label": {
      "type": "Text", "parent": "btn-inventory",
      "left": 40, "top": 48, "text": "Inventory",
      "fontColor": "#c8d8f0", "fontSize": 14
    },
    "btn-journal": {
      "type": "Rectangle", "parent": "nav",
      "left": 30, "top": 86, "width": 180, "height": 36,
      "fillColor": "#2a3040", "strokeColor": "#c8d8f0", "corners": [4, 4, 4, 4]
    },
    "btn-journal-label": {
      "type": "Text", "parent": "btn-journal",
      "left": 40, "top": 94, "text": "Journal",
      "fontColor": "#c8d8f0", "fontSize": 14
    },
    "btn-map": {
      "type": "Rectangle", "parent": "nav",
      "left": 30, "top": 132, "width": 180, "height": 36,
      "fillColor": "#2a3040", "strokeColor": "#c8d8f0", "corners": [4, 4, 4, 4]
    },
    "btn-map-label": {
      "type": "Text", "parent": "btn-map",
      "left": 40, "top": 140, "text": "Map",
      "fontColor": "#c8d8f0", "fontSize": 14
    },
    "btn-settings": {
      "type": "Rectangle", "parent": "nav",
      "left": 30, "top": 178, "width": 180, "height": 36,
      "fillColor": "#2a3040", "strokeColor": "#c8d8f0", "corners": [4, 4, 4, 4]
    },
    "btn-settings-label": {
      "type": "Text", "parent": "btn-settings",
      "left": 40, "top": 186, "text": "Settings",
      "fontColor": "#c8d8f0", "fontSize": 14
    },
    "btn-resume": {
      "type": "Rectangle", "parent": "nav",
      "left": 30, "top": 720, "width": 180, "height": 36,
      "fillColor": "#2a3040", "strokeColor": "#c8d8f0", "corners": [4, 4, 4, 4]
    },
    "btn-resume-label": {
      "type": "Text", "parent": "btn-resume",
      "left": 40, "top": 728, "text": "Resume",
      "fontColor": "#c8d8f0", "fontSize": 14
    },
    "content": {
      "type": "Rectangle",
      "parent": "bg",
      "left": 240, "top": 20, "width": 880, "height": 740,
      "fillColor": "#2a3040", "strokeColor": "#333340",
      "corners": [4, 4, 4, 4]
    },
    "content-label": {
      "type": "Text", "parent": "content",
      "left": 260, "top": 40,
      "text": "Content area",
      "fontColor": "#c8d0e0", "fontSize": 14
    }
  }
}
```

---

## 4. Modal Dialog

Centered overlay for confirmations, alerts, choices.

```json
{
  "name": "Modal Dialog",
  "shapes": {
    "overlay": {
      "type": "Rectangle",
      "left": 0, "top": 0, "width": 1140, "height": 780,
      "fillColor": "#0a0c10"
    },
    "modal": {
      "type": "Rectangle",
      "parent": "overlay",
      "left": 320, "top": 240, "width": 500, "height": 300,
      "fillColor": "#1a1e24", "strokeColor": "#333340",
      "corners": [8, 8, 8, 8]
    },
    "title": {
      "type": "Text", "parent": "modal",
      "left": 340, "top": 260,
      "text": "Confirm Action",
      "fontColor": "#c8d0e0", "fontSize": 18
    },
    "divider": {
      "type": "Line", "parent": "modal",
      "left": 340, "top": 290, "width": 460, "height": 0,
      "strokeColor": "#333340"
    },
    "body-1": {
      "type": "Text", "parent": "modal",
      "left": 340, "top": 310,
      "text": "Are you sure you want to proceed?",
      "fontColor": "#c8d0e0", "fontSize": 14
    },
    "body-2": {
      "type": "Text", "parent": "modal",
      "left": 340, "top": 340,
      "text": "This action cannot be undone.",
      "fontColor": "#c8d0e0", "fontSize": 14
    },
    "btn-cancel": {
      "type": "Rectangle", "parent": "modal",
      "left": 480, "top": 480, "width": 120, "height": 36,
      "fillColor": "#2a3040", "strokeColor": "#c8d8f0", "corners": [4, 4, 4, 4]
    },
    "btn-cancel-label": {
      "type": "Text", "parent": "btn-cancel",
      "left": 510, "top": 488,
      "text": "Cancel",
      "fontColor": "#c8d8f0", "fontSize": 14
    },
    "btn-confirm": {
      "type": "Rectangle", "parent": "modal",
      "left": 620, "top": 480, "width": 120, "height": 36,
      "fillColor": "#2a3040", "strokeColor": "#c8d8f0", "corners": [4, 4, 4, 4]
    },
    "btn-confirm-label": {
      "type": "Text", "parent": "btn-confirm",
      "left": 645, "top": 488,
      "text": "Confirm",
      "fontColor": "#c8d8f0", "fontSize": 14
    }
  }
}
```

---

## 5. List View

Scrollable list with item selection and detail panel.

```json
{
  "name": "List View",
  "shapes": {
    "list-panel": {
      "type": "Rectangle",
      "left": 20, "top": 20, "width": 400, "height": 740,
      "fillColor": "#1a1e24", "strokeColor": "#333340", "corners": [4, 4, 4, 4]
    },
    "item-1": {
      "type": "Rectangle", "parent": "list-panel",
      "left": 30, "top": 30, "width": 380, "height": 40,
      "fillColor": "#2a3040", "strokeColor": "#c8d8f0", "corners": [4, 4, 4, 4]
    },
    "item-1-label": {
      "type": "Text", "parent": "item-1",
      "left": 40, "top": 38, "text": "Item Alpha",
      "fontColor": "#c8d8f0", "fontSize": 14
    },
    "item-2": {
      "type": "Rectangle", "parent": "list-panel",
      "left": 30, "top": 80, "width": 380, "height": 40,
      "fillColor": "#2a3040", "strokeColor": "#333340", "corners": [4, 4, 4, 4]
    },
    "item-2-label": {
      "type": "Text", "parent": "item-2",
      "left": 40, "top": 88, "text": "Item Beta",
      "fontColor": "#c8d0e0", "fontSize": 14
    },
    "item-3": {
      "type": "Rectangle", "parent": "list-panel",
      "left": 30, "top": 130, "width": 380, "height": 40,
      "fillColor": "#2a3040", "strokeColor": "#333340", "corners": [4, 4, 4, 4]
    },
    "item-3-label": {
      "type": "Text", "parent": "item-3",
      "left": 40, "top": 138, "text": "Item Gamma",
      "fontColor": "#c8d0e0", "fontSize": 14
    },
    "detail-panel": {
      "type": "Rectangle",
      "left": 440, "top": 20, "width": 680, "height": 740,
      "fillColor": "#1a1e24", "strokeColor": "#333340", "corners": [4, 4, 4, 4]
    },
    "detail-title": {
      "type": "Text", "parent": "detail-panel",
      "left": 460, "top": 40,
      "text": "Item Alpha",
      "fontColor": "#c8d0e0", "fontSize": 18
    },
    "detail-body": {
      "type": "Text", "parent": "detail-panel",
      "left": 460, "top": 80, "width": 640,
      "text": "Description and properties appear here.",
      "fontColor": "#c8d0e0", "fontSize": 14, "wordWrap": true
    }
  }
}
```

---

## 6. Inventory Grid

Grid of cells for item management.

```json
{
  "name": "Inventory Grid",
  "shapes": {
    "panel": {
      "type": "Rectangle",
      "left": 240, "top": 100, "width": 660, "height": 580,
      "fillColor": "#1a1e24", "strokeColor": "#333340", "corners": [8, 8, 8, 8]
    },
    "title": {
      "type": "Text", "parent": "panel",
      "left": 260, "top": 120,
      "text": "INVENTORY",
      "fontColor": "#c8d0e0", "fontSize": 18
    },
    "cell-1-1": {
      "type": "Rectangle", "parent": "panel",
      "left": 260, "top": 160, "width": 64, "height": 64,
      "fillColor": "#2a3040", "strokeColor": "#333340", "corners": [4, 4, 4, 4]
    },
    "cell-1-2": {
      "type": "Rectangle", "parent": "panel",
      "left": 332, "top": 160, "width": 64, "height": 64,
      "fillColor": "#2a3040", "strokeColor": "#333340", "corners": [4, 4, 4, 4]
    },
    "cell-1-3": {
      "type": "Rectangle", "parent": "panel",
      "left": 404, "top": 160, "width": 64, "height": 64,
      "fillColor": "#2a3040", "strokeColor": "#333340", "corners": [4, 4, 4, 4]
    },
    "cell-1-4": {
      "type": "Rectangle", "parent": "panel",
      "left": 476, "top": 160, "width": 64, "height": 64,
      "fillColor": "#2a3040", "strokeColor": "#333340", "corners": [4, 4, 4, 4]
    },
    "cell-2-1": {
      "type": "Rectangle", "parent": "panel",
      "left": 260, "top": 232, "width": 64, "height": 64,
      "fillColor": "#2a3040", "strokeColor": "#333340", "corners": [4, 4, 4, 4]
    },
    "cell-2-2": {
      "type": "Rectangle", "parent": "panel",
      "left": 332, "top": 232, "width": 64, "height": 64,
      "fillColor": "#2a3040", "strokeColor": "#333340", "corners": [4, 4, 4, 4]
    },
    "cell-2-3": {
      "type": "Rectangle", "parent": "panel",
      "left": 404, "top": 232, "width": 64, "height": 64,
      "fillColor": "#2a3040", "strokeColor": "#333340", "corners": [4, 4, 4, 4]
    },
    "cell-2-4": {
      "type": "Rectangle", "parent": "panel",
      "left": 476, "top": 232, "width": 64, "height": 64,
      "fillColor": "#2a3040", "strokeColor": "#333340", "corners": [4, 4, 4, 4]
    },
    "detail": {
      "type": "Rectangle", "parent": "panel",
      "left": 580, "top": 160, "width": 300, "height": 400,
      "fillColor": "#2a3040", "strokeColor": "#333340", "corners": [4, 4, 4, 4]
    },
    "detail-title": {
      "type": "Text", "parent": "detail",
      "left": 600, "top": 180,
      "text": "Selected Item Name",
      "fontColor": "#c8d0e0", "fontSize": 16
    },
    "detail-body": {
      "type": "Text", "parent": "detail",
      "left": 600, "top": 210, "width": 260,
      "text": "Item description and stats",
      "fontColor": "#c8d0e0", "fontSize": 14, "wordWrap": true
    }
  }
}
```
