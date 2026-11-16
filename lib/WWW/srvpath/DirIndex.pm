use Object::Pad ':experimental(:all)';

package WWW::srvpath::DirIndex;

class WWW::srvpath::DirIndex : isa(Plack::App::Directory) :
  does(WWW::srvpath::Util)
  : does(WWW::srvpath::Base);

use utf8;
use v5.44;

use Path::Tiny;
use Plack::Request;
use IO::Handle::Common;
use Unicode::UTF8 qw'decode_utf8 encode_utf8';
use WWW::srvpath::Util;
use Plack::MIME;

field $root   : param //= ' . /';
field $mount  : param //= '/';
field $config : param;

ADJUST : params (%param) { $root = path($root)->absolute if $param{root} };

method config { $config }

method serve_path( $env, $path //= $root ) {
    my $req = Plack::Request->new($env);
    my $res = $req->new_response(200);
    my @file;

    $path = path($path)->absolute;
    if ( !$path->is_dir ) {
        return Plack::App::File->serve_path( $env, $path );
    }

    foreach my $child ( $path->children ) {

        my $basename  = encode_utf8( $child->basename );
        my %childdata = ( path => $child, name => $basename );

        ( $childdata{uri} ) =
          __CLASS__->path_uri_encode( $child->relative($path) );

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
        else { $childdata{uri} .= '/' }

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

    unshift @file,
      {
        path => $path->parent // undef,
        name => '../' . encode_utf8( $path->parent->basename ),
        uri  =>
          ( __CLASS__->path_uri_encode( $path->parent->relative($path) ) )[0]
          // undef
      }
      if $path->parent;

    my $body =
      $self->tx->render( 'dirindex.tx', { path => $path, file => \@file } );

    $res->body($body);
    $res->finalize;
}

