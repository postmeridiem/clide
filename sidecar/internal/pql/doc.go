// Package pql is the *only* place Clide contains pql logic. Pure
// shell-outs to the `pql` binary — no re-implementation of pql's
// indexer, ranker, or frontmatter parsing.
//
// See docs/ADRs/0003-pql-as-supporter-tool.md for the wrap-don't-
// duplicate rule and the "pql is a Clide subsystem when present"
// invariant.
//
// Empty for now — lands in Tier 4.
package pql
