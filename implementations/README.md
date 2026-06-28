# PACT v0.2 — Semantic-nominal Everything-as-Code Ports

This directory contains semantic-nominal ports of `Pact_reference_v02.py` for Zig, Go, Rust, TypeScript, and Gleam.

The ports preserve the reference architecture as a declarative vocabulary:

1. Atomic behaviors such as `validateTypeIsInteger`, `compareLeftValueIsLessThanOrEqualToRightValue`, and `resolveFieldPathFromSemanticContext` are declared once.
2. Composition behaviors such as `composeAllValidationsMustPass` and `evaluatePolicyRuleAgainstSemanticContext` reuse those atoms instead of duplicating operators.
3. Business values are intentionally externalized to `../config.yml`, which is the single source of truth for validation ranges, mandate metadata, PDPP checks, and transaction scenarios.

The source files are designed as language-native building blocks for host applications that load `config.yml`, map the configuration into the nominal types, and then execute the semantic functions.
