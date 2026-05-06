# D2 Language Quick Reference

## Nodes

```d2
server                              # Implicit label from key
server: Simulation Server           # Explicit label
server: Simulation Server {         # With properties
  shape: hexagon
  style.fill: "#2d3436"
}
```

## Edges

```d2
a -> b                              # Directed
a <- b                              # Reverse directed
a <-> b                             # Bidirectional
a -- b                              # Undirected
a -> b: "label"                     # Labeled edge
a -> b -> c                         # Chained
```

## Containers (nesting)

```d2
infrastructure: {
  server: Simulation Server
  database: State Store {
    shape: cylinder
  }
}
```

## Shapes

| Shape | Use for |
|-------|---------|
| `rectangle` | Default. Components, modules, generic. |
| `hexagon` | Systems, services, major components. |
| `cylinder` | Databases, storage, persistent state. |
| `diamond` | Decisions, conditions, branch points. |
| `oval` / `circle` | Start/end states, events. |
| `cloud` | External systems, networks. |
| `person` | Actors, users, NPCs. |
| `queue` | Message queues, buffers. |
| `page` | Documents, files. |
| `package` | Packages, modules, crates. |
| `sql_table` | Database tables, ECS component schemas. |
| `class` | Class diagrams, ECS system definitions. |
| `code` | Code blocks (set `language` property). |
| `markdown` | Rich text blocks. |

## SQL Tables

```d2
entity: {
  shape: sql_table
  id: u64 {constraint: primary_key}
  name: String
  position: Vec2
  faction_id: u64 {constraint: foreign_key}
}
```

## Class Diagrams

```d2
perception_system: {
  shape: class
  +run(world: &mut World)
  -calculate_los(entity: Entity): HashSet<Entity>
  #update_knowledge(entity: Entity, seen: HashSet<Entity>)
}
```

## Sequence Diagrams

```d2
shape: sequence_diagram
client: Godot Client
server: Rust Server

client -> server: TickRequest(delta)
server -> server: run ECS systems
server -> client: WorldState(entities)
```

## Styling

```d2
node: Label {
  style: {
    fill: "#2d3436"
    stroke: "#333340"
    stroke-width: 2
    stroke-dash: 5              # Dashed line
    opacity: 0.8
    font-size: 14
    font-color: "#c8d0e0"
    bold: true
    italic: false
    border-radius: 4
    shadow: true
    3d: true                    # Rectangles only
    multiple: true              # Stacked appearance
    double-border: true         # Rectangles/ovals only
  }
}
```

### Edge styling

```d2
a -> b: {
  style: {
    stroke: "#c8d8f0"
    stroke-width: 2
    stroke-dash: 5
    opacity: 0.8
    animated: true              # Animated flow
  }
}
```

## Variables

```d2
vars: {
  color-bg: "#1a1e24"
  color-stroke: "#333340"
  color-text: "#c8d0e0"
  color-accent: "#c8d8f0"
}

node: {
  style.fill: ${color-bg}
  style.stroke: ${color-stroke}
  style.font-color: ${color-text}
}
```

## Direction

```d2
direction: right                    # left-to-right (default for dagre)
direction: down                     # top-to-bottom
direction: up
direction: left
```

## Imports

```d2
...@shared-defs.d2                  # Spread import (inline all definitions)
```

## Icons

```d2
node: Label {
  icon: https://icons.terrastruct.com/essentials/time.svg
}
```

## Layers (multi-board)

```d2
# Base diagram content here

layers: {
  detailed: {
    # More detailed view
  }
  simplified: {
    # Simplified overview
  }
}
```

## Scenarios (animated transitions)

```d2
# Base state

scenarios: {
  alert: {
    # Changes from base for alert state
  }
  combat: {
    # Changes from base for combat state
  }
}
```

## Comments

```d2
# This is a comment
node: Label  # Inline comment
```

## Project Colors (from visual-grammar-v01.md)

| Constant | Hex | Usage |
|----------|-----|-------|
| Zone 1 floor | `#1a1e24` | Dark backgrounds |
| Zone 1 wall | `#2a3040` | Component fill |
| Outline standard | `#333340` | Borders, strokes |
| Insert chrome | `#c8d0e0` | Text, labels |
| Zone 1 fixture | `#c8d8f0` | Accents, highlights |
