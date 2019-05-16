%%%=============================================================================
%%% @copyright 2016-2017, Erlang Solutions Ltd
%%% @doc Compile and load module on all nodes.
%%% @end
%%%=============================================================================
-module(reshd_compile).
-copyright("2016-2017, Erlang Solutions Ltd.").


-export([compile/1]).

droplast(L, N) when length(L) =< N -> [];
droplast([H|T], N) -> [H|droplast(T, N)].

get_include_opt(SourceFileName) ->
  CurrentDir = filename:split(os:getenv("PWD")),
  RootDir = filename:join(droplast(CurrentDir, 0)), % drop rel/wombat/wombat
  % add <appdir>/include to include dir options
  IncludeDir = filename:join(droplast(filename:split(SourceFileName), 2) ++ ["include"]),
  lists:foldl(
    fun(Dir, Includes) ->
      [{i, filename:join(RootDir, Dir)} | Includes]
    end, [], ["apps", "deps"]) ++ [{i, IncludeDir}].

%%------------------------------------------------------------------------------
%% @doc
%% Compile and load given module on all nodes. On success, returns ok. On
%% compilation error returns error. The compilation errors and warnings
%% are printed on the standard output. If loading the code fails, returns
%% {ResL, BadNodes}.
%% @end
%%------------------------------------------------------------------------------
-spec(compile(SourceFileName::string()) -> ok | error | {[term()], [node()]}).
compile(SourceFileName) ->
  % Get the include path from the already loaded module.
  IncludeOpt = get_include_opt(SourceFileName),
  ExtraSinks = [rabbit_log_mirroring], 
  case compile:file(SourceFileName, [binary, verbose, report, {parse_transform, lager_transform}, {lager_extra_sinks, ExtraSinks} | IncludeOpt]) of
    {ok, ModName, ModBinary} ->
      BinFileName = 
          case code:which(ModName) of
              non_existing -> % new module, where to save?
                  re:replace(SourceFileName, ".erl", ".beam", [{return, list}]);
              FileName ->
                  FileName
          end,
      io:format("Writing file to: ~p~n", [BinFileName]),
      code:load_binary(ModName, BinFileName, ModBinary),
      file:write_file(BinFileName, ModBinary);
    error ->
      error
  end.


