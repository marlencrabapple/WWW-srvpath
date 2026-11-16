use Object::Pad ':experimental(:all)';

package WWW::srvpath::Static::File;

class WWW::srvpath::Static::File : isa(Plack::App::File) : does(Adjust::Params);
use utf8;
use v5.44;

use Path::Tiny;
use IO::Handle::Common;

field $req;
field $root;
field $file;

ADJUST : params (%param) {
    $self->adjust_params(
        [ \$file, \$root ],
        \%param,
        cb => sub ($val) {
            path($val)->absolute if $val;
        }
    );
};

method get_path ($path) {
    fatal "Request field is not an instance of Plack::Request"
      unless blessed($req) && $req->isa('Plack::Request');

    my $res = $req->new_response;

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

method map_path ($path_info) {
    if ($root) {
        if (
            my ($rel) =
            $path_info eq '/'
            ? '/'
            : ( $path_info =~ /^\/(.*)$/g )
          )
        {
            my $path =
              path( ( $rel =~ /\/$/g ? 'index.html' : $rel ) )->relative($root);

            my $res = $self->get_path($path);
            dmsg $rel, $path, $res;
            return $res;
        }
    }
    else {
        return $self->get_path( $file->absolute ) if $file;
    }
}

method to_route {

    sub ( $c, $path //= $c->req->path_info, @arg ) {

        # dmsg $c->req->env, $path, \@arg;
        $req = $c->req;
        $self->get_path( $self->map_path($path) );

        # $self->call( $c->env, @arg );
    }
}

method call ( $env, @arg ) {
    $req = Plack::Request->new($env);
    $self->get_path( $self->map_path( $req->path_info ) );

    # Plack::App::File::call( $self, $env, @arg );
}
