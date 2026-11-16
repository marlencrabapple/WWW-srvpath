use Object::Pad ':experimental(:all)';

package WWW::srvpath::CLI;
role WWW::srvpath::CLI : does(WWW::srvpath::Base);

use utf8;
use v5.44;

use parent 'Exporter';

use Getopt::Long ();
use Const::Fast;
use IO::Handle::Common;
use Path::Try;

APPLY {

}

ADJUST {

}

my class Dest {

};

my class Spec {

};

my $argv;
my $dest;
my $spec;

sub GetOptions ( $dest, $spec, %opt ) {

    GetOptionsFromArray( ( $opt{argv} // \@ARGV ), $dest );
}
