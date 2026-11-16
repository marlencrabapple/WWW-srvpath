use Object::Pad ':experimental(:all)';

package WWW::srvpath::User::Auth;

role WWW::srvpath::User::Auth : does(WWW::srvpath::Base);

use v5.44;
use utf8;

# use System::Info 'sysinfo_hash';
use Const::Fast;
use Net::SSLeay;
use Crypt::Argon2 qw'argon2_pass argon2_verify';
use Const::Fast;
use MIME::Base64 'encode_base64';
use IO::Handle::Common;

use parent 'Exporter';
use vars qw'@EXPORT @EXPORT_OK';

@EXPORT = qw'hashpass valid_pass argon2_pass argon2_verify is_argon2';

const our $ARGON2_RE => qr/^
    \$argon2(i|d|id)
    \$v=([0-9]+)
    \$m=([0-9]+),
    t=([0-9]+),
    p=([0-9]+)
\$(.+)$/xx;

const our %ARGON2_DEFAULT => (
    t_cost   => 3,
    m_factor => '64M',

    # parallel   => $$SYSINFO{cpu_cores},
    parallel => (
        map { chomp $_; $_ }
          (`getconf _NPROCESSORS_ONLN 2>/dev/null || sysctl -n hw.ncpu`)
    )[0],
    tag_size   => 32,
    type       => 'argon2id',
    salt_bytes => 512
);

field $t_cost   : param : reader = $ARGON2_DEFAULT{t_cost};
field $m_factor : param : reader = $ARGON2_DEFAULT{m_factor};
field $parallel : param : reader = $ARGON2_DEFAULT{parallel};
field $tag_size : param : reader = $ARGON2_DEFAULT{tag_size};

APPLY($class_mop) {

    #$class_mop->name->apply($class_mop)
};

ADJUST : params (%param) {
    $self->import;
};

sub hashpass (@opt) {
    my @argon2opt = ();
    my $invoke;

    if ( blessed $opt[0] && ref $opt[0] eq __PACKAGE__
        || $opt[0] eq __PACKAGE__ )
    {
        $invoke = shift @opt;
        ...;
    }

    my $pass = shift @opt;

    fatal "Given password string appears to be an argon2 hash already"
      if $pass =~ $ARGON2_RE;

    my %opt  = (@opt);
    my $type = ( $opt{type} // $ARGON2_DEFAULT{type} );
    my $salt = $opt{salt};    #base64_encode($opt{salt});

    unless ($salt) {
        my $rv =
          Net::SSLeay::RAND_bytes( $salt,
            $opt{salt_bytes} // $ARGON2_DEFAULT{salt_bytes} );
        $salt = encode_base64( $salt, "" );
        fatal "$rv: Could not generate random bytes for salt."
          unless $rv == 1;
    }

    @argon2opt = (
        $type, $pass, $salt,
        map { ( $opt{$_} // $ARGON2_DEFAULT{$_} ) }
          (qw't_cost m_factor parallel tag_size')
    );

    argon2_pass(@argon2opt);
}

method valid_pass : common ( $pass, $crypt, %opt ) {
    my $valid = argon2_verify( $crypt, $pass );
    $valid;
}

method is_argon2 : common ($str) {
    $str =~ $ARGON2_RE;
}
