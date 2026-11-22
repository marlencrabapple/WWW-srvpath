use Object::Pad ':experimental(:all)';

package WWW::srvpath::Util;
role WWW::srvpath::Util : does(WWW::srvpath::Base);

use utf8;
use v5.44;

use Path::Try;
use Const::Fast;
use Time::HiRes;
use Syntax::Keyword::Dynamically;
use IO::Handle::Common;
use HTML::Escape;
use URI::Escape;
use Net::Domain 'hostfqdn';
use List::Util 'none';
use Text::Xslate;
use WWW::srvpath::Base;
use TOML::Tiny;
use Exporter;
use parent 'Exporter';

no warnings
  qw'experimental::re_strict experimental::signature_named_parameters';

no warnings 'experimental::re_strict';
no warnings 'experimental::signature_named_parameters';

use re 'strict';

our @EXPORT_OK =
  qw'tx path2uri epoch file_unique uri_escape uri_unescape uri_escape_utf8 escape_html path_uri_encode';
our @EXPORT = @EXPORT_OK;

# field $tx   : reader = Text::Xslate->new( path => './view' );
method tx {
    state $tx //= Text::Xslate->new( path => './view' );

    # dmsg builtin::refaddr($tx);
    $tx;
}

# field $json : reader = JSON::MaybeXS->new;
method json (%opt) {

    # dmsg( ( callstack() )[0], $self );
    state $json //= JSON::MaybeXS->new(%opt);
    $json;

}
ADJUST {
    $self->json->pretty(1) if $self->debug;
    $self->json->utf8(1)   if $self->config->{charset} =~ /^utf-?8$/i;
}

sub epoch( $join = '', %opt ) {
    $opt{ms_pad} //= 6;
    my ( $sec, $ms ) = Time::HiRes::gettimeofday;

    $ms = '0' x ( $opt{ms_pad} - length $ms ) . $ms
      if $opt{ms_pad} && $opt{ms_pad} >= 1;

    join $join, $sec, $ms;
}

my class FileUnique {
    use utf8;
    use v5.44;

    use IO::Handle::Common;
    use Path::Tiny;
    use List::Util 'none';

    field $cksum : reader = {};
    field $digest : param;

    method $file_unique($in) {
        my $digest = $in->digest;
        $$cksum{$digest} //= [];
        push $$cksum{$digest}->@*, $in->absolute
          if none { dmsg $in, $_; $in->absolute eq $_ } $$cksum{digest}->@*;

        dmsg $in, $digest;

        my $ret;

        if ( scalar $$cksum{$digest}->@* > 1 ) {
            $ret = undef;
            say STDERR "Duplicate file '$in' detected. Other paths:";
            my $dupestr = "  " . ( join ', ', $$cksum{$digest}->@* ) . "\n";
            say STDERR $dupestr;
        }
        else { $ret = 1 }

        $ret;
    }

    method file_unique : common (@in) {
        my $self = $class->new();
        $self->$file_unique( path($_) ) for @in;
    }
}

sub file_unique(@in) {
    FileUnique->file_unique(@in);
}

method path_uri_encode : common ( $path, %opt ) {
    my $return_joined;
    $opt{join} //= '/';

    $path = $path->stringify if builtin::blessed($path);

    if ( refstr($path) ne 'ARRAY' ) {
        $path          = [ split qr!/!, $path ];
        $return_joined = 1;
    }

    my @pathencoded = (
        map {
            $opt{charset} && $opt{charset} !~ /^utf-?8$/i
              ? uri_escape($_)
              : uri_escape_utf8($_)
        } @$path
    );

    $return_joined ? join( $opt{join}, @pathencoded ) : @pathencoded;
}

sub wrap_anchor ( $href, $text, %opt ) {
    qq'<a href="$href" '
      . (
        $opt{title}
        ? qq'"title="' . escape_html( $opt{title} ) . '"'
        : ''
      )
      . '>'
      . escape_html($text) . "</a>";
}

const our $urisplit => qr|
 (?:([^:/?\#]+):)?
 (?://([^/?\#]*))?
 ([^?\#]*)
 (?:\?([^\#]*))?(?:\#(.*))?|x;

const our $pathsplit => qr|/|;

sub uri_split( $uristr, %opt ) {
    ( $uristr =~ $urisplit )
}

sub path_split( $pathstr, %opt ) {
    ( split /$pathsplit/, $pathstr )
}

const our %urifield_default => (
    scheme => 'https',
    host   => hostfqdn,
    ( map { ( $_ => undef ) } qw'port path query fragment' )
);

sub path2uri ( $path_aref, %opt ) {
    my @out;

    $opt{host} //= hostfqdn;
    $opt{join} //= "\n";

    my %urifield;

    foreach my ($pathstr) (@$path_aref) {

        @urifield{ keys %urifield_default } = $pathstr =~ $urisplit;

        foreach my ( $k, $v ) (
            map { ( $_ => ( $opt{$_} // $urifield_default{$_} ) ) }
              keys %urifield_default
          )
        {
            next unless $v;
            if ( $opt{"replace_$k"} ) {
                $urifield{$k} = $v;
            }
            else {
                $urifield{$k} //= $v;
            }
        }

        if ( $opt{uniq} || $opt{readpath} ) {
            $urifield{path} = path( $urifield{path} )->absolute;

            next unless $urifield{path}->is_file;
            next if $opt{unique} && !file_unique( $urifield{path} );
        }

        my @pathencoded = path_uri_encode( path_split( $urifield{path} ) );

        my $href;    # = $pathencoded;

        if ( !$opt{relative} ) {
            $href = "$urifield{scheme}://$urifield{host}$href";
            $href .= ":$urifield{port}"
              if none { $_ == $urifield{port} } qw(80 443);
        }
        $href .= join '/', @pathencoded;

        $href .= "?$urifield{query}"    if $urifield{query};
        $href .= "#$urifield{fragment}" if $urifield{fragment};

        my $outstr = $href;

        if ( $opt{wrap_anchor} ) {
            wrap_anchor(
                $href,
                $pathencoded[ scalar @pathencoded - 1 ],
                %opt{qw'title nofollow target style class id'}
            );
        }

        push @out, $outstr;
    }

    @out;
}

sub callstack ( $class = undef, : $startlvl = 1 ) {
    my @callstack;
    my $i = $startlvl // 1;

    while ( my @caller = caller $i ) {
        {
            no strict 'refs';
            push @caller, \%{"$caller[0]\::"};
            push @caller, $caller[0]->META() if ${"$caller[0]\::"}{META}
        }

        push @callstack, \@caller;
    }
    continue { $i++ }

    @callstack;
}

