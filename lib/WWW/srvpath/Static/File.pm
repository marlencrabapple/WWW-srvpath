use Object::Pad ':experimental(:all)';

package WWW::srvpath::Static::File;

class WWW::srvpath::Static::File : does(WWW::srvpath::Static) :
  does(Adjust::Params);

use utf8;
use v5.44;

use builtin;
use Path::Tiny;
use IO::Handle::Common;
use Plack::Request;
use Plack::Response;

use subs 'serve_path';

field $root  : param : reader //= undef;
field $file  : param : reader;
field $mount : param : reader //= $file->basename;

ADJUST {
    # $mount //= $file->absolute( $root->absolute );
    dmsg $self
}

ADJUST : params (%param) {
    $self->adjust_params(
        [ \$file, \$root ],
        \%param,
        cb => sub ($val) {
            path($val)->absolute if $val;
        }
    );
};

method to_res ($req) {
    my $res = $req->new_response;
    if ( $req->path_info eq $mount ) {

        if ( $self->root ) {
            return $self->render_403
              unless $root->realpath->subsumes( $file->realpath );
        }

        $res->status(200);
        $res->body( $file->openr_raw );
        if ( my ($ext) = ( $file->basename =~ /^.+\.(.+)$/g ) ) {
            $res->content_type( Plack::MIME->mime_type(".$ext") );
        }

        return $res->finalize;
    }
    else {
        return $self->render_404;
    }
}

# *serve_path = *to_res;

method to_app {
    sub ($env) {
        $self->to_res( Plack::Request->new($env) );
    }
}

# method  : common ($path, $root = './', %param) {
#     my $self = $class->new( root => $root, file => $path );
#     $self->get_path(%param);
# }
