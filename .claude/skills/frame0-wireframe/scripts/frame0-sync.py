#!/usr/bin/env python3
"""Frame0 sync: push local JSON wireframes to Frame0, pull pages back.

Local JSON is source of truth. Frame0 is a renderer.
A mapping file tracks local_id <-> frame0_id across push/pull cycles.

Usage:
    frame0-sync.py push <wireframe.json> [--port PORT]
    frame0-sync.py pull <page-id|page-name> <output.json> [--port PORT]
    frame0-sync.py export <wireframe.json> <output.png> [--port PORT] [--format MIME]
"""

import argparse
import json
import os
import sys
import urllib.request
import urllib.error

DEFAULT_PORT = 58320


def api(port, command, args=None):
    """Execute a Frame0 API command. Returns the data field on success."""
    url = f"http://localhost:{port}/execute_command"
    payload = json.dumps({"command": command, "args": args or {}}).encode()
    req = urllib.request.Request(url, data=payload, headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req) as resp:
            result = json.loads(resp.read())
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        print(f"ERROR: {command}: HTTP {e.code}: {body[:500]}", file=sys.stderr)
        sys.exit(1)
    except urllib.error.URLError as e:
        print(f"ERROR: Cannot connect to Frame0 on port {port}: {e}", file=sys.stderr)
        sys.exit(1)

    if not result.get("success"):
        print(f"ERROR: {command}: {result.get('error', 'unknown')}", file=sys.stderr)
        sys.exit(1)

    return result.get("data")


# -- Mapping file management --------------------------------------------------

def mapping_path(wireframe_path):
    """Derive the idmap path from the wireframe JSON path."""
    d = os.path.dirname(wireframe_path)
    base = os.path.splitext(os.path.basename(wireframe_path))[0]
    return os.path.join(d, f".{base}.idmap.json")


def load_mapping(wireframe_path):
    p = mapping_path(wireframe_path)
    if os.path.exists(p):
        with open(p) as f:
            return json.load(f)
    return {"page_id": None, "shapes": {}, "connectors": {}}


def save_mapping(wireframe_path, mapping):
    p = mapping_path(wireframe_path)
    os.makedirs(os.path.dirname(p) or ".", exist_ok=True)
    with open(p, "w") as f:
        json.dump(mapping, f, indent=2)
        f.write("\n")


# -- Push: local JSON -> Frame0 -----------------------------------------------

# Frame0 returns different type names from get vs what create accepts.
# Map internal types back to create-API types.
TYPE_TO_CREATE = {
    "Box": "Rectangle",
    "box": "Rectangle",
}


def topo_sort_shapes(shapes):
    """Sort shape IDs so parents come before children."""
    order = []
    visited = set()

    def visit(sid):
        if sid in visited:
            return
        visited.add(sid)
        shape = shapes[sid]
        parent = shape.get("parent")
        if parent and parent in shapes:
            visit(parent)
        order.append(sid)

    for sid in shapes:
        visit(sid)
    return order


def find_or_create_page(port, name, mapping):
    """Find existing page by mapping or name, or create a new one."""
    # Try mapped page_id first
    if mapping.get("page_id"):
        try:
            page = api(port, "page:get", {"pageId": mapping["page_id"]})
            if page:
                return mapping["page_id"]
        except SystemExit:
            pass  # Page no longer exists, fall through

    # Search by name in existing pages
    doc = api(port, "doc:get", {"exportPages": True, "exportShapes": False})
    if doc and "children" in doc:
        for page in doc["children"]:
            if page.get("name") == name:
                return page["id"]

    # Create new page
    page = api(port, "page:add", {"pageProps": {"name": name}})
    return page["id"]


def clear_page(port, page_id):
    """Delete all shapes on a page."""
    page = api(port, "page:get", {"pageId": page_id, "exportShapes": True})
    if not page or "children" not in page:
        return
    shape_ids = [s["id"] for s in page["children"]]
    if shape_ids:
        api(port, "edit:delete", {"shapeIdArray": shape_ids})


