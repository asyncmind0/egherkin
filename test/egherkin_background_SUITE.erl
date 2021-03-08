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

-module(egherkin_background_SUITE).

-compile(export_all).

-include_lib("common_test/include/ct.hrl").
-include_lib("assert.hrl").

init_per_suite(Config) -> Config.

end_per_suite(Config) -> Config.

init_per_testcase(_TestCase, Config) -> Config.

end_per_testcase(_TestCase, Config) -> Config.

all() -> [steps_works].

%%region steps

steps_works(_) ->
  Feature = test_data:parse_output(background),
  Background = egherkin_feature:background(Feature),
  ?assertMatch(
    [
      {
        3,
        given_keyword,
        [<<"I">>, <<"have">>, <<"entered">>, <<"50">>, <<"into">>, <<"the">>, <<"calculator">>]
      },
      {
        4,
        and_keyword,
        [<<"I">>, <<"have">>, <<"entered">>, <<"70">>, <<"into">>, <<"the">>, <<"calculator">>]
      },
      {5, when_keyword, [<<"I">>, <<"press">>, <<"add">>]},
      {
        6,
        then_keyword,
        [
          <<"the">>,
          <<"result">>,
          <<"should">>,
          <<"be">>,
          <<"120">>,
          <<"on">>,
          <<"the">>,
          <<"screen">>
        ]
      }
    ],
    egherkin_background:steps(Background)
  ),
  ok.

%%endregion
