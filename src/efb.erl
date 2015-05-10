-module(efb).

%% API exports
-export([send_notification/2]).
-export([send_notification/3]).

-define(EFB_API_URL, "https://graph.facebook.com").

-type result() :: ok | {error, any()}.

%%====================================================================
%% API functions
%%====================================================================

-spec send_notification(non_neg_integer() | binary(), binary()) -> ok.
send_notification(UserId, Template) ->
    send_notification(UserId, Template, <<"">>).

-spec send_notification(non_neg_integer() | binary(), binary(), binary()) -> ok.
send_notification(UserId, Template, Href) when is_integer(UserId) ->
    send_notification(integer_to_binary(UserId), Template, Href);
send_notification(UserId, Template, Href) ->
    Result = request(send_notification, #{ user_id => UserId,
                                           template => Template,
                                           href => Href
                                         }),
    case Result of
        {ok, _} -> ok;
        {error, _Reason} = Error -> Error
    end.

%%====================================================================
%% Internal functions
%%====================================================================

-spec request(atom(), map()) -> result().
request(Action, Params) ->
    case get_access_token() of
        {ok, AccessToken} ->
            {Method, URL} = gen_url_and_method(Action, AccessToken, Params),
            hreq(Method, URL);
        {error, _Reason} = Error ->
            Error
    end.

-spec gen_url_and_method(atom(), binary(), map()) -> {atom(), binary()}.
gen_url_and_method(send_notification, AccessToken, Params) ->
    {post, iolist_to_binary([?EFB_API_URL,
                             "/", maps:get(user_id, Params),
                             "/notifications?access_token=", AccessToken,
                             "&template=", maps:get(template, Params),
                             "&href=", maps:get(href, Params)])}.

-spec get_access_token() -> result().
get_access_token() ->
    ClientId = application:get_env(efb, client_id, undefined),
    ClientSecret = application:get_env(efb, client_secret, undefined),
    get_access_token(ClientId, ClientSecret).

-spec get_access_token(string(), string()) -> result().
get_access_token(ClientId, ClientSecret) when is_list(ClientId),
                                              is_list(ClientSecret) ->
    URL = iolist_to_binary([?EFB_API_URL, "/oauth/access_token?",
                            "client_id=", ClientId,
                            "&client_secret=", ClientSecret,
                            "&grant_type=client_credentials"]),
    case hreq(get, URL) of
        {ok, <<"access_token=", AccessToken/binary>>} ->
            {ok, AccessToken};
        {ok, Response} ->
            {error, Response};
        {error, _Reason} = Error ->
            Error
    end.

-spec hreq(atom, binary()) -> any().
hreq(Method, URL) ->
    case hackney:Method(URL) of
        {ok, 200, _Hrds, Ref} ->
            hackney:body(Ref);
        Any ->
            Any
    end.
