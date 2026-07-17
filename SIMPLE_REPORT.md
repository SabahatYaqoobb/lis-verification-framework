# Verification Framework Based on Hoare Logic and Incorrectness Logic

## 1. Introduction

This project implements a small program verifier in OCaml. The tool does not need concrete input values. It uses symbols, such as `x` and `y`, and records conditions that describe their possible values.

The implementation follows the main symbolic-semantics ideas of Soteria. It includes symbolic execution, symbolic memory, Hoare-style verification, API specifications, Z3 constraint solving, and counterexample generation.

## 2. Language

The language supports the commands required by the project:

```text
skip
x := e
c1 ; c2
if b then c1 else c2
while b do c
x := load(e)
store(e1, e2)
x := f(e1, ..., en)
```

Expressions include integers, variables, arithmetic operations, memory reads, and function expressions. Conditions include comparisons such as `=`, `!=`, `<`, `<=`, `>`, and `>=`, together with Boolean operations.

Programs are represented as typed OCaml values. A separate text parser is not included.

## 3. Symbolic State

The executor stores its information in a symbolic state:

```text
State = (Environment, Memory, Path Condition, Path)
```

- The environment maps program variables to symbolic expressions.
- Memory maps integer addresses to symbolic integer values.
- The path condition stores the requirements for reaching the current state.
- The path records branches, loop iterations, and API calls.

For example, after `y := x + 1`, the environment records `y = x + 1`. The value of `x` can remain unknown.

Memory is represented using Z3 arrays. A write creates an SMT `store` expression, while a read creates a `select` expression. This allows Z3 to reason correctly about symbolic addresses and memory aliasing.

## 4. Symbolic Execution

The main executor has the required basic interface:

```ocaml
exec : command -> sym_state -> sym_state list
```

An assignment updates the symbolic environment. A sequence executes its commands in order. A conditional creates a then-path and an else-path. Z3 checks each path, and impossible paths are removed.

For this program:

```text
if x > 0 then y := x else y := -x
```

the executor creates:

```text
Path 1: x > 0,  y = x
Path 2: x <= 0, y = -x
```

Loops use bounded symbolic execution. If the loop can continue after the selected bound, the verifier returns `INCONCLUSIVE` instead of incorrectly reporting success.

## 5. Hoare Verification

A specification has the form:

```text
{P} program {Q}
```

`P` is the precondition and `Q` is the expected postcondition. The verifier starts with symbolic inputs satisfying `P`, executes the program, and checks `Q` in every feasible final state.

For every final state, it asks Z3 whether the following formula is satisfiable:

```text
PathCondition AND NOT Postcondition
```

If this is impossible on every final path, the program is reported as `VERIFIED`. If it is possible, Z3 returns concrete input values that violate the postcondition.

The verifier proves partial correctness. It checks the result of terminating executions but does not prove that every program terminates.

## 6. Bug Finding

The optional incorrectness component is also implemented:

```ocaml
find_bug : assertion -> command -> assertion -> bug_report option
```

It searches for a feasible execution that reaches a bad final state. A bug report contains the failing path, the path condition, the violated postcondition, and the concrete Z3 model.

For example, the absolute-value program does not satisfy `y > 0` when `x = 0`. The tool reports `x = 0` as a counterexample.

## 7. API Specifications

External APIs are checked using specifications instead of implementations. Each specification contains the API name, parameters, precondition, and postcondition.

For example:

```text
safe_div(x, y)
Pre:  y != 0
Post: result = x / y
```

For `z := safe_div(a, b)`, the verifier first checks whether the current path guarantees `b != 0`. If it does not, it searches for a counterexample such as `b = 0`.

On a safe path, the executor creates a fresh symbolic result, adds the API postcondition to the path condition, and assigns the result to `z`. The source code of the API is never required.

## 8. Supplied Examples

The project includes five programs that verify successfully:

1. Absolute value is nonnegative.
2. Incrementing a nonnegative value produces a positive value.
3. A stored memory value can be read correctly.
4. `safe_div` is safe when its divisor is nonzero.
5. A bounded countdown reaches zero.

It also includes five buggy programs:

- Absolute value is incorrectly expected to be strictly positive.
- An impossible result is expected after an increment.
- Unknown memory is incorrectly expected to contain zero.
- `safe_div` is called without proving that the divisor is nonzero.
- A stored value is incorrectly expected to be a different value.

Each buggy example produces a concrete counterexample.

## 9. Main Design Choices

The environment and memory are immutable. Therefore, different symbolic branches cannot accidentally change one another.

The framework writes SMT-LIB formulas and starts Z3 as a separate process. This avoids depending on a platform-specific OCaml binding while keeping support for models and symbolic arrays.

Paths are checked early. When a path condition is impossible, the executor removes that path immediately. This reduces unnecessary work.

Memory uses Z3 arrays because they provide a simple and correct model for symbolic `load` and `store` operations.

Bounded loop results are handled carefully. If unexplored iterations are still possible, the result is `INCONCLUSIVE`, not `VERIFIED`.

## 10. Limitations

- Loops are explored only up to a fixed bound.
- The AST contains an optional invariant field, but invariant-based proofs are not implemented.
- Program termination is not proved.
- Arithmetic uses mathematical integers and does not model machine overflow.
- Direct division does not automatically generate a division-by-zero check.
- API contracts cannot currently describe changes to memory.
- API predicates are uninterpreted unless assumptions are explicitly provided.
- Programs are OCaml AST values; there is no textual parser.
- Programs with many branches may create a large number of symbolic paths.
- Bug reports do not contain exact source-code line numbers.

## 11. Conclusion

The project provides a working OCaml verification framework based on symbolic execution. It covers the required language, memory operations, API contracts, Hoare-style verification, and Z3 feasibility checking. It also implements the optional incorrectness engine and provides five successful and five buggy example programs.

The main limitation is bounded loop execution. Future work could add inductive loop invariants, a text parser, stateful API contracts, source locations, and machine-integer semantics.
