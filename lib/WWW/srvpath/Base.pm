use Object::Pad ':experimental(:all)';

package WWW::srvpath::Base;
role WWW::srvpath::Base : does(Adjust::Params);

use utf8;
use v5.40;

no warnings 'experimental::re_strict';
no warnings 'experimental::signature_named_parameters';

use re 'strict';

use meta;
use PadWalker qw'peek_my var_name';
use IO::Handle::Common;
use Const::Fast;

use parent 'Exporter';

use vars            qw'@EXPORT  @EXPORT_OK';
use Path::Try::Base qw($undef);

@EXPORT    = qw(sigil ARRAY array refstr dmsg fatal callctx);
@EXPORT_OK = @EXPORT;

our @EXPORT_SUB    = @EXPORT_OK;
our @EXPORT_COMMON = qw'';

field $debug : reader = $ENV{DEBUG} || 1;

APPLY($class_mop) {
    __PACKAGE__->apply($class_mop)
};

ADJUST : params (%param) {
    $self->import;
};

method apply : common ($class_mop) {
    $class->export_sub($class_mop);
    $class->export_common($class_mop);
}

method export_sub : common ($class_mop) {
    foreach my $common (@EXPORT_SUB) {
        $class_mop->add_method( $common, common => 1, \&$common );
    }
}

method export_common : common ($class_mop) {
    my $class = $class_mop->name;
    foreach my $common (@EXPORT_COMMON) {
        $class_mop->add_method( $common, common => 1, sub { $class->$common } );
    }
}

method export_instance {
    ...;
}

sub ARRAY (@in) {
    my @ret;

    foreach my ($var) (@in) {
        $var //= [];
        my $type = reftype($var);

        if ( !$type ) {
            push @ret, [$var];
        }
        elsif ( $type ne 'ARRAY' ) {
            my $name = PadWalker::var_name( 0, $var );
            die "\$name must be an ARRAY ref or a scalar value. (Got: $type)";
        }
        elsif ( $type eq 'ARRAY' ) {
            push @ret, $var;
        }
    }

    @ret;
}

*array = \&ARRAY;

sub refstr ($ref) {
    reftype($ref) // '';
}

sub callctx (@opt) {
    my $invoke;

    if ( blessed $opt[0] && ref $opt[0]->isa(__PACKAGE__)
        || $opt[0] eq __PACKAGE__ )
    {
        $invoke = shift @opt;
        ...;
    }
    return @opt;
}

sub sigil ( $varref, : $up = 1, : $name //= undef, %opt ) {
    $name //= var_name( $up + 1, $varref );
    const my $sigil => qr/^[\$\@\%\&\*]{1}/;

    # ( $name, ( $name =~ s/$sigil//rg ) );
    ( $name =~ /($sigil)(.+)$/g );
}

method lexical : common ($up //= 1, @name) {
    my %lexical;
    foreach my ( $k, $v ) ( PadWalker::peek_my($up)->%* ) {

        # /        dmsg( $k, $v );

        my ( $sig, $name ) = ( sigil( $v, name => $k, up => $up ) );

        # next if none { $name eq $_ } @name;
        # #
        # # dmsg $sig, $name, $v;
        ( $lexical{$name} ) =
          refstr($v) eq 'REF' ? ( eval qq'$sig\{\$v\}' ) : $v;

        # dmsg $lexical{$name};
    }
    \%lexical;
}
