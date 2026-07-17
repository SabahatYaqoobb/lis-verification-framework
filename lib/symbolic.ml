open Syntax

type sym_mem = MVar of string | MStore of sym_mem * sym_expr * sym_expr
and sym_expr =
  | SInt of int
  | SVar of string
  | SBinop of binop * sym_expr * sym_expr
  | SNeg of sym_expr
  | SSelect of sym_mem * sym_expr
  | SFun of string * sym_expr list

type sym_assertion =
  | STrue
  | SFalse
  | SCmp of cmp * sym_expr * sym_expr
  | SAnd of sym_assertion list
  | SOr of sym_assertion list
  | SNot of sym_assertion
  | SImplies of sym_assertion * sym_assertion
  | SPred of string * sym_expr list

module StringMap = Map.Make (String)

type path_step = Branch of string | Loop_iteration of int | Api_call of string

type state = {
  env : sym_expr StringMap.t;
  mem : sym_mem;
  pc : sym_assertion list;
  path : path_step list;
  fresh : int;
}

let initial = { env = StringMap.empty; mem = MVar "mem0"; pc = []; path = []; fresh = 0 }

let lookup env x = match StringMap.find_opt x env with Some v -> v | None -> SVar x

let rec eval_expr st = function
  | Int n -> SInt n
  | Var x -> lookup st.env x
  | Binop (op, a, b) -> SBinop (op, eval_expr st a, eval_expr st b)
  | Neg e -> SNeg (eval_expr st e)
  | Load a -> SSelect (st.mem, eval_expr st a)
  | Fun (f, xs) -> SFun (f, List.map (eval_expr st) xs)

let rec eval_assertion st = function
  | True -> STrue | False -> SFalse
  | Cmp (c, a, b) -> SCmp (c, eval_expr st a, eval_expr st b)
  | And xs -> SAnd (List.map (eval_assertion st) xs)
  | Or xs -> SOr (List.map (eval_assertion st) xs)
  | Not a -> SNot (eval_assertion st a)
  | Implies (a, b) -> SImplies (eval_assertion st a, eval_assertion st b)
  | Pred (p, xs) -> SPred (p, List.map (eval_expr st) xs)

let fresh prefix st =
  let n = st.fresh + 1 in
  (SVar (Printf.sprintf "__%s_%d" prefix n), { st with fresh = n })

let conjunction st = SAnd st.pc

