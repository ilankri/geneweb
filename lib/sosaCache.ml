open Def
open Gwdb

let has_children base u =
  Array.exists
    (fun ifam ->
       let des = foi base ifam in Array.length (get_children des) > 0)
    (get_family u)

(* Optimisation de find_sosa_aux :                                           *)
(* - ajout d'un cache pour conserver les descendants du sosa que l'on calcul *)
(* - on sauvegarde la dernière génération où l'on a arrêté le calcul pour    *)
(*   ne pas reprendre le calcul depuis la racine                             *)

(* Type pour ne pas créer à chaque fois un tableau tstab et mark *)
type sosa_t =
  { tstab : (Gwdb.iper, int) Gwdb.Marker.t;
    mark : (Gwdb.iper, bool) Gwdb.Marker.t;
    mutable last_zil : (Gwdb.iper * Sosa.t) list;
    sosa_ht : (Gwdb.iper, (Sosa.t * Gwdb.person) option) Hashtbl.t }

let init_sosa_t conf base sosa_ref =
  try
    let tstab = Util.create_topological_sort conf base in
    let mark = Gwdb.iper_marker (Gwdb.ipers base) false in
    let last_zil = [get_iper sosa_ref, Sosa.one] in
    let sosa_ht = Hashtbl.create 5003 in
    Hashtbl.add sosa_ht (get_iper sosa_ref) (Some (Sosa.one, sosa_ref)) ;
    Some {tstab = tstab; mark = mark; last_zil = last_zil; sosa_ht = sosa_ht}
  with Consang.TopologicalSortError _ -> None

let find_sosa_aux conf base a p t_sosa =
  let cache = ref [] in
  let has_ignore = ref false in
  let ht_add ht k v new_sosa =
    match try Hashtbl.find ht k with Not_found -> v with
      Some (z, _) -> if not (Sosa.gt new_sosa z) then Hashtbl.replace ht k v
    | _ -> ()
  in
  let rec gene_find =
    function
      [] -> Def.Left []
    | (ip, z) :: zil ->
        let _ = cache := (ip, z) :: !cache in
        if ip = get_iper a then Right z
        else if Gwdb.Marker.get t_sosa.mark ip then gene_find zil
        else
          begin
            Gwdb.Marker.set t_sosa.mark ip true;
            if Gwdb.Marker.get t_sosa.tstab (get_iper a)
               <= Gwdb.Marker.get t_sosa.tstab ip
            then
              let _ = has_ignore := true in gene_find zil
            else
              let asc = Util.pget conf base ip in
              match get_parents asc with
                Some ifam ->
                  let cpl = foi base ifam in
                  let z = Sosa.twice z in
                  begin match gene_find zil with
                    Left zil ->
                      Left
                        ((get_father cpl, z) ::
                         (get_mother cpl, Sosa.inc z 1) :: zil)
                  | Right z -> Right z
                  end
              | None -> gene_find zil
          end
  in
  let rec find zil =
    match
      try gene_find zil with
        Invalid_argument msg when msg = "index out of bounds" ->
          Update.delete_topological_sort conf base; Left []
    with
      Left [] ->
        let _ =
          List.iter
            (fun (ip, _) -> Gwdb.Marker.set t_sosa.mark ip false)
            !cache
        in
        None
    | Left zil ->
        let _ =
          if !has_ignore then ()
          else
            begin
              List.iter
                (fun (ip, z) -> ht_add t_sosa.sosa_ht ip (Some (z, p)) z) zil;
              t_sosa.last_zil <- zil
            end
        in
        find zil
    | Right z ->
        let _ =
          List.iter
            (fun (ip, _) -> Gwdb.Marker.set t_sosa.mark ip false)
            !cache
        in
        Some (z, p)
  in
  find t_sosa.last_zil

let find_sosa conf base a sosa_ref t_sosa =
  match sosa_ref with
    Some p ->
      if get_iper a = get_iper p then Some (Sosa.one, p)
      else
        let u = Util.pget conf base (get_iper a) in
        if has_children base u then
          try Hashtbl.find t_sosa.sosa_ht (get_iper a) with
            Not_found -> find_sosa_aux conf base a p t_sosa
        else None
  | None -> None

(* [Type]: (iper, Sosa.t) Hashtbl.t *)
let sosa_ht = Hashtbl.create 5003

let build_sosa_tree_ht conf base person =
  let () = load_ascends_array base in
  let () = load_couples_array base in
  let nb_persons = nb_of_persons base in
  let mark = Gwdb.iper_marker (Gwdb.ipers base) false in
  (* Tableau qui va stocker au fur et à mesure les ancêtres de person. *)
  (* Attention, on créé un tableau de la longueur de la base + 1 car on *)
  (* commence à l'indice 1 !                                            *)
  let sosa_accu =
    Array.make (nb_persons + 1) (Sosa.zero, dummy_iper)
  in
  let () = Array.set sosa_accu 1 (Sosa.one, get_iper person) in
  let rec loop i len =
    if i > nb_persons then ()
    else
      let (sosa_num, ip) = Array.get sosa_accu i in
      (* Si la personne courante n'a pas de numéro de sosa, alors il n'y *)
      (* a plus d'ancêtres car ils ont été ajoutés par ordre croissant.  *)
      if Sosa.eq sosa_num Sosa.zero then ()
      else
        begin
          Hashtbl.add sosa_ht ip sosa_num;
          let asc = Util.pget conf base ip in
          (* Ajoute les nouveaux ascendants au tableau des ancêtres. *)
          match get_parents asc with
            Some ifam ->
              let cpl = foi base ifam in
              let z = Sosa.twice sosa_num in
              let len =
                if not @@ Gwdb.Marker.get mark (get_father cpl) then
                  begin
                    Array.set sosa_accu (len + 1) (z, get_father cpl);
                    Gwdb.Marker.set mark (get_father cpl) true;
                    len + 1
                  end
                else len
              in
              let len =
                if not @@ Gwdb.Marker.get mark (get_mother cpl) then
                  begin
                    Array.set sosa_accu (len + 1) (Sosa.inc z 1, get_mother cpl);
                    Gwdb.Marker.set mark (get_mother cpl) true ;
                    len + 1
                  end
                else len
              in
              loop (i + 1) len
          | None -> loop (i + 1) len
        end
  in
  loop 1 1

let build_sosa_ht conf base =
  match Util.find_sosa_ref conf base with
    Some sosa_ref -> build_sosa_tree_ht conf base sosa_ref
  | None -> ()

let next_sosa s =
  (* La clé de la table est l'iper de la personne et on lui associe son numéro
    de sosa. On inverse pour trier sur les sosa *)
  let sosa_list = Hashtbl.fold (fun k v acc -> (v, k) :: acc) sosa_ht [] in
  let sosa_list = List.sort (fun (s1, _) (s2, _) -> Sosa.compare s1 s2) sosa_list in
  let rec find_n x lst = match lst with
    | [] -> (Sosa.zero, dummy_iper)
    | (so, _) :: tl ->
        if (Sosa.eq so x) then
          if tl = [] then (Sosa.zero, dummy_iper) else List.hd tl
        else find_n x tl
  in
  let (so, ip) = find_n s sosa_list in
  (so, ip)

let prev_sosa s =
  let sosa_list = Hashtbl.fold (fun k v acc -> (v, k) :: acc) sosa_ht [] in
  let sosa_list = List.sort (fun (s1, _) (s2, _) -> Sosa.compare s1 s2) sosa_list in
  let sosa_list = List.rev sosa_list in
  let rec find_n x lst = match lst with
    | [] -> (Sosa.zero, dummy_iper)
    | (so, _) :: tl ->
        if (Sosa.eq so x) then
          if tl = [] then (Sosa.zero, dummy_iper) else List.hd tl
        else find_n x tl
  in
  let (so, ip) = find_n s sosa_list in
  (so, ip)

let get_sosa_person p =
  try Hashtbl.find sosa_ht (get_iper p) with Not_found -> Sosa.zero

let get_single_sosa conf base p =
  match Util.find_sosa_ref conf base with
  | None -> Sosa.zero
  | Some p_sosa as sosa_ref ->
    match init_sosa_t conf base p_sosa with
    | None -> Sosa.zero
    | Some t_sosa ->
      match find_sosa conf base p sosa_ref t_sosa with
      | Some (z, _) -> z
      | None -> Sosa.zero

let print_sosa conf base p link =
  let sosa_num = get_sosa_person p in
  if Sosa.gt sosa_num Sosa.zero then
    match Util.find_sosa_ref conf base with
      Some ref ->
        if not link then ()
        else
          begin let sosa_link =
              let i1 = string_of_iper (get_iper p) in
              let i2 = string_of_iper (get_iper ref) in
              let b2 = Sosa.to_string sosa_num in
              "m=RL&i1=" ^ i1 ^ "&i2=" ^ i2 ^ "&b1=1&b2=" ^ b2
            in
            Output.print_sstring conf {|<a href="|} ;
            Output.print_string conf (Util.commd conf) ;
            Output.print_string conf (sosa_link |> Adef.safe) ;
            Output.print_sstring conf {|"> |};
          end;
        let title =
          if Util.is_hide_names conf ref && not (Util.authorized_age conf base ref) then
            ""
          else
            let direct_ancestor =
              Name.strip_c (p_first_name base ref) '"' ^ " " ^
              Name.strip_c (p_surname base ref) '"'
            in
            Printf.sprintf (Util.fcapitale (Util.ftransl conf "direct ancestor of %s"))
              direct_ancestor ^
            Printf.sprintf ", Sosa: %s"
              (Sosa.to_string_sep (Util.transl conf "(thousand separator)") sosa_num)
        in
        Output.print_sstring conf {|<img src="|} ;
        Output.print_string conf (Image.prefix conf) ;
        Output.print_string conf (title |> Adef.safe) ;
        Output.print_sstring conf {|"> |};
        if not link then () else 
                Output.print_sstring conf "</a> "
    | None -> ()