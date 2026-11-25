use Object::Pad ':experimental(:all)';

package WWW::srvpath::DirIndex;

class WWW::srvpath::DirIndex : isa(Plack::App::Directory) :
  does(WWW::srvpath::Util)
  : does(WWW::srvpath::Base);

use utf8;
use v5.44;

no warnings 'experimental::re_strict';
no warnings 'experimental::signature_named_parameters';

use builtin;
use Path::Tiny;
use Plack::Request;
use IO::Handle::Common;
use Unicode::UTF8 qw'decode_utf8 encode_utf8';
use WWW::srvpath::Util;
use Plack::MIME;

field $root   : param //= './';
field $mount  : param //= '/';
field $config : param;

ADJUST : params (%param) {
    $root = path($root)->absolute
      unless builtin::blessed($root) && $root->isa('Path::Tiny')
};

method config { $config }

method serve_path( $env, $path //= $root ) {
    my $req = Plack::Request->new($env);
    my $res = $req->new_response(200);
    my @file;
    $path = path($path)->absolute($root);

    return $self->render_403
      unless $root->realpath->subsumes( $path->realpath );

    if ( !$path->is_dir ) {
        return WWW::srvpath::Static::File->serve_path( $env, $path );
    }

    foreach my $child ( $path->children ) {
        my $basename  = encode_utf8( $child->basename );
        my %childdata = ( path => $child, name => $basename );

        ( $childdata{uri} ) =
          '/' . __CLASS__->path_uri_encode( $child->relative($root) );

        if ( $child->is_file ) {
            my ( $noext, $ext ) =
              ( $basename =~ /^(.+?)(?:\.([a-z0-9]+))?$/ig );

            if ( $ext && $noext ne $basename ) {
                $childdata{ext}   = $ext;
                $childdata{noext} = $noext;
            }
            $childdata{size} = $child->size_human;

            $childdata{type} = Plack::MIME->mime_type(".$ext")
              if $ext;
        }
        elsif ( $child->is_dir ) { $childdata{$_} .= '/' for qw'url name' }

        try {
            $childdata{mtime} =
              Time::Piece->new( $child->stat->mtime )->strftime
        }
        catch ($e) {
            error($e);
            dmsg($e)
        }

        push @file, \%childdata;
    }

    if ( my $up = $path->parent ) {
        dmsg $path, $up, $up->basename, $up->relative($path);

        unshift @file,
          {
            path => $up,
            name => '../'
              . ( $up->basename ? encode_utf8( $up->basename ) . '/' : '' ),
            uri => (
                '/'
                  . (
                    join '/', __CLASS__->path_uri_encode( $up->relative($root) )
                  )
            ) // undef
          };
    }

    my $body =
      $self->tx->render( 'dirindex.tx',
        { path => $path, total => ( scalar @file - 1 ), file => \@file } );

    $res->body($body);
    $res->content_type(
        'text/html; charset=' . $self->config->{charset} . ';' );
    $res->finalize;
}

