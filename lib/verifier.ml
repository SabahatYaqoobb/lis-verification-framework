open Symbolic

type bug_kind = Postcondition_violation | Api_precondition_violation of string

type bug_report = {
  kind : bug_kind;
  path_condition : sym_assertion;
  violated : sym_assertion;
  model : string;
  path : path_step list;
}

type verification_result =
  | Verified of { explored_paths : int }
  | Failed of bug_report list
  | Inconclusive of Executor.issue list

let model_for formula = match Solver.check formula with
  | Solver.Sat m -> Some m | Solver.Unsat | Solver.Unknown _ -> None

let post_bug post st =
  let expected = eval_assertion st post in
  let bad = SAnd [conjunction st; SNot expected] in
  match model_for bad with
  | None -> None
  | Some model -> Some { kind=Postcondition_violation; path_condition=conjunction st;
      violated=expected; model; path=List.rev st.path }

let issue_bug = function
  | Executor.Unsafe_api {name; state; required} ->
      let bad = SAnd [conjunction state; SNot required] in
      Option.map (fun model -> {kind=Api_precondition_violation name;
        path_condition=conjunction state; violated=required; model;
        path=List.rev state.path}) (model_for bad)
  | _ -> None

let run pre program =
  let init = Symbolic.initial in
  let init = { init with pc = [eval_assertion init pre] } in
  Executor.exec_program program init

let find_bugs pre program post =
  let out = run pre program in
  List.filter_map (post_bug post) out.states @ List.filter_map issue_bug out.issues

let find_bug_program pre program post = match find_bugs pre program post with x::_ -> Some x | [] -> None

let verify_program pre program post =
  let out = run pre program in
  let bugs = List.filter_map (post_bug post) out.states @ List.filter_map issue_bug out.issues in
  if bugs <> [] then Failed bugs
  else if out.issues <> [] then Inconclusive out.issues
  else Verified { explored_paths = List.length out.states }

let default_program body = { Syntax.body; apis=[]; loop_bound=8 }
let verify pre command post = verify_program pre (default_program command) post
let find_bug pre command post = find_bug_program pre (default_program command) post
