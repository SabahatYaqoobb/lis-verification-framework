let print_bug b =
  let kind = match b.Verifier.kind with
    | Verifier.Postcondition_violation -> "postcondition violation"
    | Verifier.Api_precondition_violation f -> "unsafe API call: " ^ f in
  Printf.printf "  FAIL (%s)\n  path: %s\n  expected: %s\n  counterexample:\n%s\n"
    kind
    (String.concat " -> " (List.map Pretty.path_step b.path))
    (Pretty.assertion b.violated) b.model

let run e =
  Printf.printf "\n%s\n" e.Programs.name;
  match Verifier.verify_program e.pre e.program e.post with
  | Verifier.Verified {explored_paths} -> Printf.printf "  VERIFIED (%d final path(s))\n" explored_paths
  | Verifier.Failed bugs -> List.iter print_bug bugs
  | Verifier.Inconclusive _ -> print_endline "  INCONCLUSIVE (loop bound or unsupported API)"

let () =
  print_endline "=== Programs expected to verify ==="; List.iter run Programs.verified;
  print_endline "\n=== Programs expected to produce counterexamples ==="; List.iter run Programs.buggy
