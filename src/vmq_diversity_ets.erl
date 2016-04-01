-module(vmq_diversity_ets).

-export([install/1]).

-import(luerl_lib, [badarg_error/3]).


install(St) ->
    luerl_emul:alloc_table(table(), St).

table() ->
    [
     {<<"insert">>, {function, fun insert/2}},
     {<<"insert_new">>, {function, fun insert_new/2}},
     {<<"lookup">>, {function, fun lookup/2}},
     {<<"delete">>, {function, fun delete/2}},
     {<<"delete_all">>, {function, fun delete_all/2}},
     {<<"ensure_table">>, {function, fun ensure_table/2}}
    ].

insert([BTableId, ObjectOrObjects] = As, St) when is_binary(BTableId) ->
    TableId = table_id(BTableId, As, St),
    case luerl:decode(ObjectOrObjects, St) of
        [{K, _}|_] = OObjects when is_binary(K) ->
            {[ets:insert(TableId, OObjects)], St}
    end.

insert_new([BTableId, ObjectOrObjects] = As, St) when is_binary(BTableId) ->
    TableId = table_id(BTableId, As, St),
    case luerl:decode(ObjectOrObjects, St) of
        [{K, _}|_] = OObjects when is_binary(K) ->
            {[ets:insert_new(TableId, OObjects)], St}
    end.

lookup([BTableId, Key] = As, St) when is_binary(BTableId) ->
    TableId = table_id(BTableId, As, St),
    KKey = luerl:decode(Key, St),
    Result0 = ets:lookup(TableId, KKey),
    {_, Vals} = lists:unzip(Result0),
    {Result1, NewSt} = luerl:encode(Vals, St),
    {[Result1], NewSt}.

delete([BTableId, Key] = As, St) when is_binary(BTableId) ->
    TableId = table_id(BTableId, As, St),
    KKey = luerl:decode(Key, St),
    {[ets:delete(TableId, KKey)], St}.

delete_all([BTableId] = As, St) when is_binary(BTableId) ->
    TableId = table_id(BTableId, As, St),
    {[ets:delete_all_objects(TableId)], St}.

ensure_table(As, St) ->
    case As of
        [Config0|_] ->
            case luerl:decode(Config0, St) of
                Config when is_list(Config) ->
                    Options = vmq_diversity_utils:map(Config),
                    Name = vmq_diversity_utils:str(maps:get(<<"name">>,
                                                               Options,
                                                               "simple_kv")),
                    Type = vmq_diversity_utils:atom(maps:get(<<"type">>,
                                                                Options,
                                                                set)),
                    AName = list_to_atom("vmq-diversity-ets" ++ Name),
                    NewOptions = [Type],
                    vmq_diversity_sup:start_all_pools(
                      [{kv, [{id, AName}, {opts, NewOptions}]}], []),

                    % return to lua
                    {[true], St};
                _ ->
                    badarg_error(execute_parse, As, St)
            end;
        _ ->
            badarg_error(execute_parse, As, St)
    end.

table_id(BTableName, As, St) ->
    try list_to_existing_atom("vmq-diversity-ets" ++ binary_to_list(BTableName)) of
        ATableName -> ATableName
    catch
        _:_ ->
            lager:error("unknown pool ~p", [BTableName]),
            badarg_error(unknown_pool, As, St)
    end.
