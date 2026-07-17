open Syntax
open Symbolic

let string_of_binop = function Add -> "+" | Sub -> "-" | Mul -> "*" | Div -> "/" | Mod -> "%"
let string_of_cmp = function Eq -> "=" | Ne -> "!=" | Lt -> "<" | Le -> "<=" | Gt -> ">" | Ge -> ">="

let rec expr = function
  | SInt n -> string_of_int n | SVar x -> x | SNeg x -> "(-" ^ expr x ^ ")"
  | SBinop (op,a,b) -> Printf.sprintf "(%s %s %s)" (expr a) (string_of_binop op) (expr b)
  | SSelect (m,a) -> Printf.sprintf "load(%s, %s)" (mem m) (expr a)
  | SFun (f,xs) -> f ^ "(" ^ String.concat ", " (List.map expr xs) ^ ")"
and mem = function
  | MVar x -> x
  | MStore (m,a,v) -> Printf.sprintf "store(%s, %s, %s)" (mem m) (expr a) (expr v)

let rec assertion = function
  | STrue -> "true" | SFalse -> "false"
  | SCmp (c,a,b) -> Printf.sprintf "%s %s %s" (expr a) (string_of_cmp c) (expr b)
  | SAnd xs -> "(" ^ String.concat " && " (List.map assertion xs) ^ ")"
  | SOr xs -> "(" ^ String.concat " || " (List.map assertion xs) ^ ")"
  | SNot a -> "!(" ^ assertion a ^ ")"
  | SImplies (a,b) -> Printf.sprintf "(%s => %s)" (assertion a) (assertion b)
  | SPred (p,xs) -> p ^ "(" ^ String.concat ", " (List.map expr xs) ^ ")"

let path_step = function
  | Branch s -> "branch " ^ s
  | Loop_iteration n -> Printf.sprintf "loop iteration %d" n
  | Api_call f -> "call " ^ f

