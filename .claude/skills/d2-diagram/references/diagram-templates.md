# Diagram Templates

Copy, adapt, and render. Each template uses project colors from visual-grammar-v01.md.

---

## 1. Architecture Diagram

System components, relationships, communication channels.

**When to use:** IPC bridge, perception pipeline, chunk loading, ECS system layout, client-server architecture.

**Agents:** Tyre (system architecture), Qatux (architecture decision records).

```d2
vars: {
  color-bg: "#2a3040"
  color-stroke: "#333340"
  color-text: "#c8d0e0"
  color-accent: "#c8d8f0"
}

direction: right

client: Godot Client {
  shape: hexagon
  style.fill: ${color-bg}
  style.font-color: ${color-text}

  rendering: Rendering {
    style.fill: ${color-bg}
    style.font-color: ${color-text}
  }
  ui: UI Layer {
    style.fill: ${color-bg}
    style.font-color: ${color-text}
  }
  bridge: IPC Bridge {
    style.fill: ${color-bg}
    style.font-color: ${color-text}
    style.stroke: ${color-accent}
  }
}

server: Rust Server {
  shape: hexagon
  style.fill: ${color-bg}
  style.font-color: ${color-text}

  ecs: bevy_ecs {
    style.fill: ${color-bg}
    style.font-color: ${color-text}
  }
  perception: Perception {
    style.fill: ${color-bg}
    style.font-color: ${color-text}
  }
  bridge: IPC Bridge {
    style.fill: ${color-bg}
    style.font-color: ${color-text}
    style.stroke: ${color-accent}
  }
}

client.bridge -> server.bridge: "stdin/stdout" {
  style.stroke: ${color-accent}
  style.stroke-dash: 5
}
```

---

## 2. Entity Relationship

Data schemas, ECS components, knowledge graph structure.

**When to use:** Database tables, component definitions, entity relationships, knowledge store schema.

**Agents:** Tyre (ECS component design), Qatux (schema documentation).

```d2
entity: Entity {
  shape: sql_table
  id: u64 {constraint: primary_key}
  name: String
  faction_id: u64 {constraint: foreign_key}
}

position: Position {
  shape: sql_table
  entity_id: u64 {constraint: foreign_key}
  x: f32
  y: f32
  chunk_id: u32
}

knowledge: KnowledgeEntry {
  shape: sql_table
  observer_id: u64 {constraint: foreign_key}
  subject_id: u64 {constraint: foreign_key}
  fact_type: FactType
  confidence: f32
  last_seen_tick: u64
}

entity.id -> position.entity_id
entity.id -> knowledge.observer_id
entity.id -> knowledge.subject_id
```

---

## 3. Sequence / Data Flow

Ordered interactions between systems over time.

**When to use:** IPC message flow, tick processing, perception update cycle, dialogue system exchanges.

**Agents:** Tyre (system interaction design), Qatux (protocol documentation).

```d2
shape: sequence_diagram

client: Godot Client
bridge: IPC Bridge
server: Rust Server
ecs: ECS Systems

client -> bridge: TickRequest(delta, input)
bridge -> server: deserialize + dispatch
server -> ecs: run_systems(delta)
ecs -> ecs: perception, AI, physics
ecs -> server: collect WorldState
server -> bridge: serialize WorldState
bridge -> client: WorldState(entities, events)
client -> client: update rendering
```

---

## 4. State Machine

Entity states, transitions, conditions.

**When to use:** NPC behavior states, game mode transitions, dialogue state, investigation phases.

**Agents:** Tyre (behavior system design), Qatux (state documentation).

```d2
vars: {
  color-state: "#2a3040"
  color-text: "#c8d0e0"
  color-edge: "#c8d8f0"
  color-decision: "#333340"
}

idle: Idle {
  style.fill: ${color-state}
  style.font-color: ${color-text}
}

alert: Alert {
  style.fill: ${color-state}
  style.font-color: ${color-text}
}

investigate: Investigate {
  style.fill: ${color-state}
  style.font-color: ${color-text}
}

combat: Combat {
  style.fill: ${color-state}
  style.font-color: ${color-text}
  style.stroke: "#f0b840"
}

flee: Flee {
  style.fill: ${color-state}
  style.font-color: ${color-text}
}

idle -> alert: "stimulus detected" { style.stroke: ${color-edge} }
alert -> investigate: "stimulus confirmed" { style.stroke: ${color-edge} }
alert -> idle: "timeout / stimulus lost" { style.stroke: ${color-edge}; style.stroke-dash: 5 }
investigate -> combat: "threat confirmed" { style.stroke: "#f0b840" }
investigate -> idle: "nothing found" { style.stroke: ${color-edge}; style.stroke-dash: 5 }
combat -> flee: "health < threshold" { style.stroke: "#f0b840" }
combat -> idle: "threat eliminated" { style.stroke: ${color-edge}; style.stroke-dash: 5 }
flee -> idle: "safe distance reached" { style.stroke: ${color-edge}; style.stroke-dash: 5 }
```

---

## 5. UI Flow

Screen navigation, component hierarchy, interaction paths.

**When to use:** HUD layout relationships, menu navigation, dialogue flow, insert mode transitions.

**Agents:** Araminta (UI/visual design), Tyre (interface architecture), Qatux (UI documentation).

```d2
vars: {
  color-screen: "#1a1e24"
  color-panel: "#2a3040"
  color-text: "#c8d0e0"
  color-nav: "#c8d8f0"
}

gameplay: Gameplay {
  style.fill: ${color-screen}
  style.font-color: ${color-text}

  hud: HUD {
    style.fill: ${color-panel}
    style.font-color: ${color-text}

    minimap: Minimap
    monologue: Monologue Panel
    insert_display: Insert Display
  }

  world: World View {
    style.fill: ${color-panel}
    style.font-color: ${color-text}
  }
}

pause: Pause Menu {
  style.fill: ${color-screen}
  style.font-color: ${color-text}

  inventory: Inventory
  journal: Journal
  settings: Settings
}

dialogue: Dialogue Mode {
  style.fill: ${color-screen}
  style.font-color: ${color-text}

  speaker: Speaker Panel
  responses: Response List
}

gameplay -> pause: "ESC" { style.stroke: ${color-nav} }
pause -> gameplay: "ESC / Resume" { style.stroke: ${color-nav}; style.stroke-dash: 5 }
gameplay -> dialogue: "interact with NPC" { style.stroke: ${color-nav} }
dialogue -> gameplay: "end conversation" { style.stroke: ${color-nav}; style.stroke-dash: 5 }
```
