open Def
open Gwdb

type 'a event_name =
  | Pevent of 'a Def.gen_pers_event_name
  | Fevent of 'a Def.gen_fam_event_name

let pevent_name s = Pevent s
let fevent_name s = Fevent s

type 'a event_item =
  | PE of Gwdb.pers_event * 'a event_name
  | FE of Gwdb.fam_event * 'a event_name * iper option
  | DPE of (iper, istr) Def.gen_pers_event * 'a event_name
  | DFE of (iper, istr) Def.gen_fam_event * 'a event_name * iper option

let wrap p f defp deff (e : 'a event_item) =
  match e with
  | PE (e, _) -> p e
  | FE (e, _, _) -> f e
  | DPE (e, _) -> defp e
  | DFE (e, _, _) -> deff e

let get_name = function
  | PE (_, name) | FE (_, name, _) -> name
  | DPE (_, name) | DFE (_, name, _) -> name

let get_date ei =
  wrap get_pevent_date get_fevent_date
    (fun e -> e.epers_date)
    (fun e -> e.efam_date)
    ei

let get_place ei =
  wrap get_pevent_place get_fevent_place
    (fun e -> e.epers_place)
    (fun e -> e.efam_place)
    ei

let get_note ei =
  wrap get_pevent_note get_fevent_note
    (fun e -> e.epers_note)
    (fun e -> e.efam_note)
    ei

let get_src ei =
  wrap get_pevent_src get_fevent_src
    (fun e -> e.epers_src)
    (fun e -> e.efam_src)
    ei

let get_witnesses ei =
  wrap get_pevent_witnesses get_fevent_witnesses
    (fun e -> Array.map (fun (a, b, _) -> (a, b)) e.epers_witnesses)
    (fun e -> Array.map (fun (a, b, _) -> (a, b)) e.efam_witnesses)
    ei

let get_witness_notes ei =
  wrap get_pevent_witness_notes get_fevent_witness_notes
    (fun e -> Array.map (fun (_, _, n) -> n) e.epers_witnesses)
    (fun e -> Array.map (fun (_, _, n) -> n) e.efam_witnesses)
    ei

let get_witnesses_and_notes ei =
  wrap get_pevent_witnesses_and_notes get_fevent_witnesses_and_notes
    (fun e -> e.epers_witnesses)
    (fun e -> e.efam_witnesses)
    ei

let get_spouse_iper ei =
  match ei with PE _ | DPE _ -> None | FE (_, _, sp) | DFE (_, _, sp) -> sp

(*let get_witnesses_and_notes ei =
  let get_notes i = match ei.witness_notes with
    | Some notes when Array.length notes > 0 -> notes.(i)
    | _ -> empty_string
  in
  Array.init (Array.length ei.witnesses) (fun i ->
      let ip, wk = ei.witnesses.(i) in
      ip, wk, get_notes i
    )
*)
let has_witnesses ei =
  let nb_witnesses =
    match ei with
    | PE _ | FE (_, _, _) -> Array.length (get_witnesses ei)
    | DPE (e, _) -> Array.length e.epers_witnesses
    | DFE (e, _, _) -> Array.length e.efam_witnesses
  in
  nb_witnesses > 0

let has_witness_note ei =
  match ei with
  | PE (e, _) ->
      Array.exists
        (fun n -> not (is_empty_string n))
        (get_pevent_witness_notes e)
  | FE (e, _, _) ->
      Array.exists
        (fun n -> not (is_empty_string n))
        (get_fevent_witness_notes e)
  | DPE (e, _) ->
      Array.exists (fun (_, _, n) -> not (is_empty_string n)) e.epers_witnesses
  | DFE (e, _, _) ->
      Array.exists (fun (_, _, n) -> not (is_empty_string n)) e.efam_witnesses

let event_item_of_pevent pe = PE (pe, pevent_name (Gwdb.get_pevent_name pe))

let event_item_of_fevent ~sp fe =
  FE (fe, fevent_name (Gwdb.get_fevent_name fe), sp)

let event_item_of_gen_pevent evt = DPE (evt, pevent_name evt.epers_name)
let event_item_of_gen_fevent ~sp evt = DFE (evt, fevent_name evt.efam_name, sp)

(*
   On ignore les événements personnalisés.
   Dans l'ordre de priorité :
     birth, baptism, ..., death, funeral, burial/cremation.
   Pour les évènements familiaux, cet ordre est envisageable :
     engage, PACS, marriage bann, marriage contract, marriage, ...,
     separate, divorce
*)
let compare_event_name name1 name2 =
  match (name1, name2) with
  | Pevent Epers_Birth, _ -> -1
  | _, Pevent Epers_Birth -> 1
  | ( Pevent Epers_Baptism,
      Pevent (Epers_Death | Epers_Funeral | Epers_Burial | Epers_Cremation) ) ->
      -1
  | ( Pevent (Epers_Death | Epers_Funeral | Epers_Burial | Epers_Cremation),
      Pevent Epers_Baptism ) ->
      1
  | Pevent Epers_Cremation, Pevent Epers_Burial -> -1
  | Pevent (Epers_Burial | Epers_Cremation), _ -> 1
  | _, Pevent (Epers_Burial | Epers_Cremation) -> -1
  | Pevent Epers_Funeral, _ -> 1
  | _, Pevent Epers_Funeral -> -1
  | Pevent Epers_Death, _ -> 1
  | _, Pevent Epers_Death -> -1
  | _, _ -> 0

let int_of_fevent_name = function
  | Efam_NoMarriage -> 0
  | Efam_PACS -> 1
  | Efam_Engage -> 2
  | Efam_MarriageBann -> 3
  | Efam_MarriageContract -> 4
  | Efam_MarriageLicense -> 5
  | Efam_Marriage -> 6
  | Efam_Residence -> 7
  | Efam_Separated -> 8
  | Efam_Annulation -> 9
  | Efam_Divorce -> 10
  | Efam_NoMention -> 11
  | Efam_Name s -> 12

let compare_fevent_name name1 name2 =
  let i1 = int_of_fevent_name name1 in
  let i2 = int_of_fevent_name name2 in
  i1 - i2

let better_compare_event_name name1 name2 =
  let c = compare_event_name name1 name2 in
  if c <> 0 then c
  else
    match (name1, name2) with
    (* put Fevent after Pevent *)
    | Fevent _, Pevent _ -> 1
    | Pevent _, Fevent _ -> -1
    (* this is to make event order stable; depends on type definition order! *)
    | Fevent e1, Fevent e2 -> compare_fevent_name e1 e2
    | Pevent e1, Pevent e2 -> compare e1 e2

(* try to handle the fact that events are not well ordered *)
let sort_events get_name get_date events =
  let dated, undated =
    List.fold_left
      (fun (dated, undated) e ->
        match Date.cdate_to_dmy_opt (get_date e) with
        | None -> (dated, e :: undated)
        | Some _d -> (e :: dated, undated))
      ([], []) events
  in
  (* we need this to keep the input with same date ordered
     by their creation order *)
  let dated, undated = (List.rev dated, List.rev undated) in

  (* this do not define a preorder (no transitivity);
     can not be used to sort a list
     ex:
      let a,b,c events with
        a.date = Some 2022;
        b.date = None;
        c.date = Some 2000;
      we can have a <= b and b <= c because of event name.
      but we do not have a <= c
  *)
  let cmp e1 e2 =
    let cmp_name e1 e2 =
      better_compare_event_name (get_name e1) (get_name e2)
    in
    match Date.cdate_to_dmy_opt (get_date e1) with
    | None -> cmp_name e1 e2
    | Some d1 -> (
        match Date.cdate_to_dmy_opt (get_date e2) with
        | None -> cmp_name e1 e2
        | Some d2 ->
            let x = Date.compare_dmy d1 d2 in
            if x = 0 then cmp_name e1 e2 else x)
  in

  (* sort events with dates separately to make sure
     that dates are in correct order *)
  let l1 = List.stable_sort cmp dated in
  let l2 = List.stable_sort cmp undated in
  List.merge cmp l1 l2

let events conf base p =
  if not (Util.authorized_age conf base p) then []
  else
    let pevents = List.map event_item_of_pevent (get_pevents p) in
    let events =
      (* append fevents *)
      Array.fold_right
        (fun ifam events ->
          let fam = foi base ifam in
          let isp = Gutil.spouse (get_iper p) fam in
          (* filter family event with contemporary spouse *)
          let m_auth =
            Util.authorized_age conf base (Util.pget conf base isp)
          in
          if not m_auth then events
          else
            List.fold_right
              (fun fe events ->
                event_item_of_fevent ~sp:(Some isp) fe :: events)
              (get_fevents fam) events)
        (get_family p) pevents
    in
    events

let sorted_events conf base p =
  let unsorted_events = events conf base p in
  sort_events get_name get_date unsorted_events
