:- module(login_crypto, [
              token_uname/2,
              make_login_cookie/2
          ]).
/** <module> Tools for crypto work on login cookies
 *
 */

%!  token_uname(+Token:string, -Uname:text) is semidet
%
%   Succeeds returning the user name if the token is valid
%   or fails if not
%
token_uname(Token, Uname) :-
    hex_bytes(Token, TokenList),
    length(Nonce, 12),
    append(Nonce, CipherTextCodes, TokenList),
    string_codes(CipherText, CipherTextCodes),
    get_crypto_key(Key),
    crypto_data_decrypt(CipherText,
                        'chacha20-poly1305',
                        Key,
                        Nonce,
                        RecoveredText,
                        []),
    split_string(RecoveredText, "/", "", [URLEncodedUName, ExpiresUtimeString]),
    number_string(Expires, ExpiresUtimeString),
    get_time(Now),
    Expires > Now,
    www_form_encode(URLEncodedUName, Uname).

:- dynamic crypto_key/1.

get_crypto_key(Key) :-
    crypto_key(Key),
    !.
get_crypto_key(Key) :-
    catch(
        setup_call_cleanup(
            open('secret_identity_key', read, Stream),
            read(Stream, Key),
            close(Stream)
        ),
        error(existence_error(source_sink, _), _),
        (   create_crypto_key_file, % make sure we really wrote it
            get_crypto_key(Key),
            asserta(crypto_key(Key))
        )
    ).

create_crypto_key_file :-
    crypto_n_random_bytes(32, Key),
    setup_call_cleanup(
        open('secret_identity_key', write, Stream),
        (   writeq(Stream, Key),
            write(Stream, '.'),
            flush_output(Stream)
        ),
        close(Stream)
    ).


make_login_cookie(UName, Cookie) :-
      www_form_encode(URLEncodedUName, UName),
      get_time(Now),
      Expires is floor(Now) + 86400,
      get_crypto_key(Key),
      atomics_to_string([URLEncodedUName, "/", Expires], PlainText),
      crypto_n_random_bytes(12, Nonce),
      crypto_data_encrypt(PlainText, 'chacha20-poly1305',
                          Key, Nonce, CipherText, []),
      string_codes(CipherText, CipherTextCodes),
      append(Nonce, CipherTextCodes, TokenList),
      hex_bytes(Cookie, TokenList).