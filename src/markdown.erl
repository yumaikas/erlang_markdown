%% Copyright (c) 2009 Will Larson <lethain@gmail.com>
%% <insert MIT License here>
-module(markdown).
-author("Will Larson <lethain@gmail.com>").
-version("0.0.1").
-export([markdown/1]).
-export([toggle_tag/3, exclusive_insert_tag/3]).
-export([parse_link/2, parse_link_text/2]).

markdown(Text) when is_list(Text) ->
    markdown(list_to_binary(Text));
markdown(Binary) when is_binary(Binary) ->
    markdown(Binary, [], [], []).

markdown(<<"">>, OpenTags, Acc, _Context) ->
    ClosedTags = lists:foldr(fun(Tag, Acc2) ->
				     [<<"</",Tag/binary,">">> | Acc2]
			     end, Acc, lists:reverse(OpenTags)),
    % markdown is gathered in reverse order
    Reversed = lists:reverse(ClosedTags),
    list_to_binary(lists:append(lists:map(fun(X) -> binary_to_list(X) end, Reversed)));

markdown(<<"#####", Rest/binary>>, OpenTags, Acc, Context) ->
    {OpenTags2, Acc2} = exclusive_insert_tag(<<"h5">>, OpenTags, Acc),
    markdown(Rest, OpenTags2, Acc2, Context);
markdown(<<"####", Rest/binary>>, OpenTags, Acc, Context) ->
    {OpenTags2, Acc2} = exclusive_insert_tag(<<"h4">>, OpenTags, Acc),
    markdown(Rest, OpenTags2, Acc2, Context);
markdown(<<"###", Rest/binary>>, OpenTags, Acc, Context) ->
    {OpenTags2, Acc2} = exclusive_insert_tag(<<"h3">>, OpenTags, Acc),
    markdown(Rest, OpenTags2, Acc2, Context);
markdown(<<"##", Rest/binary>>, OpenTags, Acc, Context) ->
    {OpenTags2, Acc2} = exclusive_insert_tag(<<"h2">>, OpenTags, Acc),
    markdown(Rest, OpenTags2, Acc2, Context);
markdown(<<"#", Rest/binary>>, OpenTags, Acc, Context) ->
    {OpenTags2, Acc2} = exclusive_insert_tag(<<"h1">>, OpenTags, Acc),
    markdown(Rest, OpenTags2, Acc2, Context);
markdown(<<"**", Rest/binary>>, OpenTags, Acc, Context) ->
    {OpenTags2, Acc2} = toggle_tag(<<"strong">>, OpenTags, Acc),
    markdown(Rest, OpenTags2, Acc2, Context);
markdown(<<"*", Rest/binary>>, OpenTags, Acc, Context) ->
    {OpenTags2, Acc2} = exclusive_insert_tag(<<"em">>, OpenTags, Acc),
    markdown(Rest, OpenTags2, Acc2, Context);
markdown(<<"``", Rest/binary>>, OpenTags, Acc, Context) ->
    {OpenTags2, Acc2} = exclusive_insert_tag(<<"code">>, OpenTags, Acc),
    markdown(Rest, OpenTags2, Acc2, Context);
markdown(<<"`", Rest/binary>>, OpenTags, Acc, Context) ->
    {OpenTags2, Acc2} = exclusive_insert_tag(<<"code">>, OpenTags, Acc),
    markdown(Rest, OpenTags2, Acc2, Context);
markdown(<<"![", Rest/binary>>, OpenTags, Acc, Context) ->
    case parse_link(<<"[", Rest/binary>>, Context) of
	{link, Rest2, Href, Text, undefined} ->
	    Img = <<"<img src=\"", Href/binary, "\" alt=\"", Text/binary, "\">">>,
	    markdown(Rest2, OpenTags, [Img | Acc], Context);
	{link, Rest2, Href, Text, Title} ->
	    Img = <<"<img src=\"", Href/binary, "\" alt=\"", Text/binary, "\" title=\"", Title/binary, "\">">>,
	    markdown(Rest2, OpenTags, [Img | Acc], Context)
    end;

markdown(<<"[", Rest/binary>>, OpenTags, Acc, Context) ->
    case parse_link(<<"[" , Rest/binary>>, Context) of
	{link, Rest2, Href, Text, undefined} ->
	    Link = <<"<a href=\"", Href/binary, ">", Text/binary, "</a>">>,
	    markdown(Rest2, OpenTags, [Link | Acc], Context);
	{link, Rest2, Href, Text, Title} ->
	    Link = <<"<a href=\"", Href/binary, " title=\"", Title/binary, "\" >", Text/binary, "</a>">>,
	    markdown(Rest2, OpenTags, [Link | Acc], Context);
	{context, Rest2, Context2} ->
	    markdown(Rest2, OpenTags, Acc, Context2)
    end;

    
markdown(<<B:1/binary, Rest/binary>>, OpenTags, Acc, Context) ->
    markdown(Rest, OpenTags, [B | Acc], Context).


%% @doc sub-parser for handling links.
%%      Handles formats:
%%        [This is a test](http://test.com/ "The title")
%%        [This is a test][test]
%%
%%     For the second format, you'll need to have previously
%%     specified the link using the format
%%        [test]: http://test.com/ "Test Title"
%%
%% @spec parse_link() -> link_components() | new_context()
%%       new_context = {context, binary(), proplist()}
%%       link_components = {link, binary(), href(), text(), title()}
%%       href = string()
%%       text = string()
%%       title = string() | undefined
%%       proplist = [{binary(), binary()}]
parse_link(Binary, Context) ->
    {Binary2, Text} = parse_link_text(Binary,[]),
    % stage 2, 
    ok.
%% @doc parse the text portion of a link.
%%      For example, parse "test" from [test][this].
parse_link_text(<<"[",Binary/binary>>, Acc) ->
    parse_link_text(Binary, Acc);
parse_link_text(<<"]",Binary/binary>>, Acc) ->
    Reversed = lists:reverse(Acc),
    Text = lists:append(lists:map(fun(X) -> binary_to_list(X) end, Reversed)),				     
    {Binary, list_to_binary(Text)};
parse_link_text(<<Char:1/binary, Binary/binary>>, Acc) ->
    parse_link_text(Binary, [Char | Acc]).

    


%% @doc close a tag if it is in the open tags stack,
%%      otherwise open it.
%% @spec toggle_tag(tag(), tag_stack(), html()) -> {tag_stack(), html()}
%%       tag = binary()
%%       tag_stack = [tag()]
%%       html = [binary()]
toggle_tag(Tag, OpenTags, Acc) ->
    case lists:member(Tag, OpenTags) of
	true ->
	    {lists:delete(Tag, OpenTags), [<<"</",Tag/binary,">">> | Acc]};
	false ->
	    {[Tag | OpenTags], [<<"<",Tag/binary,">">> | Acc]}
    end.

%% @doc insert tag IFF it isn't already on the
%%      stack of open tags.
%% @spec exclusive_insert_tag(tag(), tag_stack(), html()) -> {tag_stack(), html()}
%%       tag = binary()
%%       tag_stack = [tag()]
%%       html = [binary()]
exclusive_insert_tag(Tag, OpenTags, Acc) ->
    case lists:member(Tag,OpenTags) of
	true ->
	    {OpenTags, Acc};
	false ->
	    {[Tag | OpenTags], [<<"<",Tag/binary,">">> | Acc]}
    end.