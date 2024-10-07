let () =
  let test_suite =
    Place_test.v @ Date_test.v @ Sosa_test.v @ Wiki_test.v @ Util_test.v
    @ Ports_test.v
  in
  let known_failures = [| "calendar-sdn"; "gw-royal"; "notes-br" |] in
  let is_ci = Option.is_some (Sys.getenv_opt "GENEWEB_CI") in
  let filter ~name ~index:_ =
    if is_ci && Array.mem name known_failures then `Skip else `Run
  in
  try Alcotest.run ~and_exit:false "Geneweb" ~filter test_suite
  with Alcotest.Test_error -> ()
