(** Source language and specifications. Expressions are integer-valued; assertions
    are Boolean formulae over expressions. *)
type binop = Add | Sub | Mul | Div | Mod
type cmp = Eq | Ne | Lt | Le | Gt | Ge

type expr =
  | Int of int
  | Var of string
  | Binop of binop * expr * expr
  | Neg of expr
  | Load of expr
  | Fun of string * expr list

type assertion =
  | True
  | False
  | Cmp of cmp * expr * expr
  | And of assertion list
  | Or of assertion list
  | Not of assertion
  | Implies of assertion * assertion
  | Pred of string * expr list

type command =
  | Skip
  | Assign of string * expr
  | Seq of command list
  | If of assertion * command * command
  | While of { guard : assertion; body : command; invariant : assertion option }
  | Store of expr * expr
  | Call of string * string * expr list

type api_spec = {
  name : string;
  params : string list;
  pre : assertion;
  post : assertion; (** [result] denotes the returned value. *)
}

type program = { body : command; apis : api_spec list; loop_bound : int }
type hoare_triple = { pre : assertion; program : program; post : assertion }

let ( +: ) a b = Binop (Add, a, b)
let ( -: ) a b = Binop (Sub, a, b)
let ( *: ) a b = Binop (Mul, a, b)
let ( =: ) a b = Cmp (Eq, a, b)
let ( <>: ) a b = Cmp (Ne, a, b)
let ( <: ) a b = Cmp (Lt, a, b)
let ( <=: ) a b = Cmp (Le, a, b)
let ( >: ) a b = Cmp (Gt, a, b)
let ( >=: ) a b = Cmp (Ge, a, b)

