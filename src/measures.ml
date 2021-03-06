(*****************************************************************************)
(* Measures                                                                  *)
(*****************************************************************************)

open Query
open Streaming

let rule_name model =
    let ret s = Some (Val (s, String)) in
    function
        | Trace.Rule (r, _, _) ->
            let name = Format.asprintf "%a"
                (Model.print_rule ~noCounters:false ~env:model) r in
            ret name
        | Trace.Init  _ -> ret "_init_"
        | Trace.Dummy _ -> ret "_dummy_"
        | Trace.Subs  _ -> ret "_subs_"
        | Trace.Pert  _ -> ret "_pert_"
        | Trace.Obs   _ -> ret "_obs_"

let component ag_id state =
    match state.Replay.connected_components with
    | None -> Printf.printf "No connected component information available" ; None
    | Some ccs ->
        let cc_id = Edges.get_connected_component ag_id state.Replay.graph in
        begin match Utils.bind_option cc_id (fun cc_id -> Mods.IntMap.find_option cc_id ccs) with
        | None ->
            begin
                Printf.printf "`cc_id` is equal to None: %b\n" (cc_id = None) ;
                assert false (* Bug from `Replay` ? *)
            end
        | Some cc ->
            (* assert (Agent.SetMap.Set.exists (fun (ag_id', _) -> ag_id = ag_id') cc) ; *)
            Some (Val (cc, Agent_set))
        end

let time state = Some (Val (state.Replay.time, Float))


let int_state model ((ag_id, ag_kind), ag_site) state =
    let st = try Edges.get_internal ag_id ag_site state.Replay.graph
        with _ -> begin
            Format.printf "(%d, %d), %d \n\n" ag_id ag_kind ag_site ;
            Format.printf "%d\n\n" state.Replay.event ;
            Edges.debug_print Format.std_formatter state.Replay.graph ;
            Format.printf "\n" ;
            assert false
        end in
    let signature = Model.signatures model in
    Some (Val (Format.asprintf "%a" (Signature.print_internal_state signature ag_kind ag_site) st, String))

let take_snapshot ?uuid model state file =
    let graph = state.Replay.graph in
    let signature = Model.signatures model in
    let snapshot = Edges.build_snapshot signature graph in
    let snapshot = {
        Data.snapshot_file = file ;
        Data.snapshot_event = state.Replay.event ;
        Data.snapshot_time = state.Replay.time  ;
        Data.snapshot_agents = Snapshot.export ~debugMode:true signature snapshot ;
        Data.snapshot_tokens = [||] } in
    let oc = open_out file in
    if !Tql_output.snapshots_native_format then begin
        let fmt = Format.formatter_of_out_channel oc in
        Data.print_snapshot ?uuid fmt snapshot
    end
    else begin
        let outbuf = Bi_outbuf.create_channel_writer oc in
        Data.write_snapshot outbuf snapshot ;
        Bi_outbuf.flush_channel_writer outbuf
    end ;

    close_out oc

let print_cc model state ag_id =
    let edges = state.Replay.graph in
    let ugraph =
        Edges.species ~debugMode:false (Model.signatures model) ag_id edges in
    let str =
        Format.asprintf "@[<h>%a@]" User_graph.print_cc ugraph in
    Some (Val (str, String))

let take_measures
    ?(uuid : int option)
    (model : Model.t)
    (ev : Query.event)
    (ag_matchings : int array)
    (w : Streaming.window)
    (set_measure : int -> value option -> unit)
    : unit =

    let take_measure m_id {measure_descr;_} =
        let v =
            match measure_descr with
            | State_measure (time, _ty, st_measure) ->
                let state =
                    begin match time with
                    | Before -> w.previous_state
                    | After -> w.state
                    end in
                begin match st_measure with
                | Count _ -> None
                | Component ag_id ->
                    component ag_matchings.(ag_id) state (* Absurd *)
                | Nphos _ -> None
                | Int_state ((ag_id, ag_kind), ag_site) ->
                    int_state model ((ag_matchings.(ag_id), ag_kind), ag_site) state
                | Snapshot ->
                    let filename = Tql_output.new_snapshot_file () in
                    take_snapshot ?uuid model state filename ;
                    Some (Val (filename, String))
                | Print_cc ag_id ->
                    print_cc model state ag_matchings.(ag_id)
                end
            | Event_measure (_ty, ev_measure) ->
                begin match ev_measure with
                | Time -> time w.state
                | Rule -> rule_name model w.step
                | Init_event -> Some (Val (Trace.step_is_init w.step, Bool))
                end in
            set_measure m_id v
         in

     Array.iteri take_measure ev.measures
