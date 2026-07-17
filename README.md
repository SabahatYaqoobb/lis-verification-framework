# Soteria: symbolic verification for a small imperative language

This repository is a complete OCaml implementation of the LIS 2025-26 individual
project. It provides symbolic execution, Hoare-style partial-correctness checking,
API-contract checking, symbolic arrays for memory, and incorrectness-based
counterexample generation through Z3.

## Prerequisites and commands

- OCaml 5.x and Dune 3.x
- Z3 available as `z3`

```sh
dune build
dune runtest
dune exec examples/showcase.exe
```

The showcase contains five programs expected to verify and five expected to fail
with a concrete counterexample. The complete formal account and design rationale
are in [REPORT.md](REPORT.md).

## Repository map

- `lib/syntax.ml`: source AST, assertions, API specifications, and Hoare triples
- `lib/symbolic.ml`: symbolic expressions, functional memory, states, and paths
- `lib/solver.ml`: SMT-LIB generation and Z3 integration
- `lib/executor.ml`: path-sensitive symbolic operational semantics
- `lib/verifier.ml`: Hoare verification and incorrectness witnesses
- `examples/programs.ml`: five successful and five buggy programs
- `examples/showcase.ml`: runnable demonstration
- `test/test_suite.ml`: automated regression tests

## Public entry points

`Executor.exec : command -> state -> state list`, `Verifier.verify : assertion ->
command -> assertion -> verification_result`, and `Verifier.find_bug : assertion ->
command -> assertion -> bug_report option` provide the signatures requested in the
brief. Their richer `exec_program`, `verify_program`, and `find_bug_program` variants
also accept API pools and a configurable loop bound, and preserve explicit safety or
incompleteness issues.

The project AST is the input format: examples are ordinary OCaml values, which keeps
the implementation focused on semantics rather than an unrelated parser. The formal
concrete syntax in the report can be used as the basis for adding a textual frontend.
