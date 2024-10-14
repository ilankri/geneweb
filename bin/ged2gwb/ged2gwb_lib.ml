(* Copyright (c) 1998-2007 INRIA *)

type person = (int, int, int) Def.gen_person
type ascend = int Def.gen_ascend
type union = int Def.gen_union
type family = (int, int, int) Def.gen_family
type couple = int Def.gen_couple
type descend = int Def.gen_descend

type record =
  { rlab : string;
    rval : string;
    rcont : string;
    rsons : record list;
    rpos : int;
    mutable rused : bool }

type month_number_dates =
    MonthDayDates
  | DayMonthDates
  | NoMonthNumberDates
  | MonthNumberHappened of string

type charset = Ansel | Ansi | Ascii | Msdos | MacIntosh | Utf8

type case = NoCase | LowerCase | UpperCase

module State = struct

type t = {
  log_oc : out_channel;
  lowercase_first_names : bool;
  track_ged2gw_id : bool;
  case_surnames : case;
  extract_first_names : bool;
  extract_public_names : bool;
  mutable charset_option : charset option;
  alive_years : int;
  dead_years : int;
  try_negative_dates : bool;
  no_negative_dates : bool;
  no_public_if_titles : bool;
  first_names_brackets : (char * char) option;
  untreated_in_notes : bool;
  force : bool;
  default_source : string;
  relation_status : Def.relation_kind;
  no_picture : bool;
  do_check : bool;
  particles : string list;
  in_file : string;
  out_file : string;
  mutable charset : charset;
  mutable month_number_dates : month_number_dates;
  mutable bad_dates_warned : bool;
  mutable date_str : string;
  mutable glop : string list;
  mutable line_cnt : int;
}

(* default variable *)
let log_oc = ref stdout
let lowercase_first_names = ref false
let track_ged2gw_id = ref false
let case_surnames = ref NoCase
let extract_first_names = ref false
let extract_public_names = ref true
let charset_option = ref None
let alive_years = ref 80
let dead_years = ref 120
let try_negative_dates = ref false
let no_negative_dates = ref false
let no_public_if_titles = ref false
let first_names_brackets = ref None
let untreated_in_notes = ref false
let force = ref false
let default_source = ref ""
let relation_status = ref Def.Married
let no_picture = ref false
let do_check = ref true
let particles = ref Mutil.default_particles
let in_file = ref ""
let out_file = ref "a"

(* default mutable variable *)
let charset = ref Ascii
let month_number_dates = ref NoMonthNumberDates
let bad_dates_warned = ref false
let date_str = ref ""
let glop = ref []
let line_cnt = ref 1

let make () =
  ( {
      log_oc = !log_oc;
      lowercase_first_names = !lowercase_first_names;
      track_ged2gw_id = !track_ged2gw_id;
      case_surnames = !case_surnames;
      extract_first_names = !extract_first_names;
      extract_public_names = !extract_public_names;
      charset_option = !charset_option;
      alive_years = !alive_years;
      dead_years = !dead_years;
      try_negative_dates = !try_negative_dates;
      no_negative_dates = !no_negative_dates;
      no_public_if_titles = !no_public_if_titles;
      first_names_brackets = !first_names_brackets;
      untreated_in_notes = !untreated_in_notes;
      force = !force;
      default_source = !default_source;
      relation_status = !relation_status;
      no_picture = !no_picture;
      do_check = !do_check;
      particles = !particles;
      in_file = !in_file;
      out_file = !out_file;
      charset = !charset;
      month_number_dates = !month_number_dates;
      bad_dates_warned = !bad_dates_warned;
      date_str = !date_str;
      glop = !glop;
      line_cnt = !line_cnt;
    } )

end

let default_state = State.make ()
let state = ref default_state

(* Reading input *)

let print_location pos =
  Printf.fprintf !state.log_oc "File \"%s\", line %d:\n" !state.in_file pos

