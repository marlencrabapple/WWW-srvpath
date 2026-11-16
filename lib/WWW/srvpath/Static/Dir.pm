use Object::Pad ':experimental(:all)';

package WWW::srvpath::Static::Dir;

class WWW::srvpath::Static::Dir : isa(Plack::App::Directory);

use utf8;
use v5.44;

use builtin;
use IO::Handle::Common;
use Path::Tiny;

field $req;
field $root              : param;
field $dirindex          : param = true;
field $indexfile         : param = ['index.html'];
field $dir_rewrite_index : param = false;

method serve_path( $env, $path ) {
    if ( my $rel = $path->relative($root) ) {

    }
}
