:- module(login_register, []).
/** <module> Registration module for identity
 *
 */

:- use_module(library(http/http_dispatch)).
:- use_module(library(http/html_write)).
:- use_module(library(identity/login_page)).
:- use_module(library(http/http_client)).
:- use_module(library(http/http_path)).
:- use_module(library(identity/login_crypto)).
:- use_module(library(identity/login_database)).

:- http_handler(login(register), register_form_handler, [id(register), identity(guest), priority(-100)]).


register_form_handler(_Request) :-
    reply_html_page(
        title('Register'),
        \register_body).

register_body -->
    html(div([
             h1('Register'),
             div(\register_form)
             ])).

register_form -->
    html(
        form([method('POST'), action(location_by_id(doregister))],
             [
                 \login_warning,
                 \login_hidden_referer,
                 \login_email,
                 \login_user_name_field,
                 \login_password_field,
                 \login_password2_field,
                 \login_submit_register
             ])).

login_submit_register -->
    html(input([type(submit),
                name(submit),
                value('Register')])).

login_email -->
    html(input([type(text),
                name(email),
                placeholder('Email'),
                required])).

login_password2_field -->
    html(input([type(password),
                name(passwd2),
                placeholder('Repeat password'),
               required])).


		 /*******************************
		  *         doregister          *
		  *  handle register form data  *
		 *******************************/

:- http_handler(login(doregister), doregister_handler, [id(doregister), identity(guest), priority(-100)]).

doregister_handler(Request) :-
        member(method(post), Request),
        http_read_data(Request, Data, []),
        member(uname=UserName, Data),
        member(passwd=Password, Data),
        member(passwd2=Password, Data),
        member(email=Email, Data),
        (   member(referer=SendUserTo, Data) ;
            http_location_by_id(home, SendUserTo) % TEST this
        ),
        add_user(UserName,
                 Password,
                 Email
                 ),
        Status = ok,  %  TODO make this work probably with a throw
        www_form_encode(Status, URLStatus),
        (   Status = ok
        ->
            make_login_cookie(UserName, Cookie),
            format('Status: 302 Found~n'),
            format('Location: ~w~n', [SendUserTo]),
            % session cookie, lives until browser exits
            % however the cookie itself contains an expiry
            % as well
            format('Set-Cookie: login=~w; Path=/~n', [Cookie]),
            format('Content-type: text/plain~n~n')
        ;
            http_location_by_id(register, RegisterPage),
            format('Status: 302 Found~n'),
            format('Location: ~w?warn=~w~n', [RegisterPage, URLStatus]),
            format('Content-type: text/plain~n~n')
        ).