let rec skip_eol =
  parser
  | [< ''\010' | '\013'; _ = skip_eol >] -> ()
  | [< >] -> ()

let rec get_to_eoln len =
  parser
  | [< ''\010' | '\013'; _ = skip_eol >] -> Buff.get len
  | [< ''\t'; s >] -> get_to_eoln (Buff.store len ' ') s
  | [< 'c; s >] -> get_to_eoln (Buff.store len c) s
  | [< >] -> Buff.get len

let rec skip_to_eoln =
  parser
  | [< ''\010' | '\013'; _ = skip_eol >] -> ()
  | [< '_; s >] -> skip_to_eoln s
  | [< >] -> ()

let eol_chars = ['\010'; '\013']

let rec get_ident len =
  parser
  | [< '' ' | '\t' >] -> Buff.get len
  | [< 'c when not (List.mem c eol_chars); s >] ->
      get_ident (Buff.store len c) s
  | [< >] -> Buff.get len

let skip_space =
  parser
  | [< '' ' | '\t' >] -> ()
  | [< >] -> ()

let rec line_start num =
  parser
  | [< '' '; s >] -> line_start num s
  | [< 'x when x = num >] -> ()

let ascii_of_msdos s =
  let conv_char i =
    let cc =
      match Char.code s.[i] with
        0o200 -> 0o307
      | 0o201 -> 0o374
      | 0o202 -> 0o351
      | 0o203 -> 0o342
      | 0o204 -> 0o344
      | 0o205 -> 0o340
      | 0o206 -> 0o345
      | 0o207 -> 0o347
      | 0o210 -> 0o352
      | 0o211 -> 0o353
      | 0o212 -> 0o350
      | 0o213 -> 0o357
      | 0o214 -> 0o356
      | 0o215 -> 0o354
      | 0o216 -> 0o304
      | 0o217 -> 0o305
      | 0o220 -> 0o311
      | 0o221 -> 0o346
      | 0o222 -> 0o306
      | 0o223 -> 0o364
      | 0o224 -> 0o366
      | 0o225 -> 0o362
      | 0o226 -> 0o373
      | 0o227 -> 0o371
      | 0o230 -> 0o377
      | 0o231 -> 0o326
      | 0o232 -> 0o334
      | 0o233 -> 0o242
      | 0o234 -> 0o243
      | 0o235 -> 0o245
      | 0o240 -> 0o341
      | 0o241 -> 0o355
      | 0o242 -> 0o363
      | 0o243 -> 0o372
      | 0o244 -> 0o361
      | 0o245 -> 0o321
      | 0o246 -> 0o252
      | 0o247 -> 0o272
      | 0o250 -> 0o277
      | 0o252 -> 0o254
      | 0o253 -> 0o275
      | 0o254 -> 0o274
      | 0o255 -> 0o241
      | 0o256 -> 0o253
      | 0o257 -> 0o273
      | 0o346 -> 0o265
      | 0o361 -> 0o261
      | 0o366 -> 0o367
      | 0o370 -> 0o260
      | 0o372 -> 0o267
      | 0o375 -> 0o262
      | c -> c
    in
    Char.chr cc
  in
  String.init (String.length s) conv_char

let ascii_of_macintosh s =
  let conv_char i =
    let cc =
      match Char.code s.[i] with
        0o200 -> 0o304
      | 0o201 -> 0o305
      | 0o202 -> 0o307
      | 0o203 -> 0o311
      | 0o204 -> 0o321
      | 0o205 -> 0o326
      | 0o206 -> 0o334
      | 0o207 -> 0o341
      | 0o210 -> 0o340
      | 0o211 -> 0o342
      | 0o212 -> 0o344
      | 0o213 -> 0o343
      | 0o214 -> 0o345
      | 0o215 -> 0o347
      | 0o216 -> 0o351
      | 0o217 -> 0o350
      | 0o220 -> 0o352
      | 0o221 -> 0o353
      | 0o222 -> 0o355
      | 0o223 -> 0o354
      | 0o224 -> 0o356
      | 0o225 -> 0o357
      | 0o226 -> 0o361
      | 0o227 -> 0o363
      | 0o230 -> 0o362
      | 0o231 -> 0o364
      | 0o232 -> 0o366
      | 0o233 -> 0o365
      | 0o234 -> 0o372
      | 0o235 -> 0o371
      | 0o236 -> 0o373
      | 0o237 -> 0o374
      | 0o241 -> 0o260
      | 0o244 -> 0o247
      | 0o245 -> 0o267
      | 0o246 -> 0o266
      | 0o247 -> 0o337
      | 0o250 -> 0o256
      | 0o256 -> 0o306
      | 0o257 -> 0o330
      | 0o264 -> 0o245
      | 0o273 -> 0o252
      | 0o274 -> 0o272
      | 0o276 -> 0o346
      | 0o277 -> 0o370
      | 0o300 -> 0o277
      | 0o301 -> 0o241
      | 0o302 -> 0o254
      | 0o307 -> 0o253
      | 0o310 -> 0o273
      | 0o312 -> 0o040
      | 0o313 -> 0o300
      | 0o314 -> 0o303
      | 0o315 -> 0o325
      | 0o320 -> 0o255
      | 0o326 -> 0o367
      | 0o330 -> 0o377
      | 0o345 -> 0o302
      | 0o346 -> 0o312
      | 0o347 -> 0o301
      | 0o350 -> 0o313
      | 0o351 -> 0o310
      | 0o352 -> 0o315
      | 0o353 -> 0o316
      | 0o354 -> 0o317
      | 0o355 -> 0o314
      | 0o356 -> 0o323
      | 0o357 -> 0o324
      | 0o361 -> 0o322
      | 0o362 -> 0o332
      | 0o363 -> 0o333
      | 0o364 -> 0o331
      | c -> c
    in
    Char.chr cc
  in
  String.init (String.length s) conv_char

let utf8_of_string s =
  match !state.charset with
  | Ansel -> Utf8.utf_8_of_iso_8859_1 (Geneweb.Ansel.to_iso_8859_1 s)
  | Ansi -> Utf8.utf_8_of_iso_8859_1 s
  | Ascii -> Utf8.utf_8_of_iso_8859_1 s
  | Msdos -> Utf8.utf_8_of_iso_8859_1 (ascii_of_msdos s)
  | MacIntosh -> Utf8.utf_8_of_iso_8859_1 (ascii_of_macintosh s)
  | Utf8 -> s

let rec get_lev n =
  parser
    [< _ = line_start n; _ = skip_space; r1 = get_ident 0; strm >] ->
      let (rlab, rval, rcont, l) =
        if String.length r1 > 0 && r1.[0] = '@' then parse_address n r1 strm
        else parse_text n r1 strm
      in
      {rlab = rlab; rval = utf8_of_string rval;
       rcont = utf8_of_string rcont; rsons = List.rev l; rpos = !state.line_cnt;
       rused = false}
and parse_address n r1 =
  parser
    [< r2 = get_ident 0; r3 = get_to_eoln 0 (* ? "get to eoln" *);
       l = get_lev_list [] (Char.chr (Char.code n + 1)) (* ? "get lev list" *) >] ->
      (r2, r1, r3, l)
and parse_text n r1 =
  parser
    [< r2 = get_to_eoln 0;
       l = get_lev_list [] (Char.chr (Char.code n + 1)) (* ? "get lev list" *) >] ->
      (r1, r2, "", l)
and get_lev_list l n =
  parser
  | [< x = get_lev n; s >] -> get_lev_list (x :: l) n s
  | [< >] -> l

(* Error *)

let print_bad_date pos d =
  if !state.bad_dates_warned then ()
  else
    begin
      !state.bad_dates_warned <- true;
      print_location pos;
      Printf.fprintf !state.log_oc "Can't decode date %s\n" d;
      flush !state.log_oc
    end

let check_month m =
  if m < 1 || m > 12 then
    begin
      Printf.fprintf !state.log_oc "Bad (numbered) month in date: %d\n" m;
      flush !state.log_oc
    end

let warning_month_number_dates () =
  match !state.month_number_dates with
    MonthNumberHappened s ->
      Printf.fprintf !state.log_oc
        "  Warning: the file holds dates with numbered months (like: 12/05/1912).\n  \
 \n  \
  GEDCOM standard *requires* that months in dates be identifiers. The\n  \
  correct form for this example would be 12 MAY 1912 or 5 DEC 1912.\n  \
  \n  \
  Consider restarting with option \"-dates_dm\" or \"-dates_md\".\n  \
  Use option -help to see what they do.\n  \
  \n  \
  (example found in gedcom: \"%s\")"
        s;
      flush !state.log_oc
  | _ -> ()

(* Decoding fields *)
let rec skip_spaces =
  parser
  | [< '' '; s >] -> skip_spaces s
  | [< >] -> ()
let rec ident_slash len =
  parser
  | [< ''/' >] -> Buff.get len
  | [< ''\t'; a = ident_slash (Buff.store len ' ') >] -> a
  | [< 'c; a = ident_slash (Buff.store len c) >] -> a
  | [< >] -> Buff.get len

let strip c str =
  let start =
    let rec loop i =
      if i = String.length str then i
      else if str.[i] = c then loop (i + 1)
      else i
    in
    loop 0
  in
  let stop =
    let rec loop i =
      if i = -1 then i + 1 else if str.[i] = c then loop (i - 1) else i + 1
    in
    loop (String.length str - 1)
  in
  if start = 0 && stop = String.length str then str
  else if start >= stop then ""
  else String.sub str start (stop - start)

let strip_spaces = strip ' '
let strip_newlines = strip '\n'

let parse_name =
  parser
    [< _ = skip_spaces;
       invert =
       (parser
       | [< ''/' >] -> true
       | [< >] -> false) ;
       f = ident_slash 0; _ = skip_spaces; s = ident_slash 0 >] ->
  let (f, s) = if invert then (s, f) else (f, s) in
  let f = strip_spaces f in
  let s = strip_spaces s in
  let f = if f = "" then Option.none else Option.some f in
  let s = if s = "" then Option.none else Option.some s in
  f, s

let parse_alias s = match parse_name s with
  | Some f, Some s -> Some (Printf.sprintf "%s %s" f s)
  | Some n, None
  | None, Some n -> Some n
  | None, None -> None

let string_of_first_name_option = function
  | Some f -> f
  | None -> "x"

let string_of_surname_option = function
  | Some s -> s
  | None -> "?"

let rec find_field lab =
  function
    r :: rl ->
      if r.rlab = lab then begin r.rused <- true; Some r end
      else find_field lab rl
  | [] -> None

let rec find_all_fields lab =
  function
    r :: rl ->
      if r.rlab = lab then
        begin r.rused <- true; r :: find_all_fields lab rl end
      else find_all_fields lab rl
  | [] -> []

let rec find_field_with_value lab v =
  function
    r :: rl ->
      if r.rlab = lab && r.rval = v then begin r.rused <- true; true end
      else find_field_with_value lab v rl
  | [] -> false

let rec lexing_date =
  parser
  | [< ''0'..'9' as c; n = number (Buff.store 0 c) >] -> ("INT", n)
  | [< ''A'..'Z' as c; i = ident (Buff.store 0 c) >] -> ("ID", i)
  | [< ''('; len = text 0 >] -> ("TEXT", Buff.get len)
  | [< ''.' >] -> ("", ".")
  | [< '' ' | '\t' | '\013'; s >] -> lexing_date s
  | [< _ = Stream.empty >] -> ("EOI", "")
  | [< 'x >] -> ("", String.make 1 x)
and number len =
  parser
  | [< ''0'..'9' as c; a = number (Buff.store len c) >] -> a
  | [< >] -> Buff.get len
and ident len =
  parser
  | [< ''A'..'Z' as c; a = ident (Buff.store len c) >] -> a
  | [< >] -> Buff.get len
and text len =
  parser
  | [< '')' >] -> len
  | [< ''('; len = text (Buff.store len '('); s >] ->
      text (Buff.store len ')') s
  | [< 'c; s >] -> text (Buff.store len c) s
  | [< >] -> len

let make_date_lexing s = Stream.from (fun _ -> Some (lexing_date s))

let tparse = Token.default_match

let using_token (p_con, _) =
  match p_con with
    "" | "INT" | "ID" | "TEXT" | "EOI" -> ()
  | _ ->
      raise
        (Token.Error
           ("the constructor \"" ^ p_con ^
            "\" is not recognized by the lexer"))

let date_lexer =
  { Token.tok_func =
      (fun s -> make_date_lexing s
              ,  { Plexing.Locations.locations = ref [||]
                 ; overflow = ref true }
      )
  ; Token.tok_using = using_token
  ; Token.tok_removing = (fun _ -> ())
  ; Token.tok_match = tparse
  ; Token.tok_text = (fun _ -> "<tok>")
  ; Token.tok_comm = None
  }

type 'a range =
    Begin of 'a
  | End of 'a
  | BeginEnd of 'a * 'a

let date_g = Grammar.gcreate date_lexer
let date_value = Grammar.Entry.create date_g "date value"
let date_interval = Grammar.Entry.create date_g "date interval"
let date_value_recover = Grammar.Entry.create date_g "date value"

let is_roman_int x =
  try let _ = Mutil.arabian_of_roman x in true with Not_found -> false

let start_with_int x =
  try let s = String.sub x 0 1 in let _ = int_of_string s in true with
    _ -> false

let roman_int =
  let p =
    parser [< '("ID", x) when is_roman_int x >] -> Mutil.arabian_of_roman x
  in
  Grammar.Entry.of_parser date_g "roman int" p

let make_date n1 n2 n3 =
  let n3 =
    if !state.no_negative_dates then
      match n3 with
        Some n3 -> Some (abs n3)
      | None -> None
    else n3
  in
  match n1, n2, n3 with
    Some d, Some m, Some y ->
      let (d, m) =
        match m with
          Def.Right m -> d, m
        | Left m ->
            match !state.month_number_dates with
              DayMonthDates -> check_month m; d, m
            | MonthDayDates -> check_month d; m, d
            | _ ->
                if d >= 1 && m >= 1 && d <= 31 && m <= 31 then
                  if d > 13 && m <= 13 then d, m
                  else if m > 13 && d <= 13 then m, d
                  else if d > 13 && m > 13 then 0, 0
                  else
                    begin
                      !state.month_number_dates <- MonthNumberHappened !state.date_str;
                      0, 0
                    end
                else 0, 0
      in
      let (d, m) = if m < 1 || m > 13 then 0, 0 else d, m in
      Date.{day = d; month = m; year = y; prec = Sure; delta = 0}
  | None, Some m, Some y ->
      let m =
        match m with
          Def.Right m -> m
        | Left m -> m
      in
      {day = 0; month = m; year = y; prec = Sure; delta = 0}
  | None, None, Some y ->
      {day = 0; month = 0; year = y; prec = Sure; delta = 0}
  | Some y, None, None ->
      {day = 0; month = 0; year = y; prec = Sure; delta = 0}
  | _ -> raise (Stream.Error "bad date")

let recover_date cal = function
  | Date.Dgreg (d, Dgregorian) ->
    let d = Date.convert ~from:cal ~to_:Dgregorian d in
    Date.Dgreg (d, cal)
  | d -> d

[@@@ocaml.warning "-27"]
EXTEND
  GLOBAL: date_value date_interval date_value_recover;
  date_value:
    [ [ d = date_or_text; EOI -> d ] ]
  ;
  date_value_recover:
    [ [ "@"; "#"; ID "DGREGORIAN"; "@"; d = date_value ->
          recover_date Dgregorian d
      | "@"; "#"; ID "DJULIAN"; "@"; d = date_value ->
          recover_date Djulian d
      | "@"; "#"; ID "DFRENCH"; ID "R"; "@"; d = date_value ->
          recover_date Dfrench d
      | "@"; "#"; ID "DHEBREW"; "@"; d = date_value ->
          recover_date Dhebrew d ] ]
  ;
  date_interval:
    [ [ ID "BEF"; dt = date_or_text; EOI -> End dt
      | ID "AFT"; dt = date_or_text; EOI -> Begin dt
      | ID "BET"; dt = date_or_text; ID "AND"; dt1 = date_or_text; EOI ->
          BeginEnd (dt, dt1)
      | ID "TO"; dt = date_or_text; EOI -> End dt
      | ID "FROM"; dt = date_or_text; EOI -> Begin dt
      | ID "FROM"; dt = date_or_text; ID "TO"; dt1 = date_or_text; EOI ->
          BeginEnd (dt, dt1)
      | dt = date_or_text; EOI -> Begin dt ] ]
  ;
  date_or_text:
    [ [ dr = date_range ->
          begin match dr with
          | Begin (d, cal) -> Dgreg ({d with prec = After}, cal)
          | End (d, cal) -> Dgreg ({d with prec = Before}, cal)
          | BeginEnd ((d1, cal1), (d2, cal2)) ->
            let dmy2 = {Date.dmy2_of_dmy d2 with delta2 = 0} in
            Dgreg ({d1 with prec = YearInt dmy2}, cal1)
          end
      | (d, cal) = date -> Dgreg (d, cal)
      | s = TEXT -> Dtext s ] ]
  ;
  date_range:
    [ [ ID "BEF"; dt = date -> End dt
      | ID "AFT"; dt = date -> Begin dt
      | ID "BET"; dt = date; ID "AND"; dt1 = date -> BeginEnd (dt, dt1)
      | ID "TO"; dt = date -> End dt
      | ID "FROM"; dt = date -> Begin dt
      | ID "FROM"; dt = date; ID "TO"; dt1 = date -> BeginEnd (dt, dt1) ] ]
  ;
  date:
    [ [ ID "ABT"; (d, cal) = date_calendar -> ({(d) with prec = About}, cal)
      | ID "ENV"; (d, cal) = date_calendar -> ({(d) with prec = About}, cal)
      | ID "EST"; (d, cal) = date_calendar -> ({(d) with prec = Maybe}, cal)
      | ID "AFT"; (d, cal) = date_calendar -> ({(d) with prec = Before}, cal)
      | ID "BEF"; (d, cal) = date_calendar -> ({(d) with prec = After}, cal)
      | (d, cal) = date_calendar -> (d, cal) ] ]
  ;
  date_calendar:
    [ [ "@"; "#"; ID "DGREGORIAN"; "@"; d = date_greg -> (d, Dgregorian)
      | "@"; "#"; ID "DJULIAN"; "@"; d = date_greg ->
          (Date.convert ~from:Djulian ~to_:Dgregorian d, Djulian)
      | "@"; "#"; ID "DFRENCH"; ID "R"; "@"; d = date_fren ->
          (Date.convert ~from:Dfrench ~to_:Dgregorian d, Dfrench)
      | "@"; "#"; ID "DHEBREW"; "@"; d = date_hebr ->
          (Date.convert ~from:Dhebrew ~to_:Dgregorian d, Dhebrew)
      | d = date_greg -> (d, Dgregorian) ] ]
  ;
  date_greg:
    [ [ LIST0 "."; n1 = OPT int; LIST0 [ "." | "/" ]; n2 = OPT gen_month;
        LIST0 [ "." | "/" ]; n3 = OPT int; LIST0 "." ->
          make_date n1 n2 n3 ] ]
  ;
  date_fren:
    [ [ LIST0 "."; n1 = int; (n2, n3) = date_fren_kont ->
          make_date (Some n1) n2 n3
      | LIST0 "."; n1 = year_fren -> make_date (Some n1) None None
      | LIST0 "."; (n2, n3) = date_fren_kont -> make_date None n2 n3 ] ]
  ;
  date_fren_kont:
    [ [ LIST0 [ "." | "/" ]; n2 = OPT gen_french; LIST0 [ "." | "/" ];
        n3 = OPT year_fren; LIST0 "." ->
          (n2, n3) ] ]
  ;
  date_hebr:
    [ [ LIST0 "."; n1 = OPT int; LIST0 [ "." | "/" ]; n2 = OPT gen_hebr;
        LIST0 [ "." | "/" ]; n3 = OPT int; LIST0 "." ->
          make_date n1 n2 n3 ] ]
  ;
  gen_month:
    [ [ i = int -> Left (abs i)
      | m = month -> Def.Right m ] ]
  ;
  month:
    [ [ ID "JAN" -> 1
      | ID "FEB" -> 2
      | ID "MAR" -> 3
      | ID "APR" -> 4
      | ID "MAY" -> 5
      | ID "JUN" -> 6
      | ID "JUL" -> 7
      | ID "AUG" -> 8
      | ID "SEP" -> 9
      | ID "OCT" -> 10
      | ID "NOV" -> 11
      | ID "DEC" -> 12 ] ]
  ;
  gen_french:
    [ [ m = french -> Def.Right m ] ]
  ;
  french:
    [ [ ID "VEND" -> 1
      | ID "BRUM" -> 2
      | ID "FRIM" -> 3
      | ID "NIVO" -> 4
      | ID "PLUV" -> 5
      | ID "VENT" -> 6
      | ID "GERM" -> 7
      | ID "FLOR" -> 8
      | ID "PRAI" -> 9
      | ID "MESS" -> 10
      | ID "THER" -> 11
      | ID "FRUC" -> 12
      | ID "COMP" -> 13 ] ]
  ;
  year_fren:
    [ [ i = int -> i
      | ID "AN"; i = roman_int -> i
      | i = roman_int -> i ] ]
  ;
  gen_hebr:
    [ [ m = hebr -> Def.Right m ] ]
  ;
  hebr:
    [ [ ID "TSH" -> 1
      | ID "CSH" -> 2
      | ID "KSL" -> 3
      | ID "TVT" -> 4
      | ID "SHV" -> 5
      | ID "ADR" -> 6
      | ID "ADS" -> 7
      | ID "NSN" -> 8
      | ID "IYR" -> 9
      | ID "SVN" -> 10
      | ID "TMZ" -> 11
      | ID "AAV" -> 12
      | ID "ELL" -> 13 ] ]
  ;
  int:
    [ [ i = INT ->
          (try int_of_string i with Failure _ -> raise Stream.Failure)
      | "-"; i = INT ->
          (try (- int_of_string i) with  Failure _ -> raise Stream.Failure) ] ]
  ;
END
[@@@ocaml.warning "+27"]

(* Perform a regular expression match. *)
let preg_match pattern subject =
  let re = Str.regexp pattern in
  try ignore (Str.search_forward re subject 0); true with Not_found -> false

let date_of_field d =
  if d = "" then None
  else if preg_match "^[0-9]+$" d && String.length d > 8 then Some (Date.Dtext d)
  else
    let s = Stream.of_string (String.uppercase_ascii d) in
    !state.date_str <- d;
    try Some (Grammar.Entry.parse date_value s) with
      Ploc.Exc (_, Stream.Error _) ->
        let s = Stream.of_string (String.uppercase_ascii d) in
        try Some (Grammar.Entry.parse date_value_recover s) with
          Ploc.Exc (_, Stream.Error _) -> Some (Dtext d)

(* Creating base *)

type 'a tab = { mutable arr : 'a array ; mutable tlen : int }

type gen =
  { g_per : (string, person * ascend * union) Def.choice tab
  ; g_fam : (string, family * couple * descend) Def.choice tab
  ; g_str : string tab
  ; mutable g_bnot : string
  ; g_ic : in_channel
  ; g_not : (string, int) Hashtbl.t
  ; g_src : (string, int) Hashtbl.t
  ; g_hper : (string, int) Hashtbl.t
  ; g_hfam : (string, int) Hashtbl.t
  ; g_hstr : (string, int) Hashtbl.t
  ; g_hnam : (string, int ref) Hashtbl.t
  ; g_adop : (string, int * string) Hashtbl.t
  ; mutable g_godp : (int * int) list
  ; mutable g_prelated : (int * int) list
  ; mutable g_frelated : (int * int) list
  ; mutable g_witn : (int * int) list
  }

let assume_tab tab none =
  if tab.tlen = Array.length tab.arr then
    let new_len = 2 * Array.length tab.arr + 1 in
    let new_arr = Array.make new_len none in
    Array.blit tab.arr 0 new_arr 0 (Array.length tab.arr) ;
    tab.arr <- new_arr

let add_string gen s =
  try Hashtbl.find gen.g_hstr s
  with Not_found ->
    let i = gen.g_str.tlen in
    assume_tab gen.g_str "";
    gen.g_str.arr.(i) <- s;
    gen.g_str.tlen <- gen.g_str.tlen + 1;
    Hashtbl.add gen.g_hstr s i;
    i

let extract_addr addr =
  if String.length addr > 0 && addr.[0] = '@' then
    try let r = String.index_from addr 1 '@' in String.sub addr 0 (r + 1) with
      Not_found -> addr
  else addr

(* Output Pindex in file *)
let output_pindex i str =
  if !state.track_ged2gw_id then Printf.printf "IDGED2IDPERS %i %s\n" i str

let per_index gen lab =
  let lab = extract_addr lab in
  try Hashtbl.find gen.g_hper lab
  with Not_found ->
    let i = gen.g_per.tlen in
    assume_tab gen.g_per (Def.Left "");
    gen.g_per.arr.(i) <- Def.Left lab;
    gen.g_per.tlen <- gen.g_per.tlen + 1;
    Hashtbl.add gen.g_hper lab i;
    output_pindex i lab;
    i

let fam_index gen lab =
  let lab = extract_addr lab in
  try Hashtbl.find gen.g_hfam lab
  with Not_found ->
    let i = gen.g_fam.tlen in
    assume_tab gen.g_fam (Def.Left "");
    gen.g_fam.arr.(i) <- Def.Left lab;
    gen.g_fam.tlen <- gen.g_fam.tlen + 1;
    Hashtbl.add gen.g_hfam lab i;
    i

let string_empty = 0
let string_quest = 1
let string_x = 2

let unknown_per i sex =
  let p = { (Mutil.empty_person string_empty string_quest) with sex ; occ = i ; key_index = i }
  and a = {Def.parents = None; consang = Adef.fix (-1)}
  and u = {Def.family = [| |]} in
  p, a, u

let phony_per gen sex =
  let i = gen.g_per.tlen in
  let (person, ascend, union) = unknown_per i sex in
  assume_tab gen.g_per (Def.Left "");
  gen.g_per.tlen <- gen.g_per.tlen + 1;
  gen.g_per.arr.(i) <- Def.Right (person, ascend, union);
  i

let unknown_fam gen i =
  let father = phony_per gen Def.Male in
  let mother = phony_per gen Female in
  let f = { (Mutil.empty_family string_empty) with Def.fam_index = i }
  and c = Adef.couple father mother
  and d = {Def.children = [| |]} in
  f, c, d

let phony_fam gen =
  let i = gen.g_fam.tlen in
  let (fam, cpl, des) = unknown_fam gen i in
  assume_tab gen.g_fam (Def.Left "");
  gen.g_fam.tlen <- gen.g_fam.tlen + 1;
  gen.g_fam.arr.(i) <- Def.Right (fam, cpl, des);
  i

let this_year =
  let tm = Unix.localtime (Unix.time ()) in tm.Unix.tm_year + 1900

let infer_death birth bapt =
  match birth, bapt with
  | Some (Date.Dgreg (d, _)), _ ->
    let a = this_year - d.year in
    if a > !state.dead_years then Def.DeadDontKnowWhen
    else if a < !state.alive_years then NotDead
    else DontKnowIfDead
  | _, Some (Date.Dgreg (d, _)) ->
    let a = this_year - d.year in
    if a > !state.dead_years then Def.DeadDontKnowWhen
    else if a < !state.alive_years then NotDead
    else DontKnowIfDead
  | _ -> DontKnowIfDead

(* Fonctions utiles pour la mise en forme des noms. *)

let string_ini_eq s1 i s2 =
  let rec loop i j =
    if j = String.length s2 then true
    else if i = String.length s1 then false
    else if s1.[i] = s2.[j] then loop (i + 1) (j + 1)
    else false
  in
  loop i 0

let particle s i =
  List.exists (string_ini_eq s i) !state.particles

let look_like_a_number s =
  let rec loop i =
    if i < 0 then assert false
    else if i >= String.length s then true
    else
      match s.[i] with
        '0'..'9' -> loop (i + 1)
      | _ -> false
  in
  loop 0

let is_a_name_char =
  function
    'A'..'Z' | 'a'..'z' | '0'..'9' | '-' | '\'' -> true
  | c -> Char.code c > 127

let rec next_word_pos s i =
  if i >= String.length s then i
  else if is_a_name_char s.[i] then i
  else next_word_pos s (i + 1)

let rec next_sep_pos s i =
  if i >= String.length s then String.length s
  else if is_a_name_char s.[i] then next_sep_pos s (i + 1)
  else i

let public_name_word =
  ["Ier"; "Ière"; "der"; "den"; "die"; "el"; "le"; "la"; "the"]

let rec is_a_public_name s i =
  let i = next_word_pos s i in
  i < String.length s &&
  (let j = next_sep_pos s i in
   j > i &&
   (let w = String.sub s i (j - i) in
    look_like_a_number w ||
    is_roman_int w && j < String.length s && s.[j] <> '.' ||
    List.mem w public_name_word || is_a_public_name s j))


module Buff2 = Buff.Make (struct  end)

let aux fn s =
  (* On initialise le buffer à la valeur de s. *)
  let _ = Buff2.mstore 0 s in
  let rec loop len k =
    let i = next_word_pos s k in
    if i = String.length s then Buff2.get (String.length s)
    else
      let j = next_sep_pos s i in
      if j > i then
        let w = String.sub s i (j - i) in
        let w =
          if is_roman_int w || particle s i || List.mem w public_name_word ||
             start_with_int w
          then
            w
          else fn w
        in
        let len =
          let rec loop len k =
            if k = i then len else loop (Buff2.store len s.[k]) (k + 1)
          in
          loop len k
        in
        loop (Buff2.mstore len w) j
      else Buff2.get len
  in
  loop 0 0

let capitalize_name = aux Name.title

let uppercase_name = aux Utf8.uppercase

let get_lev0 (strm__ : _ Stream.t) =
  let _ = line_start '0' strm__ in
  let _ =
    try skip_space strm__ with Stream.Failure -> raise (Stream.Error "")
  in
  let r1 =
    try get_ident 0 strm__ with Stream.Failure -> raise (Stream.Error "")
  in
  let r2 =
    try get_ident 0 strm__ with Stream.Failure -> raise (Stream.Error "")
  in
  let r3 =
    try get_to_eoln 0 strm__ with Stream.Failure -> raise (Stream.Error "")
  in
  let l =
    try get_lev_list [] '1' strm__ with
      Stream.Failure -> raise (Stream.Error "")
  in
  let (rlab, rval) = if r2 = "" then r1, "" else r2, r1 in
  let rval = utf8_of_string rval in
  let rcont = utf8_of_string r3 in
  {rlab = rlab; rval = rval; rcont = rcont; rsons = List.rev l;
   rpos = !state.line_cnt; rused = false}

let find_notes_record gen addr =
  match try Some (Hashtbl.find gen.g_not addr) with Not_found -> None with
    Some i ->
      seek_in gen.g_ic i;
      begin try Some (get_lev0 (Stream.of_channel gen.g_ic)) with
        Stream.Failure | Stream.Error _ -> None
      end
  | None -> None

let find_sources_record gen addr =
  match try Some (Hashtbl.find gen.g_src addr) with Not_found -> None with
    Some i ->
      seek_in gen.g_ic i;
      begin try Some (get_lev '0' (Stream.of_channel gen.g_ic)) with
        Stream.Failure | Stream.Error _ -> None
      end
  | None -> None

let rec flatten_notes =
  function
    r :: rl ->
      let n = flatten_notes rl in
      begin match r.rlab with
        "CONC" | "CONT" | "NOTE" ->
          (r.rlab, r.rval) :: (flatten_notes r.rsons @ n)
      | _ -> n
      end
  | [] -> []

let extract_notes gen rl =
  List.fold_right
    (fun r lines ->
       List.fold_right
         (fun r lines ->
            r.rused <- true;
            if r.rlab = "NOTE" && r.rval <> "" && r.rval.[0] = '@' then
              let addr = extract_addr r.rval in
              match find_notes_record gen addr with
                Some r ->
                  let l = flatten_notes r.rsons in
                  ("NOTE", r.rcont) :: (l @ lines)
              | None ->
                  print_location r.rpos;
                  Printf.fprintf !state.log_oc "Note %s not found\n" addr;
                  flush !state.log_oc;
                  lines
            else (r.rlab, r.rval) :: lines)
         (r :: r.rsons) lines)
    rl []

let rebuild_text r =
  let s = strip_spaces r.rval in
  List.fold_left
    (fun s e ->
       let _ = e.rused <- true in
       let n = e.rval in
       let end_spc =
         if String.length n > 1 && n.[String.length n - 1] = ' ' then " "
         else ""
       in
       let n = strip_spaces n in
       match e.rlab with
         "CONC" -> s ^ n ^ end_spc
       | "CONT" -> s ^ "<br>\n" ^ n ^ end_spc
       | _ -> s)
    s r.rsons

let notes_from_source_record rl =
  let title =
    match find_field "TITL" rl with
      Some l ->
        let s = rebuild_text l in if s = "" then "" else "<b>" ^ s ^ "</b>"
    | None -> ""
  in
  let text =
    match find_field "TEXT" rl with
      Some l ->
        let s = rebuild_text l in if title = "" then s else "<br>\n" ^ s
    | None -> ""
  in
  title ^ text

let treat_notes gen rl =
  let lines = extract_notes gen rl in
  let buf = Buffer.create (List.length lines) in
  let () =
    List.iter
      (fun (lab, n) ->
         let spc = String.length n > 0 && n.[0] = ' ' in
         let end_spc = String.length n > 1 && n.[String.length n - 1] = ' ' in
         let n = strip_spaces n in
         if Buffer.length buf = 0 then
           begin
             Buffer.add_string buf n;
             Buffer.add_string buf (if end_spc then " " else "")
           end
         else if lab = "CONT" || lab = "NOTE" then
           begin
             Buffer.add_string buf "<br>\n";
             Buffer.add_string buf n;
             Buffer.add_string buf (if end_spc then " " else "")
           end
         else if n = "" then ()
         else
           begin
             Buffer.add_string buf (if spc then "\n" else "");
             Buffer.add_string buf n;
             Buffer.add_string buf (if end_spc then " " else "")
           end)
      lines
  in
  strip_newlines (Buffer.contents buf)

let treat_source gen r =
  if String.length r.rval > 0 && r.rval.[0] = '@' then
    match find_sources_record gen r.rval with
      Some v -> strip_spaces v.rcont, v.rsons
    | None ->
        print_location r.rpos;
        Printf.fprintf !state.log_oc "Source %s not found\n" r.rval;
        flush !state.log_oc;
        "", []
  else strip_spaces r.rval, r.rsons

let source gen r =
  match find_field "SOUR" r.rsons with
    Some r -> treat_source gen r
  | _ -> "", []

let p_index_from s i c =
  if i >= String.length s then String.length s
  else try String.index_from s i c with Not_found -> String.length s

let strip_sub s beg len = strip_spaces (String.sub s beg len)

let decode_title s =
  let i1 = p_index_from s 0 ',' in
  let i2 = p_index_from s (i1 + 1) ',' in
  let title = strip_sub s 0 i1 in
  let (place, nth) =
    if i1 = String.length s then "", 0
    else if i2 = String.length s then
      let s1 = strip_sub s (i1 + 1) (i2 - i1 - 1) in
      try "", int_of_string s1 with Failure _ -> s1, 0
    else
      let s1 = strip_sub s (i1 + 1) (i2 - i1 - 1) in
      let s2 = strip_sub s (i2 + 1) (String.length s - i2 - 1) in
      try s1, int_of_string s2 with
        Failure _ -> strip_sub s i1 (String.length s - i1), 0
  in
  title, place, nth

let list_of_string s =
  let rec loop i len list =
    if i = String.length s then List.rev (Buff.get len :: list)
    else
      match s.[i] with
        ',' -> loop (i + 1) 0 (Buff.get len :: list)
      | c -> loop (i + 1) (Buff.store len c) list
  in
  loop 0 0 []

let purge_list list =
  List.fold_right
    (fun s list ->
       match strip_spaces s with
         "" -> list
       | s -> s :: list)
    list []

let decode_date_interval pos s =
  let strm = Stream.of_string s in
  try
    match Grammar.Entry.parse date_interval strm with
      BeginEnd (d1, d2) -> Some d1, Some d2
    | Begin d -> Some d, None
    | End d -> None, Some d
  with Ploc.Exc (_, _) | Not_found -> print_bad_date pos s; None, None

let treat_indi_title gen public_name r =
  let (title, place, nth) = decode_title r.rval in
  let (date_start, date_end) =
    match find_field "DATE" r.rsons with
      Some r -> decode_date_interval r.rpos r.rval
    | None -> None, None
  in
  let (name, title, place) =
    match find_field "NOTE" r.rsons with
      Some r ->
        if title = "" then Def.Tnone, strip_spaces r.rval, ""
        else if r.rval = public_name then Tmain, title, place
        else Tname (add_string gen (strip_spaces r.rval)), title, place
    | None -> Def.Tnone, title, place
  in
  {Def.t_name = name; t_ident = add_string gen title;
   t_place = add_string gen place; t_date_start = Date.cdate_of_od date_start;
   t_date_end = Date.cdate_of_od date_end; t_nth = nth}

let forward_adop gen ip lab which_parent =
  Hashtbl.add
    gen.g_adop lab
    (ip, match which_parent with Some r when r.rval <> "" -> r.rval | _ -> "BOTH")

let adop_parent gen ip r =
  let i = per_index gen r.rval in
  match gen.g_per.arr.(i) with
  | Def.Left _ -> None
  | Def.Right (p, a, u) ->
    if List.mem ip p.related then ()
    else
      begin let p = { p with related = ip :: p.related } in
        gen.g_per.arr.(i) <- Def.Right (p, a, u)
      end;
    Some p.key_index

let set_adop_fam gen ip which_parent fath moth =
  match gen.g_per.arr.(ip) with
  | Def.Left _ -> ()
  | Def.Right (per, asc, uni) ->
      let r_fath =
        match which_parent, fath with
          ("HUSB" | "BOTH"), Some r -> adop_parent gen ip r
        | _ -> None
      in
      let r_moth =
        match which_parent, moth with
          ("WIFE" | "BOTH"), Some r -> adop_parent gen ip r
        | _ -> None
      in
      let r =
        {Def.r_type = Adoption; r_fath = r_fath; r_moth = r_moth;
         r_sources = string_empty}
      in
      let per = { per with rparents = r :: per.rparents } in
      gen.g_per.arr.(ip) <- Def.Right (per, asc, uni)

let forward_godp gen ip rval =
  let ipp = per_index gen rval in gen.g_godp <- (ipp, ip) :: gen.g_godp; ipp

let forward_witn gen ip rval =
  let ifam = fam_index gen rval in
  gen.g_witn <- (ifam, ip) :: gen.g_witn; ifam

let forward_pevent_witn gen ip rval =
  let ipp = per_index gen rval in
  gen.g_prelated <- (ipp, ip) :: gen.g_prelated; ipp

let forward_fevent_witn gen ip rval =
  let ipp = per_index gen rval in
  gen.g_frelated <- (ipp, ip) :: gen.g_frelated; ipp

let indi_lab =
  function
    "ADOP" | "ASSO" | "BAPM" | "BIRT" | "BURI" | "CHR" | "CREM" | "DEAT" |
    "FAMC" | "FAMS" | "NAME" | "NOTE" | "OBJE" | "OCCU" | "SEX" | "SOUR" |
    "TITL" ->
      true
  | c ->
      if List.mem c !state.glop then ()
      else
        begin
          !state.glop <- c :: !state.glop;
          Printf.eprintf "untreated tag %s -> in notes\n" c;
          flush stderr
        end;
      false

let html_text_of_tags text rl =
  let rec tot len lev r =
    let len = Buff.mstore len (string_of_int lev) in
    let len = Buff.store len ' ' in
    let len = Buff.mstore len r.rlab in
    let len =
      if r.rval = "" then len else Buff.mstore (Buff.store len ' ') r.rval
    in
    let len =
      if r.rcont = "" then len else Buff.mstore (Buff.store len ' ') r.rcont
    in
    totl len (lev + 1) r.rsons
  and totl len lev rl =
    List.fold_left
      (fun len r -> let len = Buff.store len '\n' in tot len lev r) len rl
  in
  let title =
    if text = "" then "-- GEDCOM --" else "-- GEDCOM (" ^ text ^ ") --"
  in
  let len = 0 in
  let len = Buff.mstore len title in let len = totl len 1 rl in Buff.get len

let rec find_all_rela nl =
  function
    [] -> []
  | r :: rl ->
      match find_field "RELA" r.rsons with
        Some r1 ->
          let rec loop =
            function
              n :: nl1 ->
                let len = String.length n in
                if String.length r1.rval >= len &&
                   String.lowercase_ascii (String.sub r1.rval 0 len) = n
                then
                  (n, r.rval) :: find_all_rela nl rl
                else loop nl1
            | [] -> find_all_rela nl rl
          in
          loop nl
      | None -> find_all_rela nl rl

let witness_kind_of_rval rval = match rval with
  | "GODP"               -> Def.Witness_GodParent
  | "officer"
  | "Civil officer"
  | "Registry officer"   -> Witness_CivilOfficer
  | "Religious officer"
  | "Officiating priest" -> Witness_ReligiousOfficer
  | "Informant"          -> Witness_Informant
  | "Attending"          -> Witness_Attending
  | "Mentioned"          -> Witness_Mentioned
  | "Other"              -> Witness_Other
  | _                    -> Witness


let find_and_treat_notes gen rsons =
  match find_all_fields "NOTE" rsons with
  | [] -> ""
  | rl -> treat_notes gen rl

let find_event_witness_aux gen i r forward =
  let rec find_witnesses =
    function
    | [] -> []
    | r :: asso_l ->
        let _: bool =
          find_field_with_value "TYPE" "INDI" r.rsons in
        let witness = forward gen i (strip_spaces r.rval) in
        let witness_kind =
          match find_field "RELA" r.rsons with
          | Some rr -> witness_kind_of_rval rr.rval
          | None -> Witness
        in
         let wnote =
           find_and_treat_notes gen r.rsons |> add_string gen
         in
        (witness, witness_kind, wnote) :: find_witnesses asso_l
  in
  let witnesses =
    match find_all_fields "ASSO" r.rsons with
      [] -> []
    | wl -> find_witnesses wl
  in
  Array.of_list witnesses

let find_event_witness gen ip r =
  find_event_witness_aux gen ip r forward_pevent_witn

let find_fevent_witness gen ifath r =
  find_event_witness_aux gen ifath r forward_fevent_witn

let find_pevent_name_from_tag gen tag tagv =
  match tag with
    "BIRT" -> Def.Epers_Birth
  | "BAPM" | "CHR" -> Epers_Baptism
  | "DEAT" -> Epers_Death
  | "BURI" -> Epers_Burial
  | "CREM" -> Epers_Cremation
  | "accomplishment" -> Epers_Accomplishment
  | "acquisition" -> Epers_Acquisition
  | "distinction" -> Epers_Distinction
  | "BAPL" | "lds baptism" -> Epers_BaptismLDS
  | "BARM" -> Epers_BarMitzvah
  | "BASM" -> Epers_BatMitzvah
  | "BLES" -> Epers_Benediction
  | "CENS" -> Epers_Recensement
  | "circumcision" -> Epers_Circumcision
  | "CONF" -> Epers_Confirmation
  | "CONL" | "lds confirmation" -> Epers_ConfirmationLDS
  | "degree" -> Epers_Diploma
  | "DECO" | "award" -> Epers_Decoration
  | "dotationlds" | "lds dotation" | "lds endowment" -> Epers_DotationLDS
  | "EDUC" -> Epers_Education
  | "election" -> Epers_Election
  | "EMIG" -> Epers_Emigration
  | "ENDL" -> Epers_Dotation
  | "excommunication" -> Epers_Excommunication
  | "family link lds" -> Epers_FamilyLinkLDS
  | "FCOM" -> Epers_FirstCommunion
  | "funeral" -> Epers_Funeral
  | "GRAD" -> Epers_Graduate
  | "hospitalization" -> Epers_Hospitalisation
  | "illness" -> Epers_Illness
  | "IMMI" -> Epers_Immigration
  | "membership" -> Epers_Adhesion
  | "military discharge" -> Epers_DemobilisationMilitaire
  | "military distinction" -> Epers_MilitaryDistinction
  | "military promotion" -> Epers_MilitaryPromotion
  | "military service" -> Epers_MilitaryService
  | "military mobilization" -> Epers_MobilisationMilitaire
  | "change name" -> Epers_ChangeName
  | "NATU" -> Epers_Naturalisation
  | "OCCU" | "occupation" -> Epers_Occupation
  | "ORDN" -> Epers_Ordination
  | "passenger list" -> Epers_ListePassenger
  | "PROP" -> Epers_Property
  | "RESI" | "residence" -> Epers_Residence
  | "RETI" -> Epers_Retired
  | "scellent parent lds" -> Epers_ScellentParentLDS
  | "SLGC" | "lds sealing child" -> Epers_ScellentChildLDS
  | "SLGS" | "lds sealing spouse" -> Epers_ScellentSpouseLDS
  | "property sale" -> Epers_VenteBien
  | "WILL" -> Epers_Will
  | _ -> Epers_Name (add_string gen (strip_spaces tagv))

let primary_pevents =
  ["BAPM"; "CHR"; "BAPL"; "BARM"; "BASM"; "BIRT"; "BLES"; "BURI"; "CENS";
   "CONF"; "CONL"; "CREM"; "DEAT"; "DECO"; "EDUC"; "EMIG"; "ENDL"; "FCOM";
   "GRAD"; "IMMI"; "NATU"; "OCCU"; "ORDN"; "PROP"; "RETI"; "RESI"; "SLGS";
   "SLGC"; "WILL"]

let treat_indi_pevent gen ip r =
  let prim_events =
    List.fold_left
      (fun events tag ->
         List.fold_left
           (fun events r ->
              let name = find_pevent_name_from_tag gen tag tag in
              let date =
                match find_field "DATE" r.rsons with
                  Some r -> date_of_field r.rval
                | None -> None
              in
              let place =
                match find_field "PLAC" r.rsons with
                  Some r -> strip_spaces r.rval
                | _ -> ""
              in
              let reason = "" in
              let note = find_and_treat_notes gen r.rsons in
              (* Si le tag 1 XXX a des infos, on les ajoutes. *)
              let note =
                let name_info = strip_spaces r.rval in
                if name_info = "" || r.rval = "Y" then note
                else name_info ^ "<br>\n" ^ note
              in
              let src =
                match find_all_fields "SOUR" r.rsons with
                  [] -> ""
                | rl ->
                    let rec loop first src rl =
                      match rl with
                        [] -> src
                      | r :: rl ->
                          let (src_cont, _) = treat_source gen r in
                          let src =
                            if first then src ^ src_cont
                            else src ^ " " ^ src_cont
                          in
                          loop false src rl
                    in
                    loop true "" rl
              in
              let witnesses = find_event_witness gen ip r in
              let evt =
                {Def.epers_name = name; epers_date = Date.cdate_of_od date;
                 epers_place = add_string gen place;
                 epers_reason = add_string gen reason;
                 epers_note = add_string gen note;
                 epers_src = add_string gen src; epers_witnesses = witnesses}
              in
              (* On ajoute que les évènements non vides, sauf *)
              (* s'il est spécifié qu'il faut l'ajouter.      *)
              if date <> None || place <> "" || note <> "" || src <> "" ||
                 witnesses <> [| |] || r.rval = "Y"
              then
                if name = Epers_Occupation then
                  if r.rsons <> [] then evt :: events else events
                else evt :: events
              else events)
           events (find_all_fields tag r.rsons))
      [] primary_pevents
  in
  let second_events =
    List.fold_left
      (fun events r ->
         match find_field "TYPE" r.rsons with
           Some rr ->
             if rr.rval <> "" then
               let name =
                 if List.mem rr.rval primary_pevents then
                   find_pevent_name_from_tag gen rr.rval rr.rval
                 else
                   find_pevent_name_from_tag gen
                     (String.lowercase_ascii rr.rval) rr.rval
               in
               let date =
                 match find_field "DATE" r.rsons with
                   Some r -> date_of_field r.rval
                 | None -> None
               in
               let place =
                 match find_field "PLAC" r.rsons with
                   Some r -> strip_spaces r.rval
                 | _ -> ""
               in
               let reason = "" in
               let note = find_and_treat_notes gen r.rsons in
               (* Si le tag 1 XXX a des infos, on les ajoutes. *)
               let note =
                 let name_info = strip_spaces r.rval in
                 if name_info = "" || r.rval = "Y" then note
                 else name_info ^ "<br>\n" ^ note
               in
               let src =
                 match find_all_fields "SOUR" r.rsons with
                   [] -> ""
                 | rl ->
                     let rec loop first src rl =
                       match rl with
                         [] -> src
                       | r :: rl ->
                           let (src_cont, _) = treat_source gen r in
                           let src =
                             if first then src ^ src_cont
                             else src ^ " " ^ src_cont
                           in
                           loop false src rl
                     in
                     loop true "" rl
               in
               let witnesses = find_event_witness gen ip r in
               let evt =
                 {Def.epers_name = name; epers_date = Date.cdate_of_od date;
                  epers_place = add_string gen place;
                  epers_reason = add_string gen reason;
                  epers_note = add_string gen note;
                  epers_src = add_string gen src; epers_witnesses = witnesses}
               in
               (* On ajoute que les évènements non vides, *)
               (* sauf si évènement personnalisé !        *)
               let has_epers_name =
                 match name with
                   Epers_Name n -> n <> string_empty
                 | _ -> false
               in
               if has_epers_name || date <> None || place <> "" ||
                  note <> "" || src <> "" || witnesses <> [| |]
               then
                 evt :: events
               else events
             else events
         | None -> events)
      [] (find_all_fields "EVEN" r.rsons)
  in
  List.rev_append prim_events second_events

let rec build_remain_tags =
  function
    [] -> []
  | r :: rest ->
      let rsons = if indi_lab r.rlab then [] else build_remain_tags r.rsons in
      let rest = build_remain_tags rest in
      if r.rused = true && rsons = [] then rest
      else
        {rlab = r.rlab; rval = r.rval; rcont = r.rcont; rsons = rsons;
         rpos = r.rpos; rused = r.rused} ::
        rest

let applycase_surname s =
  match !state.case_surnames with
    NoCase -> s
  | LowerCase -> capitalize_name s
  | UpperCase ->
      if !state.charset = Utf8 then uppercase_name s else String.uppercase_ascii s

let reconstitute_from_pevents pevents bi bp de bu =
  let found_birth = ref false in
  let found_baptism = ref false in
  let found_death = ref false in
  let found_burial = ref false in
  let rec loop pevents bi bp de bu =
    match pevents with
      [] -> bi, bp, de, bu
    | evt :: l ->
        match evt.Def.epers_name with
          Def.Epers_Birth ->
            if !found_birth then loop l bi bp de bu
            else
              let bi =
                evt.epers_date, evt.epers_place, evt.epers_note, evt.epers_src
              in
              let () = found_birth := true in loop l bi bp de bu
        | Epers_Baptism ->
            if !found_baptism then loop l bi bp de bu
            else
              let bp =
                evt.epers_date, evt.epers_place, evt.epers_note, evt.epers_src
              in
              let () = found_baptism := true in loop l bi bp de bu
        | Epers_Death ->
            if !found_death then loop l bi bp de bu
            else
              let death =
                match Date.od_of_cdate evt.epers_date with
                | Some d -> Def.Death (Unspecified, Date.cdate_of_date d)
                | None -> Def.DeadDontKnowWhen
              in
              let de =
                death, evt.epers_place, evt.epers_note, evt.epers_src
              in
              let () = found_death := true in loop l bi bp de bu
        | Epers_Burial ->
            if !found_burial then loop l bi bp de bu
            else
              let bu =
                Def.Buried evt.epers_date, evt.epers_place, evt.epers_note,
                evt.epers_src
              in
              let () = found_burial := true in loop l bi bp de bu
        | Epers_Cremation ->
            if !found_burial then loop l bi bp de bu
            else
              let bu =
                Def.Cremated evt.epers_date, evt.epers_place, evt.epers_note,
                evt.epers_src
              in
              let () = found_burial := true in loop l bi bp de bu
        | _ -> loop l bi bp de bu
  in
  loop pevents bi bp de bu

let add_indi gen r =
  let ip = per_index gen r.rval in
  let name_sons = find_field "NAME" r.rsons in
  let givn =
    match name_sons with
      Some n ->
      begin match find_field "GIVN" n.rsons with
          Some r -> r.rval
        | None -> ""
      end
    | None -> ""
  in
  let (first_name, surname, occ, public_name, first_names_aliases) =
    match name_sons with
    | Some n ->
      let (f, s) = parse_name (Stream.of_string n.rval) in
      let f = string_of_first_name_option f in
      let s = string_of_surname_option s in
      let pn = "" in
      let fal = if givn = f then [] else [givn] in
      let (f, fal) =
        match !state.first_names_brackets with
          Some (bb, eb) ->
          let first_enclosed f =
            let i = String.index f bb in
            let j =
              if i + 2 >= String.length f then raise Not_found
              else String.index_from f (i + 2) eb
            in
            let fn = String.sub f (i + 1) (j - i - 1) in
            let fa =
              String.sub f 0 i ^ fn ^
              String.sub f (j + 1) (String.length f - j - 1)
            in
            fn, fa
          in
          let rec loop first ff accu =
            try
              let (fn, fa) = first_enclosed ff in
              let accu =
                if first then fn
                else if fn <> "" then accu ^ " " ^ fn
                else accu
              in
              loop false fa accu
            with Not_found -> if f = ff then f, fal else accu, ff :: fal
          in
          loop true f ""
        | None -> f, fal
      in
      let (f, pn, fal) =
        if !state.extract_public_names || !state.extract_first_names then
          let i = next_word_pos f 0 in
          let j = next_sep_pos f i in
          if j = String.length f then f, pn, fal
          else
            let fn = String.sub f i (j - i) in
            if pn = "" && !state.extract_public_names then
              if is_a_public_name f j then fn, f, fal
              else if !state.extract_first_names then fn, "", f :: fal
              else f, "", fal
            else fn, pn, f :: fal
        else f, pn, fal
      in
      let f = if !state.lowercase_first_names then capitalize_name f else f in
      let fal =
        if !state.lowercase_first_names then List.map capitalize_name fal else fal
      in
      let pn = if capitalize_name pn = f then "" else pn in
      let pn = if !state.lowercase_first_names then capitalize_name pn else pn in
      let fal =
        List.fold_right (fun fa fal -> if fa = pn then fal else fa :: fal) fal []
      in
      let s = applycase_surname s in
      let r =
        let key = Name.strip_lower (Mutil.nominative f ^ " " ^ Mutil.nominative s) in
        try Hashtbl.find gen.g_hnam key
        with Not_found ->
          let r = ref (-1) in
          Hashtbl.add gen.g_hnam key r ;
          r
      in
      incr r; f, s, !r, pn, fal
    | None -> "?", "?", ip, givn, []
  in
  (* S'il y a des caractères interdits, on les supprime *)
  let (first_name, surname) =
    Name.strip_c first_name ':', Name.strip_c surname ':'
  in
  let qualifier =
    match name_sons with
      Some n ->
      begin match find_field "NICK" n.rsons with
          Some r -> r.rval
        | None -> ""
      end
    | None -> ""
  in
  let surname_aliases =
    match name_sons with
      Some n ->
      begin match find_field "SURN" n.rsons with
          Some r ->
          let list = purge_list (list_of_string r.rval) in
          List.fold_right
            (fun x list ->
               let x = applycase_surname x in
               if x <> surname then x :: list else list)
            list []
        | _ -> []
      end
    | None -> []
  in
  let aliases =
    match find_all_fields "NAME" r.rsons with
    | _ :: l ->
      List.filter_map (fun r ->
          parse_alias (Stream.of_string r.rval)
        ) l
    | _ -> []
  in
  let sex =
    match find_field "SEX" r.rsons with
      Some {rval = "M"} -> Def.Male
    | Some {rval = "F"} -> Female
    | _ -> Neuter
  in
  let image =
    match find_field "OBJE" r.rsons with
      Some r ->
      begin match find_field "FILE" r.rsons with
          Some r -> if !state.no_picture then "" else r.rval
        | None -> ""
      end
    | None -> ""
  in
  let parents =
    match find_field "FAMC" r.rsons with
      Some r -> Some (fam_index gen r.rval)
    | None -> None
  in
  (* On ne prend que les professions sans info supplémentaires. *)
  let occupation =
    let l =
      List.fold_right
        (fun r l -> if r.rsons = [] then strip_spaces r.rval :: l else l)
        (find_all_fields "OCCU" r.rsons) []
    in
    String.concat ", " l
  in
  let notes = find_and_treat_notes gen r.rsons in
  let titles =
    List.map (treat_indi_title gen public_name)
      (find_all_fields "TITL" r.rsons)
  in
  let pevents = treat_indi_pevent gen ip r in
  let family =
    let rl = find_all_fields "FAMS" r.rsons in
    let rvl =
      List.fold_right
        (fun r rvl -> if List.mem r.rval rvl then rvl else r.rval :: rvl) rl
        []
    in
    List.map (fun r -> fam_index gen r) rvl
  in
  let rasso = find_all_fields "ASSO" r.rsons in
  let rparents =
    let godparents = find_all_rela ["godf"; "godm"; "godp"] rasso in
    let godparents =
      if godparents = [] then
        let ro =
          match find_field "BAPM" r.rsons with
            None -> find_field "CHR" r.rsons
          | x -> x
        in
        if ro <> None then find_all_rela ["godf"; "godm"; "godp"] rasso
        else []
      else godparents
    in
    let rec loop rl =
      if rl <> [] then
        let (r_fath, rl) =
          match rl with
            ("godf", r) :: rl -> Some (forward_godp gen ip r), rl
          | _ -> None, rl
        in
        let (r_moth, rl) =
          match rl with
            ("godm", r) :: rl -> Some (forward_godp gen ip r), rl
          | _ -> None, rl
        in
        let (r_fath, r_moth, rl) =
          if r_fath <> None || r_moth <> None then r_fath, r_moth, rl
          else
            let (r_fath, rl) =
              match rl with
                ("godp", r) :: rl -> Some (forward_godp gen ip r), rl
              | _ -> None, rl
            in
            r_fath, None, rl
        in
        let r =
          {Def.r_type = GodParent; r_fath = r_fath; r_moth = r_moth;
           r_sources = string_empty}
        in
        r :: loop rl
      else []
    in
    loop godparents
  in
  let witn = find_all_rela ["witness"] rasso in
  let () =
    List.iter (fun (_, rval) -> (@@) ignore (forward_witn gen ip rval)) witn
  in
  let (birth, birth_place, (birth_note, _), (birth_src, birth_nt)) =
    match find_field "BIRT" r.rsons with
      Some r ->
      let d =
        match find_field "DATE" r.rsons with
          Some r -> date_of_field r.rval
        | _ -> None
      in
      let p =
        match find_field "PLAC" r.rsons with
          Some r -> strip_spaces r.rval
        | _ -> ""
      in
      let note = find_and_treat_notes gen r.rsons in
      d, p, (note, []), source gen r
    | None -> None, "", ("", []), ("", [])
  in
  let (bapt, bapt_place, (bapt_note, _), (bapt_src, bapt_nt)) =
    let ro =
      match find_field "BAPM" r.rsons with
        None -> find_field "CHR" r.rsons
      | x -> x
    in
    match ro with
      Some r ->
      let d =
        match find_field "DATE" r.rsons with
          Some r -> date_of_field r.rval
        | _ -> None
      in
      let p =
        match find_field "PLAC" r.rsons with
          Some r -> strip_spaces r.rval
        | _ -> ""
      in
      let note = find_and_treat_notes gen r.rsons in
      d, p, (note, []), source gen r
    | None -> None, "", ("", []), ("", [])
  in
  let (death, death_place, (death_note, _), (death_src, death_nt)) =
    match find_field "DEAT" r.rsons with
    | Some r ->
      if r.rsons = [] then
        if r.rval = "Y" then Def.DeadDontKnowWhen, "", ("", []), ("", [])
        else infer_death birth bapt, "", ("", []), ("", [])
      else
        let d =
          match find_field "DATE" r.rsons with
            Some r ->
            begin match date_of_field r.rval with
              | Some d -> Def.Death (Unspecified, Date.cdate_of_date d)
              | None -> Def.DeadDontKnowWhen
            end
          | _ -> Def.DeadDontKnowWhen
        in
        let p =
          match find_field "PLAC" r.rsons with
          | Some r -> strip_spaces r.rval
          | None -> ""
        in
        let note = find_and_treat_notes gen r.rsons in
        d, p, (note, []), source gen r
    | None -> infer_death birth bapt, "", ("", []), ("", [])
  in
  let (burial, burial_place, (burial_note, _), (burial_src, burial_nt)) =
    let (buri, buri_place, (buri_note, _), (buri_src, buri_nt)) =
      match find_field "BURI" r.rsons with
        Some r ->
        if r.rsons = [] then
          if r.rval = "Y" then
            Def.Buried Date.cdate_None, "", ("", []), ("", [])
          else UnknownBurial, "", ("", []), ("", [])
        else
          let d =
            match find_field "DATE" r.rsons with
              Some r -> date_of_field r.rval
            | _ -> None
          in
          let p =
            match find_field "PLAC" r.rsons with
              Some r -> strip_spaces r.rval
            | _ -> ""
          in
          let note = find_and_treat_notes gen r.rsons in
          Def.Buried (Date.cdate_of_od d), p, (note, []), source gen r
      | None -> UnknownBurial, "", ("", []), ("", [])
    in
    let (crem, crem_place, (crem_note, _), (crem_src, crem_nt)) =
      match find_field "CREM" r.rsons with
        Some r ->
        if r.rsons = [] then
          if r.rval = "Y" then
            Def.Cremated Date.cdate_None, "", ("", []), ("", [])
          else UnknownBurial, "", ("", []), ("", [])
        else
          let d =
            match find_field "DATE" r.rsons with
              Some r -> date_of_field r.rval
            | _ -> None
          in
          let p =
            match find_field "PLAC" r.rsons with
              Some r -> strip_spaces r.rval
            | _ -> ""
          in
          let note = find_and_treat_notes gen r.rsons in
          Def.Cremated (Date.cdate_of_od d), p, (note, []), source gen r
      | None -> UnknownBurial, "", ("", []), ("", [])
    in
    match buri, crem with
      UnknownBurial, Def.Cremated _ ->
      crem, crem_place, (crem_note, []), (crem_src, crem_nt)
    | _ -> buri, buri_place, (buri_note, []), (buri_src, buri_nt)
  in
  let birth =Date.cdate_of_od birth in
  let bapt =Date.cdate_of_od bapt in
  let (psources, psources_nt) =
    let (s, s_nt) = source gen r in
    if s = "" then !state.default_source, s_nt else s, s_nt
  in
  let ext_notes =
    let concat_text s1 s2 s_sep =
      let s = if s1 = "" && notes = "" || s2 = "" then "" else s_sep in
      s1 ^ s ^ s2
    in
    let text = concat_text "" (notes_from_source_record birth_nt) "<br>\n" in
    let text = concat_text text (notes_from_source_record bapt_nt) "<br>\n" in
    let text =
      concat_text text (notes_from_source_record death_nt) "<br>\n"
    in
    let text =
      concat_text text (notes_from_source_record burial_nt) "<br>\n"
    in
    let text =
      concat_text text (notes_from_source_record psources_nt) "<br>\n"
    in
    if !state.untreated_in_notes then
      let remain_tags_in_notes text init rtl =
        let rtl = build_remain_tags rtl in
        if rtl = [] then init
        else concat_text init (html_text_of_tags text rtl) "\n"
      in
      let nt = remain_tags_in_notes "INDI" "" r.rsons in
      let nt = remain_tags_in_notes "BIRT SOUR" nt birth_nt in
      let nt = remain_tags_in_notes "BAPT SOUR" nt bapt_nt in
      let nt = remain_tags_in_notes "DEAT SOUR" nt death_nt in
      let nt = remain_tags_in_notes "BURI/CREM SOUR" nt burial_nt in
      let nt = remain_tags_in_notes "SOUR SOUR" nt psources_nt in
      if nt = "" then text else text ^ "<pre>\n" ^ nt ^ "\n</pre>"
    else text
  in
  (* Mise à jour des évènements principaux. *)
  let (birth_place, birth_note, birth_src) =
    add_string gen birth_place, add_string gen birth_note,
    add_string gen birth_src
  in
  let (bapt_place, bapt_note, bapt_src) =
    add_string gen bapt_place, add_string gen bapt_note,
    add_string gen bapt_src
  in
  let (death_place, death_note, death_src) =
    add_string gen death_place, add_string gen death_note,
    add_string gen death_src
  in
  let (burial_place, burial_note, burial_src) =
    add_string gen burial_place, add_string gen burial_note,
    add_string gen burial_src
  in
  (* On tri les évènements pour être sûr. *)
  let pevents =
    Geneweb.Event.sort_events (fun evt -> Geneweb.Event.Pevent evt.Def.epers_name)
      (fun evt -> evt.epers_date) pevents
  in
  let (bi, bp, de, bu) =
    reconstitute_from_pevents pevents
      (birth, birth_place, birth_note, birth_src)
      (bapt, bapt_place, bapt_note, bapt_src)
      (death, death_place, death_note, death_src)
      (burial, burial_place, burial_note, burial_src)
  in
  let (birth, birth_place, birth_note, birth_src) = bi in
  let (bapt, bapt_place, bapt_note, bapt_src) = bp in
  let (death, death_place, death_note, death_src) = de in
  let (burial, burial_place, burial_note, burial_src) = bu in
  let person =
    {Def.first_name = add_string gen first_name;
     surname = add_string gen surname; occ = occ;
     public_name = add_string gen public_name; image = add_string gen image;
     qualifiers =
       if qualifier <> "" then [add_string gen qualifier] else [];
     aliases = List.map (add_string gen) aliases;
     first_names_aliases = List.map (add_string gen) first_names_aliases;
     surnames_aliases = List.map (add_string gen) surname_aliases;
     titles = titles; rparents = rparents; related = [];
     occupation = add_string gen occupation; sex = sex;
     access = if !state.no_public_if_titles && titles = [] then Private else IfTitles;
     birth = birth; birth_place = birth_place; birth_note = birth_note;
     birth_src = birth_src; baptism = bapt; baptism_place = bapt_place;
     baptism_note = bapt_note; baptism_src = bapt_src; death = death;
     death_place = death_place; death_note = death_note;
     death_src = death_src; burial = burial; burial_place = burial_place;
     burial_note = burial_note; burial_src = burial_src; pevents = pevents;
     notes = add_string gen (notes ^ ext_notes);
     psources = add_string gen psources; key_index = ip}
  in
  let ascend = {Def.parents = parents; consang = Adef.fix (-1)} in
  let union = {Def.family = Array.of_list family} in
  gen.g_per.arr.(ip) <- Def.Right (person, ascend, union);
  begin match find_field "ADOP" r.rsons with
    | Some r ->
      begin match find_field "FAMC" r.rsons with
        | Some r -> forward_adop gen ip r.rval (find_field "ADOP" r.rsons)
        | _ -> ()
      end
    | _ -> ()
  end;
  r.rused <- true

let find_fevent_name_from_tag gen tag tagv =
  match tag with
    "MARR" -> Def.Efam_Marriage
  | "unmarried" -> Def.Efam_NoMarriage
  | "nomen" -> Efam_NoMention
  | "ENGA" -> Efam_Engage
  | "DIV" -> Efam_Divorce
  | "SEP" | "separation" -> Efam_Separated
  | "ANUL" -> Efam_Annulation
  | "MARB" -> Efam_MarriageBann
  | "MARC" -> Efam_MarriageContract
  | "MARL" -> Efam_MarriageLicense
  | "pacs" -> Efam_PACS
  | "RESI" | "residence" -> Efam_Residence
  | _ -> Efam_Name (add_string gen (strip_spaces tagv))

let primary_fevents =
  ["ANUL"; "DIV"; "ENGA"; "MARR"; "MARB"; "MARC"; "MARL"; "RESI"; "SEP"]

(* Types d'évènement présents seulement dans les tags de niveau 2 (2 TYPE). *)
let secondary_fevent_types = [Def.Efam_NoMarriage; Efam_NoMention]

let treat_fam_fevent gen ifath r =
  let check_place_unmarried efam_name place r =
    match find_all_fields "PLAC" r.rsons with
      r :: rl ->
        if String.uncapitalize_ascii r.rval = "unmarried" then
          Def.Efam_NoMarriage, ""
        else
          let place = strip_spaces r.rval in
          let rec loop =
            function
              r :: rl ->
                if String.uncapitalize_ascii r.rval = "unmarried" then
                  Def.Efam_NoMarriage, place
                else loop rl
            | [] -> efam_name, place
          in
          loop rl
    | [] -> efam_name, place
  in
  let prim_events =
    List.fold_left
      (fun events tag ->
         List.fold_left
           (fun events r ->
              let name = find_fevent_name_from_tag gen tag tag in
              let date =
                match find_field "DATE" r.rsons with
                  Some r -> date_of_field r.rval
                | None -> None
              in
              let place =
                match find_field "PLAC" r.rsons with
                  Some r -> strip_spaces r.rval
                | _ -> ""
              in
              let reason = "" in
              let note = find_and_treat_notes gen r.rsons in
              (* Si le tag 1 XXX a des infos, on les ajoutes. *)
              let note =
                let name_info = strip_spaces r.rval in
                if name_info = "" || r.rval = "Y" then note
                else name_info ^ "<br>\n" ^ note
              in
              let src =
                match find_all_fields "SOUR" r.rsons with
                  [] -> ""
                | rl ->
                    let rec loop first src rl =
                      match rl with
                        [] -> src
                      | r :: rl ->
                          let (src_cont, _) = treat_source gen r in
                          let src =
                            if first then src ^ src_cont
                            else src ^ " " ^ src_cont
                          in
                          loop false src rl
                    in
                    loop true "" rl
              in
              let witnesses = find_fevent_witness gen ifath r in
              (* Vérification du mariage. *)
              let (name, place) =
                match name with
                  Def.Efam_Marriage ->
                    begin match find_field "TYPE" r.rsons with
                      Some r ->
                        if String.uncapitalize_ascii r.rval = "unmarried" then
                          Def.Efam_NoMarriage, place
                        else check_place_unmarried name place r
                    | None -> check_place_unmarried name place r
                    end
                | _ -> name, place
              in
              let evt =
                {Def.efam_name = name; efam_date = Date.cdate_of_od date;
                 efam_place = add_string gen place;
                 efam_reason = add_string gen reason;
                 efam_note = add_string gen note;
                 efam_src = add_string gen src; efam_witnesses = witnesses}
              in
              (* On ajoute toujours les évènements principaux liés à la   *)
              (* famille, sinon, on peut avoir un problème si on supprime *)
              (* l'évènement, celui ci sera remplacé par la relation par  *)
              (* défaut.                                                  *)
              evt :: events)
           events (find_all_fields tag r.rsons))
      [] primary_fevents
  in
  let second_events =
    List.fold_left
      (fun events r ->
         match find_field "TYPE" r.rsons with
           Some rr ->
             if rr.rval <> "" then
               let name =
                 if List.mem rr.rval primary_fevents then
                   find_fevent_name_from_tag gen rr.rval rr.rval
                 else
                   find_fevent_name_from_tag gen
                     (String.lowercase_ascii rr.rval) rr.rval
               in
               let date =
                 match find_field "DATE" r.rsons with
                   Some r -> date_of_field r.rval
                 | None -> None
               in
               let place =
                 match find_field "PLAC" r.rsons with
                   Some r -> strip_spaces r.rval
                 | _ -> ""
               in
               let reason = "" in
               let note = find_and_treat_notes gen r.rsons in
               (* Si le tag 1 XXX a des infos, on les ajoutes. *)
               let note =
                 let name_info = strip_spaces r.rval in
                 if name_info = "" || r.rval = "Y" then note
                 else name_info ^ "<br>\n" ^ note
               in
               let src =
                 match find_all_fields "SOUR" r.rsons with
                   [] -> ""
                 | rl ->
                     let rec loop first src rl =
                       match rl with
                         [] -> src
                       | r :: rl ->
                           let (src_cont, _) = treat_source gen r in
                           let src =
                             if first then src ^ src_cont
                             else src ^ " " ^ src_cont
                           in
                           loop false src rl
                     in
                     loop true "" rl
               in
               let witnesses = find_fevent_witness gen ifath r in
               let evt =
                 {Def.efam_name = name; efam_date = Date.cdate_of_od date;
                  efam_place = add_string gen place;
                  efam_reason = add_string gen reason;
                  efam_note = add_string gen note;
                  efam_src = add_string gen src; efam_witnesses = witnesses}
               in
               (* On n'ajoute que les évènements non vides,        *)
               (* sauf si évènement personnalisé et les évènements *)
               (* des tags de niveau 2 (qui peuvent être vides).   *)
               let has_efam_name =
                 match name with
                   Efam_Name n -> n <> string_empty
                 | _ -> false
               in
               if has_efam_name || date <> None || place <> "" ||
                  note <> "" || src <> "" || witnesses <> [| |] ||
                  List.mem name secondary_fevent_types
               then
                 evt :: events
               else events
             else events
         | None -> events)
      [] (find_all_fields "EVEN" r.rsons)
  in
  List.rev_append prim_events second_events

let reconstitute_from_fevents gen gay fevents marr witn div =
  let found_marriage = ref false in
  let found_divorce = ref false in
  (* On veut cette fois ci que ce soit le dernier évènement *)
  (* qui soit mis dans les évènements principaux.           *)
  let rec loop fevents marr witn div =
    match fevents with
      [] -> marr, witn, div
    | evt :: l ->
        match evt.Def.efam_name with
          Efam_Engage ->
            if !found_marriage then loop l marr witn div
            else
              let witn = Array.map (fun (ip,_,_) -> ip) evt.efam_witnesses in
              let marr =
                Def.Engaged, evt.efam_date, evt.efam_place, evt.efam_note,
                evt.efam_src
              in
              let () = found_marriage := true in loop l marr witn div
        | Def.Efam_Marriage ->
            let witn = Array.map (fun (ip,_,_) -> ip) evt.efam_witnesses in
            let marr =
              Def.Married, evt.efam_date, evt.efam_place, evt.efam_note,
              evt.efam_src
            in
            let () = found_marriage := true in marr, witn, div
        | Efam_MarriageContract ->
            if !found_marriage then loop l marr witn div
            else
              let witn = Array.map (fun (ip,_,_) -> ip) evt.efam_witnesses in
              (* Pour différencier le fait qu'on recopie le *)
              (* mariage, on met une précision "vers".      *)
              let date =
                match Date.od_of_cdate evt.efam_date with
                | Some (Dgreg (dmy, cal)) ->
                    let dmy = {dmy with prec = About} in
                    Date.cdate_of_od (Some (Dgreg (dmy, cal)))
                | _ -> evt.efam_date
              in
              (* Pour différencier le fait qu'on recopie le *)
              (* mariage, on ne met pas de lieu.            *)
              let place = add_string gen "" in
              let marr = Def.Married, date, place, evt.efam_note, evt.efam_src in
              let () = found_marriage := true in loop l marr witn div
        | Efam_NoMention | Efam_MarriageBann | Efam_MarriageLicense |
          Efam_Annulation | Efam_PACS ->
            if !found_marriage then loop l marr witn div
            else
              let witn = Array.map (fun (ip,_,_) -> ip) evt.efam_witnesses in
              let marr =
                Def.NoMention, evt.efam_date, evt.efam_place, evt.efam_note,
                evt.efam_src
              in
              let () = found_marriage := true in loop l marr witn div
        | Def.Efam_NoMarriage ->
            if !found_marriage then loop l marr witn div
            else
              let witn = Array.map (fun (ip,_,_) -> ip) evt.efam_witnesses in
              let marr =
                Def.NotMarried, evt.efam_date, evt.efam_place, evt.efam_note,
                evt.efam_src
              in
              let () = found_marriage := true in loop l marr witn div
        | Efam_Divorce ->
            if !found_divorce then loop l marr witn div
            else
              let div = Def.Divorced evt.efam_date in
              let () = found_divorce := true in loop l marr witn div
        | Efam_Separated ->
            if !found_divorce then loop l marr witn div
            else
              let div = Def.Separated in
              let () = found_divorce := true in loop l marr witn div
        | _ -> loop l marr witn div
  in
  let (marr, witn, div) = loop (List.rev fevents) marr witn div in
  (* Parents de même sexe. *)
  if gay then
    let (relation, date, place, note, src) = marr in
    let relation =
      match relation with
        Def.Married | Def.NoSexesCheckMarried -> Def.NoSexesCheckMarried
      | _ -> Def.NoSexesCheckNotMarried
    in
    let marr = relation, date, place, note, src in marr, witn, div
  else marr, witn, div

let add_fam_norm gen r adop_list =
  let i = fam_index gen r.rval in
  let (fath, moth, gay) =
    match find_all_fields "HUSB" r.rsons, find_all_fields "WIFE" r.rsons with
    | [f1], [m1] -> per_index gen f1.rval, per_index gen m1.rval, false
    | [f1; f2], [] -> per_index gen f1.rval, per_index gen f2.rval, true
    | [], [m1; m2] -> per_index gen m1.rval, per_index gen m2.rval, true
    | _ ->
      let fath =
        match find_field "HUSB" r.rsons with
          Some r -> per_index gen r.rval
        | None -> phony_per gen Def.Male
      in
      let moth =
        match find_field "WIFE" r.rsons with
          Some r -> per_index gen r.rval
        | None -> phony_per gen Female
      in
      fath, moth, false
  in
  begin match gen.g_per.arr.(fath) with
    | Def.Left _ -> ()
    | Def.Right (p, a, u) ->
      let u =
        if not (Array.mem i u.Def.family)
        then { Def.family = Array.append u.Def.family [| i |] }
        else u
      in
      let p = if p.Def.sex = Neuter then { p with sex = Def.Male } else p in
      gen.g_per.arr.(fath) <- Def.Right (p, a, u)
  end ;
  begin match gen.g_per.arr.(moth) with
    | Def.Left _ -> ()
    | Def.Right (p, a, u) ->
      let u =
        if not (Array.mem i u.Def.family)
        then { Def.family = Array.append u.Def.family [| i |] }
        else u
      in
      let p = if p.Def.sex = Neuter then { p with sex = Female } else p in
      gen.g_per.arr.(moth) <- Def.Right (p, a, u)
  end;
  let children =
    let rl = find_all_fields "CHIL" r.rsons in
    List.fold_right begin fun r ipl ->
      let ip = per_index gen r.rval in
      if List.mem_assoc ip adop_list then
        match gen.g_per.arr.(ip) with
        | Def.Right (p, a, u) ->
          begin
            match a.Def.parents with
            | Some ifam when ifam = i ->
              let a = { a with Def.parents = None } in
              gen.g_per.arr.(ip) <- Def.Right (p, a, u) ;
              ipl
            | _ -> ip :: ipl
          end
        | _ -> ip :: ipl
      else ip :: ipl
    end rl []
  in
  let (relation, marr, marr_place, (marr_note, _), (marr_src, marr_nt), witnesses) =
    let (relation, sons) =
      match find_field "MARR" r.rsons with
      | Some r -> if gay then Def.NoSexesCheckMarried, Some r else Def.Married, Some r
      | None ->
        match find_field "ENGA" r.rsons with
        | Some r -> Def.Engaged, Some r
        | None -> !state.relation_status, None
    in
    match sons with
      Some r ->
      let (u, p) =
        match find_all_fields "PLAC" r.rsons with
          r :: rl ->
          if String.uncapitalize_ascii r.rval = "unmarried" then
            Def.NotMarried, ""
          else
            let p = strip_spaces r.rval in
            let rec loop =
              function
                r :: rl ->
                if String.uncapitalize_ascii r.rval = "unmarried" then
                  Def.NotMarried, p
                else loop rl
              | [] -> relation, p
            in
            loop rl
        | [] -> relation, ""
      in
      let u =
        match find_field "TYPE" r.rsons with
          Some r ->
          if String.uncapitalize_ascii r.rval = "gay" then
            Def.NoSexesCheckNotMarried
          else u
        | None -> u
      in
      let d =
        match find_field "DATE" r.rsons with
          Some r -> date_of_field r.rval
        | _ -> None
      in
      let rec heredis_witnesses =
        function
          [] -> []
        | r :: asso_l ->
          if find_field_with_value "RELA" "Witness" r.rsons &&
             find_field_with_value "TYPE" "INDI" r.rsons
          then
            let witness = per_index gen r.rval in
            witness :: heredis_witnesses asso_l
          else begin r.rused <- false; heredis_witnesses asso_l end
      in
      let witnesses =
        match find_all_fields "ASSO" r.rsons with
          [] -> []
        | wl -> heredis_witnesses wl
      in
      let note = find_and_treat_notes gen r.rsons in
      u, d, p, (note, []), source gen r, witnesses
    | None -> relation, None, "", ("", []), ("", []), []
  in
  let witnesses = Array.of_list witnesses in
  let div =
    match find_field "DIV" r.rsons with
      Some r ->
      begin match find_field "DATE" r.rsons with
          Some d -> Def.Divorced (Date.cdate_of_od (date_of_field d.rval))
        | _ ->
          match find_field "PLAC" r.rsons with
            Some _ -> Def.Divorced Date.cdate_None
          | _ ->
            if r.rval = "Y" then Def.Divorced Date.cdate_None else NotDivorced
      end
    | None -> NotDivorced
  in
  let fevents = treat_fam_fevent gen fath r in
  let comment = find_and_treat_notes gen r.rsons in
  let (fsources, fsources_nt) =
    let (s, s_nt) = source gen r in
    if s = "" then !state.default_source, s_nt else s, s_nt
  in
  let concat_text s1 s2 s_sep =
    let s = if s1 = "" then "" else s_sep in s1 ^ s ^ s2
  in
  let ext_sources =
    let text = concat_text "" (notes_from_source_record marr_nt) "<br>\n" in
    concat_text text (notes_from_source_record fsources_nt) "<br>\n"
  in
  let ext_notes =
    if !state.untreated_in_notes then
      let remain_tags_in_notes text init rtl =
        let rtl = build_remain_tags rtl in
        if rtl = [] then init
        else concat_text init (html_text_of_tags text rtl) "\n"
      in
      let nt = remain_tags_in_notes "FAM" "" r.rsons in
      let nt = remain_tags_in_notes "MARR SOUR" nt marr_nt in
      let nt = remain_tags_in_notes "SOUR SOUR" nt fsources_nt in
      if nt = "" then "" else "<pre>\n" ^ nt ^ "\n</pre>"
    else ""
  in
  let add_in_person_notes iper =
    match gen.g_per.arr.(iper) with
    | Def.Left _ -> ()
    | Def.Right (p, a, u) ->
      let notes = gen.g_str.arr.(p.notes) in
      let notes =
        if notes = "" then ext_sources ^ ext_notes
        else if ext_sources = "" then notes ^ "\n" ^ ext_notes
        else notes ^ "<br>\n" ^ ext_sources ^ ext_notes
      in
      let new_notes = add_string gen notes in
      let p = { p with notes = new_notes } in
      gen.g_per.arr.(iper) <- Def.Right (p, a, u)
  in
  let _ =
    if ext_notes = "" then ()
    else begin add_in_person_notes fath; add_in_person_notes moth end
  in
  (* Mise à jour des évènements principaux. *)
  let (marr, marr_place, marr_note, marr_src) =
    Date.cdate_of_od marr, add_string gen marr_place,
    add_string gen marr_note, add_string gen marr_src
  in
  (* On tri les évènements pour être sûr. *)
  let fevents =
    Geneweb.Event.sort_events (fun evt -> Geneweb.Event.Fevent evt.Def.efam_name)
      (fun evt -> evt.efam_date) fevents
  in
  let (marr, witn, div) =
    reconstitute_from_fevents gen gay fevents
      (relation, marr, marr_place, marr_note, marr_src) witnesses div
  in
  let (relation, marr, marr_place, marr_note, marr_src) = marr in
  let witnesses = witn in
  let div = div in
  let fam =
    {Def.marriage = marr; marriage_place = marr_place;
     marriage_note = marr_note; marriage_src = marr_src;
     witnesses = witnesses; relation = relation; divorce = div;
     fevents = fevents; comment = add_string gen comment;
     origin_file = string_empty; fsources = add_string gen fsources;
     fam_index = i}
  and cpl = Adef.couple fath moth
  and des = {Def.children = Array.of_list children} in
  gen.g_fam.arr.(i) <- Def.Right (fam, cpl, des)

let add_fam gen r =
  let list = Hashtbl.find_all gen.g_adop r.rval in
  match list with
    [] -> add_fam_norm gen r []
  | list ->
      let husb = find_field "HUSB" r.rsons in
      let wife = find_field "WIFE" r.rsons in
      List.iter
        (fun (ip, which_parent) -> set_adop_fam gen ip which_parent husb wife)
        list;
      match find_field "CHIL" r.rsons with
        Some _ -> add_fam_norm gen r list
      | _ -> ()

let treat_header2 r =
  begin match find_field "GEDC" r.rsons with
  | Some r ->
     begin match find_field "VERS" r.rsons with
     | Some r ->
        let vs = String.split_on_char '.' r.rval in
        begin match vs with
        | major::_ ->
           let is_major_post7 = (try int_of_string major >= 7 with _ -> false) in
           if is_major_post7 then !state.charset_option <- Some Utf8;
        | _ -> ();
        end
     | None -> ()
     end;
  | None -> ()
  end;
  begin match !state.charset_option with
    Some v -> !state.charset <- v
  | None ->
      match find_field "CHAR" r.rsons with
        Some r ->
          begin match r.rval with
            "ANSEL" -> !state.charset <- Ansel
          | "ASCII" | "IBMPC" -> !state.charset <- Ascii
          | "MACINTOSH" -> !state.charset <- MacIntosh
          | "UTF-8" -> !state.charset <- Utf8
          | _ -> !state.charset <- Ascii
          end
      | None -> ()
  end;
  match find_field "PLAC" r.rsons with
    Some rr ->
      begin match find_field "FORM" rr.rsons with
        Some rrr -> if rrr.rval <> "" then ()
      | None -> ()
      end
  | None -> ()

let treat_header3 gen r =
  match find_all_fields "NOTE" r.rsons with
    [] -> ()
  | rl -> gen.g_bnot <- treat_notes gen rl

let turn_around_genealogos_bug r =
  if String.length r.rlab > 0 && r.rlab.[0] = '@' then
    {r with rlab = r.rval; rval = r.rlab}
  else r

let make_gen2 gen r =
  let r = turn_around_genealogos_bug r in
  match r.rlab with
    "HEAD" -> treat_header2 r
  | "INDI" -> add_indi gen r
  | _ -> ()

let make_gen3 gen r =
  let r = turn_around_genealogos_bug r in
  match r.rlab with
    "HEAD" -> treat_header3 gen r
  | "SUBM" -> ()
  | "INDI" -> ()
  | "FAM" -> add_fam gen r
  | "NOTE" -> ()
  | "SOUR" -> ()
  | "TRLR" -> Printf.eprintf "*** Trailer ok\n"; flush stderr
  | s -> Printf.fprintf !state.log_oc "Not implemented typ = %s\n" s; flush !state.log_oc

let sortable_by_date proj =
  Array.for_all begin fun e -> proj e <> None end

let sort_by_date proj array =
  if sortable_by_date proj array
  then
    Array.stable_sort begin fun e1 e2 ->
      match proj e1, proj e2 with
      | Some d1, Some d2 -> Date.compare_date d1 d2
      | _ -> 1
    end array

let find_lev0 (strm__ : _ Stream.t) =
  let bp = Stream.count strm__ in
  let _ = line_start '0' strm__ in
  let _ =
    try skip_space strm__ with Stream.Failure -> raise (Stream.Error "")
  in
  let r1 =
    try get_ident 0 strm__ with Stream.Failure -> raise (Stream.Error "")
  in
  let r2 =
    try get_ident 0 strm__ with Stream.Failure -> raise (Stream.Error "")
  in
  let _ =
    try skip_to_eoln strm__ with Stream.Failure -> raise (Stream.Error "")
  in
  bp, r1, r2

let open_in_bin_with_bom_check fname =
  let in_channel_has_bom ic =
    try
      Char.code (input_char ic) = 239
      && Char.code (input_char ic) = 187
      && Char.code (input_char ic) = 191
    with End_of_file -> false
  in
  let ic = open_in_bin fname in
  if in_channel_has_bom ic then
    !state.charset_option <- Some Utf8
  else
    seek_in ic 0;
  ic

let pass1 gen fname =
  let ic = open_in_bin_with_bom_check fname in
  let strm = Stream.of_channel ic in
  let rec loop () =
    match try Some (find_lev0 strm) with Stream.Failure -> None with
      Some (bp, r1, r2) ->
        begin match r2 with
          "NOTE" -> Hashtbl.add gen.g_not r1 bp
        | "SOUR" -> Hashtbl.add gen.g_src r1 bp
        | _ -> ()
        end;
        loop ()
    | None ->
        let (strm__ : _ Stream.t) = strm in
        match Stream.peek strm__ with
          Some _ -> Stream.junk strm__; skip_to_eoln strm; loop ()
        | _ -> ()
  in
  loop (); close_in ic

let fill_g_per gen list =
  List.iter begin fun (ipp, ip) ->
    match gen.g_per.arr.(ipp) with
    | Def.Right (p, a, u) when not @@ List.mem ip p.related ->
      let p = { p with related = ip :: p.related } in
      gen.g_per.arr.(ipp) <- Def.Right (p, a, u)
    | _ -> ()
  end list

let pass2 gen fname =
  let ic = open_in_bin_with_bom_check fname in
  !state.line_cnt <- 0;
  let strm =
    Stream.from
      (fun _ ->
         try
           let c = input_char ic in if c = '\n' then
             !state.line_cnt <- succ !state.line_cnt;
             Some c
         with End_of_file -> None)
  in
  let rec loop () =
    match try Some (get_lev0 strm) with Stream.Failure -> None with
      Some r -> make_gen2 gen r; loop ()
    | None ->
        let (strm__ : _ Stream.t) = strm in
        match Stream.peek strm__ with
          Some ('1'..'9') ->
            Stream.junk strm__;
            let (_ : string) = get_to_eoln 0 strm in loop ()
        | Some _ ->
            Stream.junk strm__;
            let (_ : string) = get_to_eoln 0 strm in loop ()
        | _ -> ()
  in
  loop () ;
  fill_g_per gen gen.g_godp ;
  fill_g_per gen gen.g_prelated ;
  close_in ic

let pass3 gen fname =
  let ic = open_in_bin_with_bom_check fname in
  !state.line_cnt <- 0;
  let strm =
    Stream.from
      (fun _ ->
         try
           let c = input_char ic in if c = '\n' then
             !state.line_cnt <- succ !state.line_cnt;
             Some c
         with End_of_file -> None)
  in
  let rec loop () =
    match try Some (get_lev0 strm) with Stream.Failure -> None with
      Some r -> make_gen3 gen r; loop ()
    | None ->
        let (strm__ : _ Stream.t) = strm in
        match Stream.peek strm__ with
          Some ('1'..'9') ->
            Stream.junk strm__;
            let (_ : string) = get_to_eoln 0 strm in loop ()
        | Some c ->
            Stream.junk strm__;
            print_location !state.line_cnt;
            Printf.fprintf !state.log_oc "Strange input '%c' (%i).\n" c (Char.code c);
            flush !state.log_oc;
            let (_ : string) = get_to_eoln 0 strm in loop ()
        | _ -> ()
  in
  loop ();
  List.iter begin fun (ifam, ip) ->
    match gen.g_fam.arr.(ifam) with
    | Def.Right (fam, cpl, des) ->
      begin match gen.g_per.arr.(Adef.father cpl), gen.g_per.arr.(ip) with
        | Def.Right _, Def.Right (p, a, u) ->
          if List.mem (Adef.father cpl) p.related then ()
          else begin
            let p = { p with related = Adef.father cpl :: p.related } in
            gen.g_per.arr.(ip) <- Def.Right (p, a, u)
          end ;
          if Array.mem ip fam.witnesses then ()
          else
            let fam =
              { fam with witnesses = Array.append fam.witnesses [| ip |] }
            in
            gen.g_fam.arr.(ifam) <- Def.Right (fam, cpl, des)
        | _ -> ()
      end
    | _ -> ()
  end gen.g_witn ;
  fill_g_per gen gen.g_frelated ;
  close_in ic

let check_undefined gen =
  for i = 0 to gen.g_per.tlen - 1 do
    match gen.g_per.arr.(i) with
    | Def.Right (_, _, _) -> ()
    | Def.Left lab ->
      let (p, a, u) = unknown_per i Neuter in
      Printf.fprintf !state.log_oc "Warning: undefined person %s\n" lab;
      gen.g_per.arr.(i) <- Def.Right (p, a, u)
  done;
  for i = 0 to gen.g_fam.tlen - 1 do
    match gen.g_fam.arr.(i) with
    | Def.Right (_, _, _) -> ()
    | Def.Left lab ->
      let (f, c, d) = unknown_fam gen i in
      Printf.fprintf !state.log_oc "Warning: undefined family %s\n" lab;
      gen.g_fam.arr.(i) <- Def.Right (f, c, d)
  done

let add_parents_to_isolated gen =
  let ht_missing_children = Hashtbl.create 1001 in
  (* Parfois, l'enfant n'a pas de tag FAMC, mais il est bien présent
     dans la famille. Du coup, si on lui ajoute des parents tout de
     suite, lors du finish base, on va se rendre compte qu'il est en
     trop dans sa "vraie" famille et on va le supprimer, alors qu'on
     veut re-créer la liaison. *)
  let () =
    let rec loop i =
      if i = gen.g_fam.tlen then ()
      else
        match gen.g_fam.arr.(i) with
        | Def.Right (_, _, des) ->
          Array.iter (fun ip -> Hashtbl.add ht_missing_children ip true) des.children ;
            loop (i + 1)
        | Def.Left _ -> loop (i + 1)
    in
    loop 0
  in
  for i = 0 to gen.g_per.tlen - 1 do
    match gen.g_per.arr.(i) with
    | Def.Right (p, a, u) ->
        if a.Def.parents = None
        && Array.length u.Def.family = 0
        && p.rparents = []
        && p.related = []
        && not (Hashtbl.mem ht_missing_children p.key_index)
        then
          let fn = gen.g_str.arr.(p.Def.first_name) in
          let sn = gen.g_str.arr.(p.surname) in
          if fn = "?" && sn = "?" then ()
          else begin
            Printf.fprintf !state.log_oc
              "Adding parents to isolated person: %s.%d %s\n" fn p.occ sn ;
            let ifam = phony_fam gen in
            match gen.g_fam.arr.(ifam) with
            | Def.Right (fam, cpl, _) ->
              let des = { Def.children = [| p.key_index |] } in
              gen.g_fam.arr.(ifam) <- Def.Right (fam, cpl, des);
              let a = { a with Def.parents = Some ifam } in
              gen.g_per.arr.(i) <- Def.Right (p, a, u)
            | _ -> ()
          end
    | Def.Left _ -> ()
  done

let make_arrays in_file =
  let fname =
    if Filename.check_suffix in_file ".ged" then in_file
    else if Filename.check_suffix in_file ".GED" then in_file
    else in_file ^ ".ged"
  in
  let gen =
    {g_per = {arr = [| |]; tlen = 0}; g_fam = {arr = [| |]; tlen = 0};
     g_str = {arr = [| |]; tlen = 0}; g_bnot = ""; g_ic = open_in_bin_with_bom_check fname;
     g_not = Hashtbl.create 3001; g_src = Hashtbl.create 3001;
     g_hper = Hashtbl.create 3001; g_hfam = Hashtbl.create 3001;
     g_hstr = Hashtbl.create 3001; g_hnam = Hashtbl.create 3001;
     g_adop = Hashtbl.create 3001; g_godp = []; g_prelated = [];
     g_frelated = []; g_witn = []}
  in
  assert (add_string gen "" = string_empty);
  assert (add_string gen "?" = string_quest);
  assert (add_string gen "x" = string_x);
  Printf.eprintf "*** pass 1 (note)\n";
  flush stderr;
  pass1 gen fname;
  Printf.eprintf "*** pass 2 (indi)\n";
  flush stderr;
  pass2 gen fname;
  Printf.eprintf "*** pass 3 (fam)\n";
  flush stderr;
  pass3 gen fname;
  close_in gen.g_ic;
  check_undefined gen;
  add_parents_to_isolated gen;
  gen.g_per, gen.g_fam, gen.g_str, gen.g_bnot

let make_subarrays (g_per, g_fam, g_str, g_bnot) =
  let persons =
    let pa = Array.make g_per.tlen (Obj.magic 0) in
    let aa = Array.make g_per.tlen (Obj.magic 0) in
    let ua = Array.make g_per.tlen (Obj.magic 0) in
    for i = 0 to g_per.tlen - 1 do
      match g_per.arr.(i) with
      | Def.Right (p, a, u) -> pa.(i) <- p; aa.(i) <- a; ua.(i) <- u
      | Def.Left lab -> failwith ("undefined person " ^ lab)
    done;
    pa, aa, ua
  in
  let families =
    let fa = Array.make g_fam.tlen (Obj.magic 0) in
    let ca = Array.make g_fam.tlen (Obj.magic 0) in
    let da = Array.make g_fam.tlen (Obj.magic 0) in
    for i = 0 to g_fam.tlen - 1 do
      match g_fam.arr.(i) with
        Def.Right (f, c, d) -> fa.(i) <- f; ca.(i) <- c; da.(i) <- d
      | Def.Left lab -> failwith ("undefined family " ^ lab)
    done;
    fa, ca, da
  in
  let strings = Array.sub g_str.arr 0 g_str.tlen in
  let bnotes =
    {Def.nread = (fun s _ -> if s = "" then g_bnot else ""); norigin_file = "";
     efiles = fun _ -> []}
  in
  persons, families, strings, bnotes

let designation strings p =
  let fn = Mutil.nominative strings.(p.Def.first_name) in
  let sn = Mutil.nominative strings.(p.surname) in
  fn ^ "." ^ string_of_int p.occ ^ " " ^ sn

let check_parents_children persons ascends unions families couples descends strings =
  let prints = Printf.fprintf !state.log_oc in
  let print = Printf.fprintf !state.log_oc in
  let designation = designation strings in
  for i = 0 to Array.length ascends - 1 do
    let a = ascends.(i) in
    begin match a.Def.parents with
      | Some ifam ->
        let fam = families.(ifam) in
        if fam.Def.fam_index = -1
        then ascends.(i) <- { a with Def.parents = None }
        else
          let cpl = couples.(ifam) in
          let des = descends.(ifam) in
          if Array.memq i des.Def.children then ()
          else
            let p = persons.(i) in
            prints "%s is not the child of his/her parents\n" (designation p) ;
            prints "- %s\n" (designation persons.(Adef.father cpl)) ;
            prints "- %s\n" (designation persons.(Adef.mother cpl)) ;
            print "=> no more parents for him/her\n" ;
            print "\n" ;
            flush !state.log_oc ;
            ascends.(i) <- { a with Def.parents = None }
      | None -> ()
    end;
    let u = unions.(i) in
    let fam_to_delete =
      Array.fold_left begin fun acc ifam ->
        let cpl = couples.(ifam) in
        if i <> Adef.father cpl && i <> Adef.mother cpl
        then begin
          let acc =
            prints "%s is spouse in this family but neither husband nor wife:\n"
              (designation persons.(i)) ;
            prints "- %s\n" (designation persons.(Adef.father cpl)) ;
            prints "- %s\n" (designation persons.(Adef.mother cpl)) ;
            let fath = persons.(Adef.father cpl) in
            let moth = persons.(Adef.mother cpl) in
            let ffn = strings.(fath.Def.first_name) in
            let fsn = strings.(fath.surname) in
            let mfn = strings.(moth.Def.first_name) in
            let msn = strings.(moth.surname) in
            if ffn = "?" && fsn = "?" && mfn <> "?" && msn <> "?" then begin
              print "However, the husband is unknown, I set him as husband\n" ;
              unions.(Adef.father cpl) <- {Def.family = [| |]};
              couples.(ifam) <- Adef.couple i (Adef.mother cpl) ;
              acc
            end else if mfn = "?" && msn = "?" && ffn <> "?" && fsn <> "?" then begin
              print "However, the wife is unknown, I set her as wife\n" ;
              unions.(Adef.mother cpl) <- {Def.family = [| |]} ;
              couples.(ifam) <- Adef.couple (Adef.father cpl) i ;
              acc
            end else begin
              print "=> deleted this family for him/her\n" ;
              ifam :: acc
            end
          in
          print "\n";
          flush !state.log_oc ;
          acc
        end else acc
      end [] u.Def.family
    in
    if fam_to_delete <> [] then
      let list =
        Array.fold_right begin fun x acc ->
          if List.mem x fam_to_delete then acc
          else x :: acc
        end u.Def.family []
      in
      unions.(i) <- { Def.family = Array.of_list list }
  done ;
  for i = 0 to Array.length families - 1 do
    let to_delete = ref [] in
    let fam = families.(i) in
    let cpl = couples.(i) in
    let des = descends.(i) in
    Array.iter begin fun ip ->
      let a = ascends.(ip) in
      let p = persons.(ip) in
      match a.Def.parents with
      | Some ifam ->
        if ifam <> i then begin
            prints "Other parents for %s\n" (designation p);
            prints "- %s\n" (designation persons.(Adef.father cpl)) ;
            prints "- %s\n" (designation persons.(Adef.mother cpl)) ;
            print "=> deleted in this family\n" ;
            print "\n" ;
            flush !state.log_oc ;
            to_delete := p.key_index :: !to_delete
          end
      | None ->
        prints "%s has no parents but is the child of\n" (designation p) ;
        prints "- %s\n" (designation persons.(Adef.father cpl)) ;
        prints "- %s\n" (designation persons.(Adef.mother cpl)) ;
        print "=> added parents\n" ;
        print "\n" ;
        flush !state.log_oc ;
        let a = { a with Def.parents = Some fam.Def.fam_index } in
        ascends.(ip) <- a
    end des.Def.children ;
    if !to_delete <> []
    then
      let l =
        Array.fold_right begin fun ip acc ->
          if List.mem ip !to_delete then acc else ip :: acc
        end des.Def.children []
      in
      descends.(i) <- { Def.children = Array.of_list l }
  done

let check_parents_sex persons families couples strings =
  for i = 0 to Array.length couples - 1 do
    let cpl = couples.(i) in
    let fam = families.(i) in
    let ifath = Adef.father cpl in
    let imoth = Adef.mother cpl in
    let fath = persons.(ifath) in
    let moth = persons.(imoth) in
    if fam.Def.relation = Def.NoSexesCheckNotMarried
    || fam.Def.relation = Def.NoSexesCheckMarried
    then ()
    else if fath.Def.sex = Female || moth.Def.sex = Def.Male then
      begin
        if fath.Def.sex = Female
        then
          Printf.fprintf !state.log_oc "Warning - husband with female sex: %s\n"
            (designation strings fath) ;
        if moth.Def.sex = Def.Male
        then
          Printf.fprintf !state.log_oc "Warning - wife with male sex: %s\n"
            (designation strings moth) ;
        flush !state.log_oc ;
        families.(i) <- { fam with relation = Def.NoSexesCheckNotMarried }
      end
    else
      begin
        persons.(ifath) <- { fath with sex = Def.Male } ;
        persons.(imoth) <- { moth with sex = Female }
      end
  done

let neg_year_dmy = function
  | Date.{day = d; month = m; year = y; prec = OrYear dmy2} ->
    let dmy2 = {dmy2 with year2 = -abs dmy2.year2} in
    Date.{day = d; month = m; year = -abs y; prec = OrYear dmy2; delta = 0}
  | {day = d; month = m; year = y; prec = YearInt dmy2} ->
    let dmy2 = {dmy2 with year2 = -abs dmy2.year2} in
    {day = d; month = m; year = -abs y; prec = YearInt dmy2; delta = 0}
  | {day = d; month = m; year = y; prec = p} ->
    {day = d; month = m; year = -abs y; prec = p; delta = 0}

let neg_year = function
  | Date.Dgreg (d, cal) -> Date.Dgreg (neg_year_dmy d, cal)
  | x -> x

let neg_year_cdate cd = Date.cdate_of_date (neg_year (Date.date_of_cdate cd))

let rec negative_date_ancestors persons ascends unions families couples i =
  let p = persons.(i) in
  let p =
    { p with
      Def.birth = begin match Date.od_of_cdate p.Def.birth with
        | Some d1 -> Date.cdate_of_od (Some (neg_year d1))
        | None -> p.Def.birth
      end ;
      death = match p.death with
        | Def.Death (dr, cd2) -> Def.Death (dr, neg_year_cdate cd2)
        | _ -> p.death
    }
  in
  persons.(i) <- p;
  let u = unions.(i) in
  for i = 0 to Array.length u.Def.family - 1 do
    let j = u.Def.family.(i) in
    let fam = families.(j) in
    match Date.od_of_cdate fam.Def.marriage with
    | None -> ()
    | Some d ->
      let fam =
        { fam with Def.marriage = Date.cdate_of_od (Some (neg_year d)) }
      in
      families.(j) <- fam
  done ;
  let a = ascends.(i) in
  match a.Def.parents with
  | None -> ()
  | Some ifam ->
    let cpl = couples.(ifam) in
    negative_date_ancestors
      persons ascends unions families couples (Adef.father cpl) ;
    negative_date_ancestors
      persons ascends unions families couples (Adef.mother cpl)

let negative_dates persons ascends unions families couples =
  for i = 0 to Array.length persons - 1 do
    let p = persons.(i) in
    match Date.cdate_to_dmy_opt p.Def.birth, Date.dmy_of_death p.death with
    | Some d1, Some d2 ->
      if d1.year > 0 && d2.year > 0 && Date.compare_dmy d2 d1 < 0
      then negative_date_ancestors persons ascends unions families couples i
    | _ -> ()
  done

let finish_base (persons, families, strings, _) =
  let (persons, ascends, unions) = persons in
  let (families, couples, descends) = families in
  for i = 0 to Array.length descends - 1 do
    let des = descends.(i) in
    let children = des.Def.children in
    sort_by_date (fun i -> Date.od_of_cdate persons.(i).Def.birth) children ;
    descends.(i) <- { Def.children }
  done ;
  for i = 0 to Array.length unions - 1 do
    let u = unions.(i) in
    let family = u.Def.family in
    sort_by_date (fun i -> Date.od_of_cdate families.(i).Def.marriage) family ;
    unions.(i) <- { family }
  done ;
  for i = 0 to Array.length persons - 1 do
    let p = persons.(i) in
    let a = ascends.(i) in
    let u = unions.(i) in
    if a.Def.parents <> None
    && Array.length u.Def.family != 0
 || p.notes <> string_empty
    then
      let (fn, occ) =
        if strings.(p.Def.first_name) = "?" then string_x, i
        else p.Def.first_name, p.occ
      in
      let (sn, occ) =
        if strings.(p.surname) = "?" then string_x, i
        else p.surname, occ
      in
      persons.(i) <- { p with Def.first_name = fn; surname = sn; occ }
  done;
  check_parents_sex persons families couples strings ;
  check_parents_children persons ascends unions families couples descends strings ;
  if !state.try_negative_dates then negative_dates persons ascends unions families couples

let make_base state' =
  (* set global state;
     we use a global ref for the state because of camlp5 *)
  state := state';
  Secure.set_base_dir (Filename.dirname !state.out_file);
  let arrays = make_arrays !state.in_file in
  Gc.compact ();
  let arrays = make_subarrays arrays in
  finish_base arrays ;
  Gwdb.make !state.out_file !state.particles arrays
