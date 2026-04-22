// Tree-sitter WASM bridge — compiled per grammar into a self-contained
// WASM module.  Exports: init, set_query, parse_and_highlight,
// capture_count, capture_name, ts_alloc, ts_dealloc.

#include "tree_sitter/api.h"
#include <stdlib.h>
#include <stdint.h>

// Linked at compile time via -DGRAMMAR_FN=tree_sitter_<lang>.
extern const TSLanguage *GRAMMAR_FN(void);

static TSParser      *g_parser = NULL;
static TSQuery       *g_query  = NULL;
static TSQueryCursor *g_cursor = NULL;

// 12-byte packed span: start_byte, end_byte, capture_index.
typedef struct { uint32_t start; uint32_t end; uint32_t capture; } Span;

__attribute__((export_name("init")))
int32_t init(void) {
    g_parser = ts_parser_new();
    if (!g_parser) return -1;
    if (!ts_parser_set_language(g_parser, GRAMMAR_FN())) return -2;
    g_cursor = ts_query_cursor_new();
    if (!g_cursor) return -3;
    return 0;
}

// Returns 0 on success, or (error_offset + 1) on failure.
__attribute__((export_name("set_query")))
int32_t set_query(const char *src, uint32_t len) {
    if (g_query) { ts_query_delete(g_query); g_query = NULL; }
    uint32_t error_offset;
    TSQueryError error_type;
    g_query = ts_query_new(GRAMMAR_FN(), src, len, &error_offset, &error_type);
    return g_query ? 0 : (int32_t)(error_offset + 1);
}

// Parse source and run the active query.  Writes Span structs into |out|.
// Returns the number of spans written.
__attribute__((export_name("parse_and_highlight")))
uint32_t parse_and_highlight(
    const char *src, uint32_t src_len,
    Span *out, uint32_t max_spans
) {
    if (!g_parser || !g_query || !g_cursor) return 0;

    TSTree *tree = ts_parser_parse_string(g_parser, NULL, src, src_len);
    if (!tree) return 0;

    TSNode root = ts_tree_root_node(tree);
    ts_query_cursor_exec(g_cursor, g_query, root);

    TSQueryMatch match;
    uint32_t count = 0;
    while (ts_query_cursor_next_match(g_cursor, &match) && count < max_spans) {
        for (uint16_t i = 0; i < match.capture_count && count < max_spans; i++) {
            TSQueryCapture cap = match.captures[i];
            out[count].start   = ts_node_start_byte(cap.node);
            out[count].end     = ts_node_end_byte(cap.node);
            out[count].capture = cap.index;
            count++;
        }
    }

    ts_tree_delete(tree);
    return count;
}

__attribute__((export_name("capture_count")))
uint32_t capture_count(void) {
    return g_query ? ts_query_capture_count(g_query) : 0;
}

// Returns a pointer into WASM linear memory.  Caller reads |*out_len|
// bytes starting at the returned address.
__attribute__((export_name("capture_name")))
const char *capture_name(uint32_t index, uint32_t *out_len) {
    if (!g_query) { *out_len = 0; return NULL; }
    return ts_query_capture_name_for_id(g_query, index, out_len);
}

__attribute__((export_name("ts_alloc")))
void *ts_alloc(uint32_t size) { return malloc(size); }

__attribute__((export_name("ts_dealloc")))
void ts_dealloc(void *ptr) { free(ptr); }