def push(wireframe_path, port):
    """Push local wireframe JSON to Frame0."""
    with open(wireframe_path) as f:
        wireframe = json.load(f)

    name = wireframe.get("name", os.path.splitext(os.path.basename(wireframe_path))[0])
    shapes = wireframe.get("shapes", {})
    connectors = wireframe.get("connectors", {})

    mapping = load_mapping(wireframe_path)

    # Find or create page
    page_id = find_or_create_page(port, name, mapping)
    mapping["page_id"] = page_id

    # Switch to page and clear it
    api(port, "page:set-current-page", {"pageId": page_id})
    clear_page(port, page_id)

    # Reset ID mappings (shapes are recreated)
    mapping["shapes"] = {}
    mapping["connectors"] = {}

    # Create shapes in dependency order
    order = topo_sort_shapes(shapes)
    for local_id in order:
        shape = shapes[local_id]
        raw_type = shape.get("type", "Rectangle")
        shape_type = TYPE_TO_CREATE.get(raw_type, raw_type)
        parent_local = shape.get("parent")

        # Build shapeProps from everything except meta fields
        meta_keys = {"type", "parent"}
        props = {k: v for k, v in shape.items() if k not in meta_keys}

        # Set name to local_id if not explicitly set
        if "name" not in props:
            props["name"] = local_id

        create_args = {
            "type": shape_type,
            "shapeProps": props,
            "convertColors": True,
        }

        # Resolve parent ID
        if parent_local and parent_local in mapping["shapes"]:
            create_args["parentId"] = mapping["shapes"][parent_local]

        f0_id = api(port, "shape:create-shape", create_args)
        mapping["shapes"][local_id] = f0_id

    # Create connectors
    for local_id, conn in connectors.items():
        tail_local = conn.get("tailId")
        head_local = conn.get("headId")

        if tail_local not in mapping["shapes"] or head_local not in mapping["shapes"]:
            print(f"WARNING: connector '{local_id}' references unknown shape, skipping", file=sys.stderr)
            continue

        meta_keys = {"tailId", "headId"}
        props = {k: v for k, v in conn.items() if k not in meta_keys}
        if "name" not in props:
            props["name"] = local_id

        f0_id = api(port, "shape:create-connector", {
            "tailId": mapping["shapes"][tail_local],
            "headId": mapping["shapes"][head_local],
            "shapeProps": props,
            "convertColors": True,
        })
        mapping["connectors"][local_id] = f0_id

    # Fit to screen
    api(port, "view:fit-to-screen")

    save_mapping(wireframe_path, mapping)
    total = len(mapping["shapes"]) + len(mapping["connectors"])
    print(f"Pushed '{name}' to Frame0: {len(mapping['shapes'])} shapes, {len(mapping['connectors'])} connectors")


# -- Pull: Frame0 -> local JSON -----------------------------------------------

