-module(aeplugin_dev_mode_app).
-behavior(application).

-export([ start/2,
          start_phase/3,
          stop/1 ]).

-export([ check_env/0 ]).

-define(PLUGIN_NAME_STR, "aeplugin_dev_mode").

start(_Type, _Args) ->
    {ok, Pid} = aeplugin_dev_mode_sup:start_link(),
    ok = start_http_api(),
    {ok, Pid}.

start_phase(check_config, _Type, _Args) ->
    case aeu_env:find_config([<<"system">>, <<"plugins">>], [user_config, schema_default]) of
        {ok, Objs} ->
            case [Conf ||
                     #{<<"name">> := <<?PLUGIN_NAME_STR>>, <<"config">> := Conf}
                         <- Objs] of
                [Config] ->
                    check_config(Config);
                [] ->
                    lager:warning("Could not fetch plugin config object (~p)",
                                  [?PLUGIN_NAME_STR]),
                    ok
            end;
        _ ->
                    lager:warning("Could not fetch plugin config object (~p)",
                                  [?PLUGIN_NAME_STR]),
                    ok
    end.

stop(_State) ->
    ok.

check_env() ->
    %% start_trace(),
    case aec_conductor:get_beneficiary() of
        {ok, _} ->
            ok;
        {error, beneficiary_not_configured} ->
            lager:warning("Beneficiary not configured. Dev mode may not work", [])
    end,
    ok.

start_http_api() ->
    Port = get_http_api_port(),
    Dispatch = cowboy_router:compile(aeplugin_dev_mode_handler:routes()),
    {ok, _} = cowboy:start_clear(devmode_listener,
                                 [{port, Port}],
                                 #{env => #{dispatch => Dispatch}}),
    ok.

get_http_api_port() ->
    list_to_integer(os:getenv("AE_DEVMODE_PORT", "3313")).

check_config(Config0) ->
    {ok, AppName} = application:get_application(),
    SchemaF = filename:join(code:priv_dir(AppName),
                            "aeplugin_dev_mode_config_schema.json"),
    {ok, Config} = aeu_plugins:validate_config(Config0, SchemaF),
    maybe_set_keyblock_interval(Config),
    maybe_set_microblock_interval(Config),
    maybe_set_auto_emit(Config),
    ok.


maybe_set_keyblock_interval(#{<<"keyblock_interval">> := Interval}) ->
    aeplugin_dev_mode_emitter:set_keyblock_interval(Interval);
maybe_set_keyblock_interval(_) ->
    ok.

maybe_set_microblock_interval(#{<<"microblock_interval">> := Interval}) ->
    aeplugin_dev_mode_emitter:set_microblock_interval(Interval);
maybe_set_microblock_interval(_) ->
    ok.

maybe_set_auto_emit(#{<<"auto_emit_microblocks">> := Bool}) ->
    aeplugin_dev_mode_emitter:auto_emit_microblocks(Bool);
maybe_set_auto_emit(_) ->
    ok.
