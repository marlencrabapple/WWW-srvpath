use Object::Pad ':experimental(:all)';

package WWW::srvpath::User;
role WWW::srvpath::User : does(WWW::srvpath::User::Auth);

use v5.44;
use utf8;

use Net::SSLeay;
use IO::Handle::Common;

field $userdb : reader = [];

# TODO: Maybe use autoload to call in form of (class common technically) method

method add_user ( $name, @pass ) {
    my %user = ( user => $name );

    if ( scalar @pass == 1 ) {
        $user{crypt} =
          __CLASS__->is_argon2( $pass[0] )
          ? $pass[0]
          : hashpass( $pass[0] );
    }
    else {
        my %pass = @pass;

        # TODO: eventually support reads from a different key
        my $crypt_key = $user{crypt_key} = $pass{crypt_key} //= 'crypt';

        if ( $pass{password} ) {
            $user{crypt} =
              WWW::srvpath::User::Auth::hashpass( delete $pass{password} );
        }
        elsif ( $pass{$crypt_key} ) {
            fatal "Not a valid argon2 hash"
              unless __CLASS__->is_argon2( $pass{$crypt_key} );

            $user{crypt} = $pass{$crypt_key};
        }
        else {
            fatal "No cleartext password or argon2 hash given.";
        }
    }

    push @$userdb, \%user;
    \%user;
}
