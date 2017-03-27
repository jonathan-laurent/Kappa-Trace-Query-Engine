(*****************************************************************************)
(* Measures                                                                  *)
(*****************************************************************************)

open Query

let rule_name model = function
    | Trace.Rule (r, _, _) -> 
        let name = Format.asprintf "%a" (Model.print_rule ~env:model) r in
        Some (Val (name, String))
    | _ -> None

let component ag_id state = 
    match state.Replay.connected_components with
    | None -> None
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

let take_measures 
    (model : Model.t) 
    (ev : Query.event) 
    (ag_matchings : int array)
    (prev_state, step, next_state : Replay.state * Trace.step * Replay.state)
    (set_measure : int -> value option -> unit)
    : unit =

    let take_measure m_id {measure_descr;_} =
        let v = 
            match measure_descr with
            | State_measure (time, ty, st_measure) ->
                let state = 
                    begin match time with
                    | Before -> prev_state
                    | After -> next_state
                    end in
                begin match st_measure with
                | Count _ -> None
                | Component ag_id -> 
                    component ag_matchings.(ag_id) state (* Absurd *)
                | Nphos _ -> None
                end
            | Event_measure (ty, ev_measure) -> 
                begin match ev_measure with
                | Time -> time next_state
                | Rule -> rule_name model step
                end in
            set_measure m_id v
         in

     Array.iteri take_measure ev.measures