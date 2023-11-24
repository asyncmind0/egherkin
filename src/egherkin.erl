%% Copyright (c) 2018, Jabberbees SAS

%% Permission to use, copy, modify, and/or distribute this software for any
%% purpose with or without fee is hereby granted, provided that the above
%% copyright notice and this permission notice appear in all copies.

%% THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
%% WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
%% MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
%% ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
%% WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
%% ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
%% OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

%% @author Emmanuel Boutin <emmanuel.boutin@jabberbees.com>

-module(egherkin).

-export([lexer/1, from_lexer/1, parse/1, parse_file/1]).

-define(is_gwt(V), ((V == <<"Given">>)
  orelse (V == <<"When">>)
  orelse (V == <<"Then">>)
  orelse (V == <<"And">>)
  orelse (V == <<"But">>))).

-define(is_white(C), ((C == $\s) orelse (C == $\t))).

-define(is_crlf(C), ((C == $\r) orelse (C == $\n))).

lexer(Source) ->
  lexer(Source, {keepwhite, <<>>}, []).

lexer(<<>>, _Text, Result) ->
  lists:reverse(Result);

lexer(<<$#, S/binary>>, {keepwhite, _White}, Result) ->
  lexer(S, skipcomment, Result);
lexer(<<"Feature:", S/binary>>, {keepwhite, _White}, Result) ->
  lexer(S, skipwhite, [<<"Feature:">> | Result]);
lexer(<<"Background:", S/binary>>, {keepwhite, _White}, Result) ->
  lexer(S, skipwhite, [<<"Background:">> | Result]);
lexer(<<"Scenario Outline:", S/binary>>, {keepwhite, _White}, Result) ->
  lexer(S, skipwhite, [<<"Scenario Outline:">> | Result]);
lexer(<<"Scenario:", S/binary>>, {keepwhite, _White}, Result) ->
  lexer(S, skipwhite, [<<"Scenario:">> | Result]);
lexer(<<"Examples:", S/binary>>, {keepwhite, _White}, Result) ->
  lexer(S, skipwhite, [examples_keyword | Result]);
lexer(<<"Given", S/binary>>, {keepwhite, _White}, Result) ->
  lexer(S, skipwhite, [<<"Given">> | Result]);
lexer(<<"When", S/binary>>, {keepwhite, _White}, Result) ->
  lexer(S, skipwhite, [<<"When">> | Result]);
lexer(<<"Then", S/binary>>, {keepwhite, _White}, Result) ->
  lexer(S, skipwhite, [<<"Then">> | Result]);
lexer(<<"And", S/binary>>, {keepwhite, _White}, Result) ->
  lexer(S, skipwhite, [<<"And">> | Result]);
lexer(<<"But", S/binary>>, {keepwhite, _White}, Result) ->
  lexer(S, skipwhite, [<<"But">> | Result]);
lexer(<<"\"\"\"", S/binary>>, {keepwhite, _White}, Result) ->
  lexer(S, skipwhite, [<<"\"\"\"">> | Result]);
lexer(<<$@, S/binary>>, {keepwhite, _White}, Result) ->
  lexer(S, skipwhite, [<<"@">> | Result]);
lexer(<<"\n", S/binary>>, {keepwhite, _White}, Result) ->
  lexer(S, {keepwhite, <<>>}, [<<"\n">> | Result]);
lexer(<<C, S/binary>>, {keepwhite, _White}, Result) when ?is_crlf(C) ->
  lexer(S, {keepwhite, <<>>}, [<<"\n">> | Result]);
lexer(<<C, S/binary>>, {keepwhite, White}, Result) when ?is_white(C) ->
  lexer(S, {keepwhite, <<White/binary, C>>}, Result);
lexer(<<C, S/binary>>, {keepwhite, _White}, Result) ->
  lexer(S, {keeptext, <<C>>, <<>>}, Result);

lexer(<<"\n", S/binary>>, skipcomment, Result) ->
  lexer(S, {keepwhite, <<>>}, [<<"\n">> | Result]);
lexer(<<C, S/binary>>, skipcomment, Result) when ?is_crlf(C) ->
  lexer(S, {keepwhite, <<>>}, [<<"\n">> | Result]);
lexer(<<_, S/binary>>, skipcomment, Result) ->
  lexer(S, skipcomment, Result);

lexer(<<"\n", S/binary>>, skipwhite, Result) ->
  lexer(S, {keepwhite, <<>>}, [<<"\n">> | Result]);
lexer(<<C, S/binary>>, skipwhite, Result) when ?is_crlf(C) ->
  lexer(S, {keepwhite, <<>>}, [<<"\n">> | Result]);
lexer(<<C, S/binary>>, skipwhite, Result) when ?is_white(C) ->
  lexer(S, skipwhite, Result);
lexer(<<C, S/binary>>, skipwhite, Result) ->
  lexer(S, {keeptext, <<C>>, <<>>}, Result);

lexer(<<"\n", S/binary>>, {keeptext, Text, _White}, Result) ->
  lexer(S, {keepwhite, <<>>}, [<<"\n">>, Text | Result]);
lexer(<<C, S/binary>>, {keeptext, Text, _White}, Result) when ?is_crlf(C) ->
  lexer(S, <<>>, [<<"\n">>, Text | Result]);
%lexer(<<$@, S/binary>>, {keeptext, <<>>, _White}, Result) ->
%  lexer(S, skipwhite, [<<"@">> | Result]);
%lexer(<<$@, S/binary>>, {keeptext, Text, _White}, Result) ->
%  lexer(S, skipwhite, [<<"@">>, Text | Result]);
lexer(<<C, S/binary>>, {keeptext, Text, White}, Result) when ((C == $\s) orelse (C == $\t)) ->
  lexer(S, {keeptext, Text, <<White/binary, C>>}, Result);
lexer(<<C, S/binary>>, {keeptext, Text, White}, Result) ->
  lexer(S, {keeptext, <<Text/binary, White/binary, C>>, <<>>}, Result).

from_lexer(L) ->
  Parsers = [
    fun parse_headers/2,
    fun parse_tags/2,
    fun parse_feature_line/2,
    fun parse_background/2,
    fun parse_scenario_definitions/2,
    fun parse_eof/2
  ],
  case p_seq(Parsers, L, 1) of
  {failed, _, _} = Failed ->
    Failed;
  {[Headers, Tags, {Name, Description}, Background, Scenarios, _EOF], _, _} ->
    {Headers, Tags, Name, Description, Background, Scenarios}
  end.

parse(Source) ->
  Lexed = lexer(<<Source/binary, "\n">>),
  from_lexer(Lexed).

parse_file(Filename) ->
  case file:read_file(Filename) of
  {ok, Source} -> parse(Source);
  Else -> Else
  end.

parse_headers(L, Line) ->
  parse_headers(L, Line, []).

parse_headers([sharp_sign, Comment, <<"\n">> | L], Line, Headers) when is_binary(Comment) ->
  parse_headers(L, Line+1, [{Line, Comment} | Headers]);
parse_headers(L, Line, Headers) ->
  {lists:reverse(Headers), L, Line}.

parse_tags(L, Line) ->
  parse_tags(L, Line, []).

parse_tags([<<"@">>, Name, <<"\n">> | L], Line, Tags) when is_binary(Name) ->
  parse_tags(L, Line+1, [{Line, Name} | Tags]);
parse_tags([<<"@">>, Name | L], Line, Tags) when is_binary(Name) ->
  parse_tags(L, Line, [{Line, Name} | Tags]);
parse_tags([<<"\n">> | L], Line, Tags) ->
  parse_tags(L, Line+1, Tags);
parse_tags(L, Line, Tags) ->
  {lists:reverse(Tags), L, Line}.

parse_feature_line([<<"Feature:">>, Name, <<"\n">> | L], Line) when is_binary(Name) ->
  case parse_comments(L, Line+1) of
  {failed, _, _} = Failed -> Failed;
  {Comments, L2, Line2} -> {{Name, Comments}, L2, Line2}
  end;
parse_feature_line(L, Line) when is_binary(L)->
    parse_feature_line(lexer(L), Line);
    
parse_feature_line(_, Line) ->
  {failed, Line, "expected 'Feature:' keyword"}.

parse_comments(L, Line) ->
  parse_comments(L, Line, []).

parse_comments([Comment, <<"\n">> | L], Line, Comments) when is_binary(Comment) ->
  parse_comments(L, Line+1, [Comment | Comments]);
parse_comments(L, Line, Comments) ->
  {lists:reverse(Comments), L, Line}.

parse_background([<<"\n">> | L], Line) ->
  parse_background(L, Line+1);
parse_background([<<"Background:">>, <<"\n">> | L], Line) ->
  case parse_steps(L, Line+1) of
  {failed, _, _} = Failed ->
    Failed;
  {Steps, L2, Line2} ->
    {{Line, Steps}, L2, Line2}
  end;
parse_background(L, Line) ->
  {undefined, L, Line}.

parse_scenario_definitions(L, Line) ->
  parse_scenario_definitions(L, Line, []).

parse_scenario_definitions([] = L, Line, Scenarios) ->
  {lists:reverse(Scenarios), L, Line};
parse_scenario_definitions([<<"\n">> | L], Line, Scenarios) ->
  parse_scenario_definitions(L, Line+1, Scenarios);
parse_scenario_definitions(L, Line, Scenarios) ->
  Parsers = [
    fun parse_tags/2,
    fun parse_scenario_definition/2
  ],
  case p_seq(Parsers, L, Line) of
  {failed, _, _} = Failed ->
    Failed;
  {[Tags, {Loc, Name, Steps}], L2, Line2} ->
    Scenario = {Loc, Name, Tags, Steps},
    parse_scenario_definitions(L2, Line2, [Scenario | Scenarios]);
  {[Tags, {Loc, Name, Steps, Examples}], L2, Line2} ->
    Scenario = {Loc, Name, Tags, Steps, Examples},
    parse_scenario_definitions(L2, Line2, [Scenario | Scenarios])
  end.

parse_scenario_definition([<<"Scenario:">>, Name, <<"\n">> | L], Line) when is_binary(Name) ->
  case parse_steps(L, Line+1) of
  {failed, _, _} = Failed ->
    Failed;
  {Steps, L2, Line2} ->
    {{Line, Name, Steps}, L2, Line2}
  end;
parse_scenario_definition([<<"Scenario Outline:">>, Name, <<"\n">> | L], Line) when is_binary(Name) ->
  Parsers = [
    fun parse_steps/2,
    fun parse_examples/2
  ],
  case p_seq(Parsers, L, Line+1) of
  {failed, _, _} = Failed ->
    Failed;
  {[Steps, Examples], L2, Line2} ->
    {{Line, Name, Steps, Examples}, L2, Line2}
  end;
parse_scenario_definition(L, Line) when is_binary(L) ->
    parse_scenario_definition(lexer(L), Line);
parse_scenario_definition(_, Line) ->
  {failed, Line, "expected 'Scenario:' or 'Scenario Outline:'"}.

parse_steps(L, Line) ->
  parse_steps(L, Line, []).

parse_steps([GWT, StepLine, <<"\n">> | L], Line, Steps) when ?is_gwt(GWT) andalso is_binary(StepLine) ->
  StepParts = parse_step_line(StepLine),
  Parsers = [
    fun skip_crlfs/2,
    fun parse_step_args/2
  ],
  case p_seq(Parsers, L, Line+1) of
  {failed, _, _} = Failed ->
    Failed;
  {[_, undefined], L2, Line2} ->
    parse_steps(L2, Line2, [{Line, GWT, StepParts} | Steps]);
  {[_, StepArgs], L2, Line2} ->
    parse_steps(L2, Line2, [{Line, GWT, StepParts ++ [StepArgs]} | Steps])
  end;
parse_steps([<<"\n">> | L], Line, Steps) ->
  parse_steps(L, Line+1, Steps);
parse_steps(L, Line, Steps) ->
  {lists:reverse(Steps), L, Line}.

parse_step_line(S) ->
  parse_step_line(S, <<>>, []).

parse_step_line(<<>>, <<>>, Result) ->
  lists:reverse(Result);
parse_step_line(<<>>, Part, Result) ->
  lists:reverse([Part | Result]);
parse_step_line(<<C:8, S/binary>>, <<>>, Result) when ?is_white(C) ->
  parse_step_line(S, <<>>, Result);
parse_step_line(<<C:8, S/binary>>, Part, Result) when ?is_white(C) ->
  parse_step_line(S, <<>>, [Part | Result]);
parse_step_line(<<C:8, S/binary>>, Part, Result) ->
  parse_step_line(S, <<Part/binary, C:8>>, Result).

parse_step_args([<<"\"\"\"">>, <<"\n">> | L], Line) ->
  parse_docstring(L, Line+1);
parse_step_args([<<$|, _/binary>>, <<"\n">> | _] = L, Line) ->
  parse_datatable(L, Line);
parse_step_args(L, Line) ->
  {undefined, L, Line}.

parse_docstring(L, Line) ->
  parse_docstring(L, Line, []).

parse_docstring([<<"\"\"\"">>, <<"\n">> | L], Line, Result) ->
  {{docstring, lists:reverse(Result)}, L, Line+1};
parse_docstring([String, <<"\n">> | L], Line, Result) when is_binary(String) ->
  parse_docstring(L, Line+1, [<<String/binary, "\n">> | Result]);
parse_docstring([<<"Then">> | L], Line, Result) ->
  String = <<"Then">>,
  parse_docstring(L, Line+1, [String | Result]);
parse_docstring([<<"\n">> | L], Line, Result) ->
  String = <<"\n">>,
  parse_docstring(L, Line+1, [String | Result]);
parse_docstring([Doc| Rest], Line, Result) ->
  parse_docstring(Rest, Line+1, [Doc | Result]);
parse_docstring([], Line, Result) ->
  {failed, Line, "expected '\"\"\"'" ++ Result}.

parse_datatable(L, Line) ->
  parse_datatable(L, Line, []).

parse_datatable([<<$|, _/binary>> = Row, <<"\n">> | L], Line, Result) ->
  parse_datatable(L, Line+1, [{Line, Row} | Result]);
parse_datatable([<<"\n">> | L], Line, Result) ->
  parse_datatable(L, Line+1, Result);
parse_datatable(L, Line, Result) ->
  case parse_datatable_lines(lists:reverse(Result)) of
  {failed, _, _} = Failed ->
    Failed;
  {Headers, Rows} ->
    DataTable = egherkin_datatable:new(Headers, Rows),
    {DataTable, L, Line}
  end.

parse_examples([<<"\n">> | L], Line) ->
  parse_examples(L, Line+1);
parse_examples([examples_keyword, <<"\n">> | L], Line) ->
  parse_datatable(L, Line+1);
parse_examples(_, Line) ->
  {failed, Line, "expected 'Examples:'"}.

skip_crlfs([<<"\n">> | L], Line) ->
  skip_crlfs(L, Line+1);
skip_crlfs(L, Line) ->
  {undefined, L, Line}.

parse_eof([], Line) ->
  {eof, [], Line};
parse_eof(_, Line) ->
  {failed, Line, "expected end of file"}.

parse_datatable_lines(Lines) ->
  [Headers | Rows] = lists:map(fun parse_datatable_line/1, Lines),
  collect_datatable_rows(Rows, Headers, []).

collect_datatable_rows([], {_, Names}, Result) ->
  {Names, lists:reverse(Result)};
collect_datatable_rows([{Line, Row} | Rows], {_, Names} = Headers, Result) ->
  if length(Row) == length(Names) ->
    collect_datatable_rows(Rows, Headers, [Row | Result]);
  true ->
    {failed, Line, "column count mismatch"}
  end.

parse_datatable_line({Line, S}) ->
  {Line, parse_datatable_line(S, skip, [])}.

parse_datatable_line(<<>>, _, Result) ->
  lists:reverse(Result);

parse_datatable_line(<<$|, S/binary>>, skip, _) ->
  parse_datatable_line(S, skip, []);
parse_datatable_line(<<C, S/binary>>, skip, Result) when ?is_white(C) ->
  parse_datatable_line(S, skip, Result);
parse_datatable_line(<<C, S/binary>>, skip, Result) ->
  parse_datatable_line(S, {keep, <<C>>, <<>>}, Result);

parse_datatable_line(<<$|, S/binary>>, {keep, Text, _}, Result) ->
  parse_datatable_line(S, skip, [Text | Result]);
parse_datatable_line(<<C, S/binary>>, {keep, Text, White}, Result) when ?is_white(C) ->
  parse_datatable_line(S, {keep, Text, <<White/binary, C>>}, Result);
parse_datatable_line(<<$\\, C, S/binary>>, {keep, Text, White}, Result) ->
  parse_datatable_line(S, {keep, <<Text/binary, White/binary, C>>, <<>>}, Result);
parse_datatable_line(<<C, S/binary>>, {keep, Text, White}, Result) ->
  parse_datatable_line(S, {keep, <<Text/binary, C>>, White}, Result).

p_seq(Parsers, L, Line) ->
  p_seq(Parsers, L, Line, []).

p_seq([], L, Line, Result) ->
  {lists:reverse(Result), L, Line};
p_seq([Parser | Parsers], L, Line, Result) ->
  case Parser(L, Line) of
  {failed, _, _} = Failed -> Failed;
  {Item, L2, Line2} -> p_seq(Parsers, L2, Line2, [Item | Result])
  end.
