let string_of_status = function
  | Def.OK -> "200 OK"
  | Def.Moved_Temporarily -> "302 Moved Temporarily"
  | Def.Bad_Request -> "400 Bad Request"
  | Def.Unauthorized -> "401 Unauthorized"
  | Def.Forbidden -> "403 Forbidden"
  | Def.Not_Found -> "404 Not Found"
  | Def.Conflict -> "409 Conflict"
  | Def.Internal_Server_Error -> "500 Internal Server Error"
  | Def.Service_Unavailable -> "503 Service Unavailable"
  | Def.Gateway_Timeout -> "504 Gateway Timeout"

let json_entry key value =
  Printf.sprintf "\"%s\":\"%s\"" (String.escaped key) (String.escaped value)

let json_of_request_infos ~curr_tm ~tm ~request ~path ~query ~resp_status
    ~length =
  let utime = Printf.sprintf "\"utime\":%f" tm.Unix.tms_utime in
  let stime = Printf.sprintf "\"stime\":%f" tm.tms_stime in
  let resp_length = Printf.sprintf "\"resp_length\":%d" length in
  let resp_status =
    Option.value ~default:"" @@ Option.map string_of_status resp_status
  in
  "{"
  ^ String.concat ","
      [
        json_entry "date" curr_tm;
        json_entry "status" resp_status;
        resp_length;
        utime;
        stime;
        json_entry "path" path;
        json_entry "query" (Adef.as_string query);
      ]
  ^ "}"

let log_request_infos ~request ~path ~query ~resp_status ~length =
  let tm = Unix.times () in
  let curr_tm = (Mutil.sprintf_date Unix.(time () |> localtime) :> string) in
  let json =
    json_of_request_infos ~curr_tm ~tm ~request ~path ~query ~resp_status
      ~length
  in
  Printf.eprintf "GW_REQUEST_INFO : %s\n" json
