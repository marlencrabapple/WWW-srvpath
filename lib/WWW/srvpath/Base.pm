use Object::Pad ':experimental(:all)';

package WWW::srvpath::Base;
role WWW::srvpath::Base : does(Adjust::Params);

use utf8;
use v5.40;

use meta;
use PadWalker qw'peek_my var_name';
use IO::Handle::Common;

use parent 'Exporter';

use vars qw'@EXPORT  @EXPORT_OK';

@EXPORT    = qw(ARRAY array refstr dmsg fatal callctx);
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
