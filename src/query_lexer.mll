(*****************************************************************************)
(* Lexer                                                                     *)
(*****************************************************************************)

{

open Lexing
open Query_parser

let keywords_list = 
    [("match", MATCH); ("do", DO); ("yield", DO); ("and", AND);
     ("with", WITH); ("last", LAST); ("first", FIRST);
     ("before", BEFORE); ("after", AFTER); 
     ("time", TIME); ("nphos", NPHOS); ("rule", RULE); ("count", COUNT);
     ("component", COMPONENT); ("dist", DIST); ("size", SIZE);
     ("query", QUERY)]

let ktab = 
    let t = Hashtbl.create 20 in 
    keywords_list |> List.iter (fun (k, v) ->
        Hashtbl.add t k v) ;
    t

let kword_or_id s = 
    try Hashtbl.find ktab s with Not_found -> ID s

let newline lexbuf =
    let pos = lexbuf.lex_curr_p in
    lexbuf.lex_curr_p <- 
      { pos with pos_lnum = pos.pos_lnum + 1; pos_bol = pos.pos_cnum }

}

let letter = ['a'-'z' 'A'-'Z']
let digit = ['0'-'9']
let non_null_digit = ['1'-'9']

let integer = non_null_digit digit*

let ident = (letter | '_') (letter | '_' | digit)*

let space = [' ' '\t']

rule token = parse
  | "'" ([^'\'']* as s) "'"  {STRING s}
  | "\"" ([^'"']* as s) "\"" {STRING s}
  | space {token lexbuf}
  | "\n" {new_line lexbuf; token lexbuf}
  | "#" {comment lexbuf}

  | "(" {OP_PAR}
  | ")" {CL_PAR}
  | "{" {OP_CURL}
  | "}" {CL_CURL}
  | "[" {OP_SQPAR}
  | "]" {CL_SQPAR}
  | "|" {BAR}
  | "!" {LINK}
  | "~" {INT_STATE}


  | ":" {COLON}
  | "," {COMMA}
  | "." {DOT}
  | "_" {UNDERSCORE}

  | "<" {LT}
  | "<=" {LE}
  | ">" {GT}
  | ">=" {GE}
  | "+" {PLUS}
  | "-" {MINUS}
  | "*" {MULT}
  
  | "0" {INT 0}
  | (non_null_digit digit*) as s {INT (int_of_string s)}
  | ident as s {kword_or_id s}

  | eof {EOF}


and comment = parse
  | "\n" { new_line lexbuf ;token lexbuf }
  | eof {EOF}
  | _ {comment lexbuf}