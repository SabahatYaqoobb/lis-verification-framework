open Syntax
open Symbolic

module SS = Set.Make (String)
module FM = Map.Make (String)

type result = Sat of string | Unsat | Unknown of string

type symbols = { ints : SS.t; mems : SS.t; funs : int FM.t; preds : int FM.t }
let empty = { ints = SS.empty; mems = SS.empty; funs = FM.empty; preds = FM.empty }

let add_arity name arity map =
  match FM.find_opt name map with
  | None -> FM.add name arity map
  | Some n when n = arity -> map
  | Some _ -> invalid_arg ("symbol used with inconsistent arity: " ^ name)

let rec collect_mem s = function
  | MVar x -> { s with mems = SS.add x s.mems }
  | MStore (m,a,v) -> collect_expr (collect_expr (collect_mem s m) a) v
and collect_expr s = function
  | SInt _ -> s
  | SVar x -> { s with ints = SS.add x s.ints }
  | SNeg a -> collect_expr s a
  | SBinop (_,a,b) -> collect_expr (collect_expr s a) b
  | SSelect (m,a) -> collect_expr (collect_mem s m) a
  | SFun (f,xs) -> List.fold_left collect_expr { s with funs = add_arity f (List.length xs) s.funs } xs

let rec collect_assertion s = function
  | STrue | SFalse -> s
  | SCmp (_,a,b) -> collect_expr (collect_expr s a) b
  | SAnd xs | SOr xs -> List.fold_left collect_assertion s xs
  | SNot a -> collect_assertion s a
  | SImplies (a,b) -> collect_assertion (collect_assertion s a) b
  | SPred (p,xs) -> List.fold_left collect_expr { s with preds = add_arity p (List.length xs) s.preds } xs

let smt_binop = function Add -> "+" | Sub -> "-" | Mul -> "*" | Div -> "div" | Mod -> "mod"
let smt_cmp = function Eq -> "=" | Ne -> "distinct" | Lt -> "<" | Le -> "<=" | Gt -> ">" | Ge -> ">="
let atom x = "|" ^ String.concat "_" (String.split_on_char '|' x) ^ "|"
let int n = if n < 0 then Printf.sprintf "(- %d)" (-n) else string_of_int n

let rec expr = function
  | SInt n -> int n | SVar x -> atom x
  | SNeg a -> "(- " ^ expr a ^ ")"
  | SBinop (op,a,b) -> Printf.sprintf "(%s %s %s)" (smt_binop op) (expr a) (expr b)
  | SSelect (m,a) -> Printf.sprintf "(select %s %s)" (mem m) (expr a)
  | SFun (f,xs) -> Printf.sprintf "(%s%s)" (atom f)
      (if xs=[] then "" else " " ^ String.concat " " (List.map expr xs))
and mem = function
  | MVar x -> atom x
  | MStore (m,a,v) -> Printf.sprintf "(store %s %s %s)" (mem m) (expr a) (expr v)

let rec assertion = function
  | STrue -> "true" | SFalse -> "false"
  | SCmp (c,a,b) -> Printf.sprintf "(%s %s %s)" (smt_cmp c) (expr a) (expr b)
  | SAnd [] -> "true" | SAnd xs -> "(and " ^ String.concat " " (List.map assertion xs) ^ ")"
  | SOr [] -> "false" | SOr xs -> "(or " ^ String.concat " " (List.map assertion xs) ^ ")"
  | SNot a -> "(not " ^ assertion a ^ ")"
  | SImplies (a,b) -> Printf.sprintf "(=> %s %s)" (assertion a) (assertion b)
  | SPred (p,xs) -> Printf.sprintf "(%s%s)" (atom p)
      (if xs=[] then "" else " " ^ String.concat " " (List.map expr xs))

let declaration ret name arity =
  Printf.sprintf "(declare-fun %s (%s) %s)\n" (atom name)
    (String.concat " " (List.init arity (fun _ -> "Int"))) ret

let script formula =
  let s = collect_assertion empty formula in
  let b = Buffer.create 1024 in
  Buffer.add_string b "(set-option :produce-models true)\n(set-logic ALL)\n";
  SS.iter (fun x -> Buffer.add_string b (declaration "Int" x 0)) s.ints;
  SS.iter (fun x -> Buffer.add_string b (Printf.sprintf "(declare-fun %s () (Array Int Int))\n" (atom x))) s.mems;
  FM.iter (fun f n -> Buffer.add_string b (declaration "Int" f n)) s.funs;
  FM.iter (fun p n -> Buffer.add_string b (declaration "Bool" p n)) s.preds;
  Buffer.add_string b ("(assert " ^ assertion formula ^ ")\n(check-sat)\n(get-model)\n(exit)\n");
  Buffer.contents b

let read_all ch =
  let b = Buffer.create 256 in
  (try while true do Buffer.add_string b (input_line ch); Buffer.add_char b '\n' done with End_of_file -> ());
  Buffer.contents b

let check formula =
  let env = Unix.environment () in
  let ic, oc, ec = Unix.open_process_args_full "z3" [|"z3"; "-in"; "-smt2"|] env in
  output_string oc (script formula); flush oc;
  let out = read_all ic and err = read_all ec in
  ignore (Unix.close_process_full (ic, oc, ec));
  let first = match String.split_on_char '\n' out with x::_ -> String.trim x | [] -> "" in
  match first with
  | "sat" -> Sat out | "unsat" -> Unsat
  | _ -> Unknown (if err = "" then out else out ^ err)

let feasible pcs = match check (SAnd pcs) with Sat _ -> true | Unsat -> false | Unknown _ -> true
let valid assumptions goal = match check (SAnd [SAnd assumptions; SNot goal]) with Unsat -> true | _ -> false
