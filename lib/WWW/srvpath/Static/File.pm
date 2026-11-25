use Object::Pad ':experimental(:all)';

package WWW::srvpath::Static::File;

class WWW::srvpath::Static::File : isa(Plack::App::File) : does(Adjust::Params);
use utf8;
use v5.44;

use builtin;
use Path::Tiny;
use IO::Handle::Common;
use Sublike::Extended;
use Plack::Request;
use Plack::Response;

field $root  : param : reader //= './';
field $file  : param : reader;
field $mount : param : reader;

ADJUST : params (%param) {
    $self->adjust_params(
        [ \$file, \$root ],
        \%param,
        cb => sub ($val) {
            path($val)->absolute if $val;
        }
    );
};

method serve : common ($path, $root = './', %param) {
    my $self = $class->new( root => $root, file => $path );
    $self->get_path(%param);
}

extended method get_path (
    $path //= $self->file,
    $root //= $self->root,
    : $env = undef,
    : $req = undef,
    : $res = undef
  )
{
    if ( $req || $env ) {
        if ($req) {
            fatal "Request field is not an instance of Plack::Request"
              unless builtin::blessed($req) && $req->isa('Plack::Request');
        }
        elsif ($env) {
            $req = Plack::Request->new($env);

        }
        $res //= $req->new_response;
    }
    else {
        $res //= Plack::Response->new(200);
    }

    return $self->render_403
      unless $root->realpath->subsumes( $path->realpath );

    # $path = $path->relative($root);

    if ( $path->is_file ) {
        $res->status(200);
        $res->body( $path->openr_raw );
    }
    else {
        $res->status(404);
        $res->body('404 - File not found');
    }

    $res;
}

method to_app {
    sub ( $c, $path //= $c->req->path_info, @arg ) {
        my $req = $c->req;
        $self->get_path($path);
    }
}

# *to_route = *to_app;

method call ( $env, @arg ) {
    my $req = Plack::Request->new($env);
    $self->get_path( $req->path_info, req => $req );
}