def pull(page_ref, output_path, port):
    """Pull a Frame0 page into local wireframe JSON."""
    # Resolve page_ref: could be an ID or a name
    page_id = None
    doc = api(port, "doc:get", {"exportPages": True, "exportShapes": False})
    if doc and "children" in doc:
        for page in doc["children"]:
            if page["id"] == page_ref or page.get("name") == page_ref:
                page_id = page["id"]
                page_name = page.get("name", page_ref)
                break

    if not page_id:
        print(f"ERROR: Page not found: {page_ref}", file=sys.stderr)
        sys.exit(1)

    # Load existing mapping for reverse lookup
    mapping = load_mapping(output_path)
    reverse_map = {v: k for k, v in mapping.get("shapes", {}).items()}
    reverse_conn = {v: k for k, v in mapping.get("connectors", {}).items()}

    # Get full page with shapes
    page = api(port, "page:get", {"pageId": page_id, "exportShapes": True})

    shapes = {}
    connectors = {}
    new_mapping = {"page_id": page_id, "shapes": {}, "connectors": {}}
    auto_id_counter = [0]

    def auto_id(f0_shape):
        """Generate a stable local ID from shape name or auto-number."""
        # Prefer existing mapping
        f0_id = f0_shape["id"]
        if f0_id in reverse_map:
            return reverse_map[f0_id]
        # Use sanitized name
        name = f0_shape.get("name", "")
        if name:
            sanitized = name.lower().replace(" ", "-").replace("_", "-")
            if sanitized not in shapes:
                return sanitized
        # Fallback: auto-number
        auto_id_counter[0] += 1
        return f"s{auto_id_counter[0]:03d}"

    def process_shape(f0_shape, parent_local_id=None):
        f0_id = f0_shape["id"]
        local_id = auto_id(f0_shape)
        new_mapping["shapes"][local_id] = f0_id

        # Extract shape properties — only strip structural keys that our
        # ID mapping replaces. Everything else passes through as-is so the
        # local JSON speaks Frame0's native vocabulary.
        shape_type = f0_shape.get("type", "Box")
        skip_keys = {"id", "type", "children", "pageId", "parentId"}
        props = {k: v for k, v in f0_shape.items() if k not in skip_keys and v is not None}

        entry = {"type": shape_type}
        if parent_local_id:
            entry["parent"] = parent_local_id
        entry.update(props)

        # Remove name if it matches local_id (redundant)
        if entry.get("name") == local_id:
            del entry["name"]

        shapes[local_id] = entry

        # Process children recursively
        for child in f0_shape.get("children", []):
            child_type = child.get("type", "")
            if child_type == "Connector":
                process_connector(child)
            else:
                process_shape(child, local_id)

    def process_connector(f0_conn):
        f0_id = f0_conn["id"]
        local_id = reverse_conn.get(f0_id)
        if not local_id:
            auto_id_counter[0] += 1
            local_id = f"c{auto_id_counter[0]:03d}"

        new_mapping["connectors"][local_id] = f0_id

        tail_f0 = f0_conn.get("tail", {}).get("id")
        head_f0 = f0_conn.get("head", {}).get("id")

        entry = {}
        if tail_f0:
            # Will be resolved after all shapes are processed
            entry["_tailF0"] = tail_f0
        if head_f0:
            entry["_headF0"] = head_f0

        skip_keys = {"id", "type", "children", "pageId", "tail", "head"}
        props = {k: v for k, v in f0_conn.items() if k not in skip_keys and v is not None}
        entry.update(props)

        connectors[local_id] = entry

    # Process all top-level shapes
    for child in page.get("children", []):
        child_type = child.get("type", "")
        if child_type == "Connector":
            process_connector(child)
        else:
            process_shape(child)

    # Resolve connector references to local IDs
    f0_to_local = {v: k for k, v in new_mapping["shapes"].items()}
    for conn in connectors.values():
        tail_f0 = conn.pop("_tailF0", None)
        head_f0 = conn.pop("_headF0", None)
        if tail_f0 and tail_f0 in f0_to_local:
            conn["tailId"] = f0_to_local[tail_f0]
        if head_f0 and head_f0 in f0_to_local:
            conn["headId"] = f0_to_local[head_f0]

    wireframe = {"name": page_name}
    if shapes:
        wireframe["shapes"] = shapes
    if connectors:
        wireframe["connectors"] = connectors

    os.makedirs(os.path.dirname(output_path) or ".", exist_ok=True)
    with open(output_path, "w") as f:
        json.dump(wireframe, f, indent=2)
        f.write("\n")

    save_mapping(output_path, new_mapping)
    print(f"Pulled '{page_name}' -> {output_path}: {len(shapes)} shapes, {len(connectors)} connectors")


# -- Export: push then export as image -----------------------------------------

def export_image(wireframe_path, output_path, port, fmt="image/png"):
    """Push wireframe to Frame0 and export the page as an image."""
    import base64

    # Push first to ensure Frame0 is up to date
    push(wireframe_path, port)

    mapping = load_mapping(wireframe_path)
    page_id = mapping.get("page_id")
    if not page_id:
        print("ERROR: No page_id in mapping after push", file=sys.stderr)
        sys.exit(1)

    image_b64 = api(port, "file:export-image", {
        "pageId": page_id,
        "format": fmt,
        "fillBackground": True,
    })

    image_bytes = base64.b64decode(image_b64)
    with open(output_path, "wb") as f:
        f.write(image_bytes)

    print(f"Exported: {output_path} ({len(image_bytes) // 1024}KB)")


# -- CLI -----------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Sync wireframe JSON with Frame0")
    parser.add_argument("--port", type=int, default=int(os.environ.get("FRAME0_PORT", DEFAULT_PORT)))
    sub = parser.add_subparsers(dest="command")

    p_push = sub.add_parser("push", help="Push local JSON to Frame0")
    p_push.add_argument("wireframe", help="Path to wireframe .json file")

    p_pull = sub.add_parser("pull", help="Pull Frame0 page to local JSON")
    p_pull.add_argument("page", help="Page ID or page name")
    p_pull.add_argument("output", help="Output .json path")

    p_export = sub.add_parser("export", help="Push and export as image")
    p_export.add_argument("wireframe", help="Path to wireframe .json file")
    p_export.add_argument("output", help="Output image path (e.g. wireframe.png)")
    p_export.add_argument("--format", default="image/png",
                         help="Export MIME type (default: image/png)")

    args = parser.parse_args()

    if args.command == "push":
        push(args.wireframe, args.port)
    elif args.command == "pull":
        pull(args.page, args.output, args.port)
    elif args.command == "export":
        export_image(args.wireframe, args.output, args.port, args.format)
    else:
        parser.print_help()
        sys.exit(1)


if __name__ == "__main__":
    main()
