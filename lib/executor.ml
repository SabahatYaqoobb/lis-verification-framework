open Syntax
open Symbolic

type issue =
  | Unsafe_api of { name : string; state : state; required : sym_assertion }
  | Loop_bound_reached of { state : state; guard : sym_assertion }
  | Unknown_api of string

type outcome = { states : state list; issues : issue list }
let pure states = { states; issues = [] }
let combine a b = { states = a.states @ b.states; issues = a.issues @ b.issues }

let find_api apis name = List.find_opt (fun a -> a.name = name) apis

let bind_formals st names values =
  let env = List.fold_left2 (fun e n v -> StringMap.add n v e) st.env names values in
  { st with env }

let add_if_feasible condition label st =
  let s = { st with pc = condition :: st.pc; path = Branch label :: st.path } in
  if Solver.feasible s.pc then Some s else None

let rec exec_command apis bound cmd st =
  match cmd with
  | Skip -> pure [st]
  | Assign (x,e) -> pure [{ st with env = StringMap.add x (eval_expr st e) st.env }]
  | Store (a,v) -> pure [{ st with mem = MStore (st.mem, eval_expr st a, eval_expr st v) }]
  | Seq cmds ->
      List.fold_left (fun acc c ->
        let next = List.map (exec_command apis bound c) acc.states in
        { states = List.concat_map (fun x -> x.states) next;
          issues = acc.issues @ List.concat_map (fun x -> x.issues) next }) (pure [st]) cmds
  | If (g,t,e) ->
      let sg = eval_assertion st g in
      let run c = function None -> pure [] | Some s -> exec_command apis bound c s in
      combine (run t (add_if_feasible sg "then" st))
        (run e (add_if_feasible (SNot sg) "else" st))
  | While {guard; body; invariant=_} -> exec_loop apis bound guard body 0 st
  | Call (x,name,args) -> exec_call apis bound x name args st

and exec_loop apis bound guard body iteration st =
  let g = eval_assertion st guard in
  let exit = match add_if_feasible (SNot g) "loop exit" st with None -> [] | Some s -> [s] in
  if iteration >= bound then
    let issue = if Solver.feasible (g :: st.pc) then
        [Loop_bound_reached {state=st; guard=g}] else [] in
    { states = exit; issues = issue }
  else
    match add_if_feasible g "loop body" st with
    | None -> pure exit
    | Some entered ->
        let entered = { entered with path = Loop_iteration (iteration+1) :: entered.path } in
        let body_out = exec_command apis bound body entered in
        let continued = List.map (exec_loop apis bound guard body (iteration+1)) body_out.states in
        { states = exit @ List.concat_map (fun x -> x.states) continued;
          issues = body_out.issues @ List.concat_map (fun x -> x.issues) continued }

and exec_call apis _bound x name args st =
  match find_api apis name with
  | None -> { states=[]; issues=[Unknown_api name] }
  | Some spec when List.length spec.params <> List.length args ->
      { states=[]; issues=[Unknown_api (name ^ " (arity mismatch)")] }
  | Some spec ->
      let actuals = List.map (eval_expr st) args in
      let scoped = bind_formals st spec.params actuals in
      let required = eval_assertion scoped spec.pre in
      let unsafe = if Solver.valid st.pc required then [] else [Unsafe_api {name; state=st; required}] in
      let safe_state = { st with pc = required :: st.pc; path = Api_call name :: st.path } in
      if not (Solver.feasible safe_state.pc) then { states=[]; issues=unsafe }
      else
        let result, safe_state = fresh (name ^ "_result") safe_state in
        let scoped = bind_formals safe_state spec.params actuals in
        let scoped = { scoped with env = StringMap.add "result" result scoped.env } in
        let guarantee = eval_assertion scoped spec.post in
        let env = StringMap.add x result safe_state.env in
        { states=[{ safe_state with env; pc = guarantee :: safe_state.pc }]; issues=unsafe }

let exec command state = (exec_command [] 8 command state).states
let exec_program program state = exec_command program.apis program.loop_bound program.body state
