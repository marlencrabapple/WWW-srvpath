use Object::Pad ':experimental(:all)';

package WWW::srvpath::Config;
role WWW::srvpath::Config : does(WWW::srvpath::Base);

use utf8;
use v5.44;

use Path::Tiny;
use File::ConfigDir;
use Const::Fast;
use IO::Handle::Common;
use WWW::srvpath::Base;
use WWW::srvpath::Util;
use List::Util qw'first uniq';

# field $reset_config : accessor : param //= 0;
field $reset_config : accessor : param //= 0;

method flatten : prototype($) : common ($optdef) {
    map {
        (
            $_ => [
                $_,
                reftype( $$optdef{$_} ) eq 'ARRAY' ? $$optdef{$_}->@*
                : reftype( $$optdef{$_} ) eq 'HASH'
                  && $$optdef{$_}->{alias}
                  && refstr( $$optdef{$_}->{alias} ) eq 'ARRAY'
                ? $$optdef{$_}->{alias}->@*
                : ()
            ]
        )
    } keys %$optdef;
}

method canon_alias_kv : common : prototype(%) (%optdef) {
    foreach my ( $canon, $allname ) ( $class->flatten( \%optdef ) ) {
        my $prefix = $optdef{$canon}->{prefix};

        foreach my $name (@$allname) {
            for my ( $ptn, $subst ) (
                qr/-/  => '_',
                qr/_/  => '-',
                qr/-|/ => '',
                ( $prefix ? ( qr/^$prefix/ => '' ) : () )
              )
            {
                if ( my $alias = ( $name =~ s/$ptn/$subst/gr ) ) {
                    push $optdef{$canon}->{alias}->@*, $alias;
                }
            }
        }
    }
}

sub to_getopt (%optdef) {
    my @spec;
    foreach my ( $canon, $alias ) (%optdef) {

        # my @spec;
        ( scalar @$alias ? ( $$alias[ scalar @$alias - 1 ] ) : $canon ) .=
          ':' . $optdef{$canon}->{type}
          if $optdef{$canon}->{type};
        push @spec, join '|', ( $canon, @$alias );
        push @spec, $optdef{$canon}->{dest};
    }
    @spec;
}

sub from_getopt (@spec) {
    foreach my ( $prev, $curr, $next ) ( undef, @spec ) {
        if ( refstr($curr) eq 'CODE' ) {
            next;
        }
        if ( !reftype($curr) ) {

            # Detect destination or callback (but don't do anything as of
            # yet...)
            my ( $name, @alias ) = split /\|/, $curr;
            my %optdef = ( $name => \@alias );
            if ( scalar @alias ) {
                my ( $last, $type ) = ( split /:/, pop @alias );
                $optdef{$name} = { alias => [ @alias, $last ] };
                $optdef{$name}->{type} = $type if $type;
            }

            %optdef = find_alias(%optdef);
            $curr   = \%optdef;

            if ( my $type = reftype($next) ) {
                if ( $type eq 'CODE' ) {
                    if ( $curr eq '<>' ) {    # bare arg
                    }
                    else {                    # 'name' => \&callback
                    }
                }
                elsif ( $type eq 'ARRAY' ) {    # (s|i)@ or (s|i){[0-9]?,[0-9]?}
                }
                elsif ( $type eq 'HASH' ) {     # (s|i)% ...
                }
                else {
                    error "'$type' not explicitly supported";
                }

                $$curr{dest} = $next;
            }
            else {    # $next is next option
            }
        }

    }

    # foreach my $spec (@spec) {
    #     my ( $name, @alias ) = split /\|/, $spec;
    #     my %optdef = ( $name => \@alias );
    #     if ( scalar @alias ) {
    #         my ( $last, $type ) = ( split /:/, pop @alias );
    #         $optdef{$name} = { alias => [ @alias, $last ] };
    #         $optdef{$name}->{type} = $type if $type;
    #     }

    #     %optdef = find_alias(%optdef);
    # }
}

sub default_options {
    my %default = (
        dirindex => {
            alias => [qw'index generate-index'],
        },
        ssl => {
            alias => [qw'tls']
        },
        certfile => {
            alias => []
        }
    );

}

const our %DEFAULT => default_options;

const our @CONFIGDIR_DEFAULT =>
  ( path(File::ConfigDir::xdg_config_home)->absolute, path("./")->absolute, );

method toml(%opt) {
    state $toml //= TOML::Tiny->new( %opt, strict => 1 );
    $toml;
}

field $file = [

    # grep { $_->is_file }
    map  { path("$_/srvpath.toml") }
    grep { $_ } @CONFIGDIR_DEFAULT
];
field $data : reader = {};

ADJUST : params (:$config = []) {

    dmsg $self, [ $self->reset_config ], $config;

  # Default configuration files. May warn on error but will fall back to minimal
  # inline config
    $self->default_config unless $self->reset_config;

    # dmsg $self;

    # User provided/non-default config files. Fatal when path does not exist.
    $self->load_config($_)
      for @$config;

    # dmsg $self
};

method default_config {

    # dmsg $file;
    for my $path (@$file) {

        # dmsg $path, $reset_config;
        my $_config = $self->try_config( $path, dest => $data );
        if ( !$path->exists || refstr($_config) ne 'HASH' ) {
            dmsg $path, $_config;
            if ( $path->parent eq $CONFIGDIR_DEFAULT[0] ) {
                dmsg $path, $data, $self->toml->encode($data);
                $path->spew_utf8( $self->toml->encode($data) );
            }
        }
        $path = $_config;
    }
}

method try_config ( $file, %opt ) {
    $self->load_config( $file, %opt, try => 1 );
}

method load_config ( $in, %opt ) {
    my $path = path($in)->absolute;

    # dmsg $in, $path, \%opt;

    if ( !$path->exists ) {
        return undef if $opt{try};
        fatal "Config file '$path' does not exist.";
    }

    my $data_merge = $self->toml->decode( $path->slurp_utf8 );
    my $dest       = $self->merge_config($data_merge);
    @$file = uniq @$file, $path;

    # dmsg $file;
    $dest;
}

method clear ( $key, $val, $src, $dst ) {

    # dmsg $key, $val, $src, $dst;
    if ( my $type = builtin::reftype($val) ) {
        my ( $sigil, $name ) = sigil($val);
        dmsg $sigil, $name, $type;
        eval "$sigil\$name = ()";
        $val =
            $type eq 'ARRAY' ? []
          : $type eq 'HASH'  ? {}
          :                    fatal "Cannot call reset on '$type' key '$key'";

    }
    else { $val = undef }

}
use subs 'reset';
*reset = *clear;

method default ( $key, $val, $src, $dst ) {

}

method merge_config ( $data_merge, $dest = $data ) {
    const my @metaprefix => qw(clear reset default);

    my $keyptn = join '|', keys %$data_merge, keys %$dest;
    $keyptn = qr/$keyptn/;

    foreach my ( $key, $val ) ( $data_merge->%* ) {

        # my $keyptn = join '|', keys %$data;
        # $keyptn = qr/($keyptn)/;
        # dmsg $key, $val, $keyptn, qr/^$_($keyptn)$/;

        if (
            my $subname =
            first {

                my $prefix = $_;
                my $ptn    = qr/^$prefix\_$keyptn$/;

                # dmsg $key, $ptn, ( $key =~ /^$prefix\_($keyptn)$/g );
                $key =~ /^$prefix\_($keyptn)$/g
            } @metaprefix
          )
        {
            # dmsg $subname;
            $self->$subname( $key, $val, $data_merge, $dest );
        }
        if ( my $val_curr = $$dest{$key} ) {
            if (   ( !ref $val && !ref $val_curr )
                || ( ref $val eq ref $val_curr ) )
            {
                if ( ref $val eq 'ARRAY' ) {
                    if ( scalar @$val ) {
                        push @$val_curr, @$val;
                    }
                    else { @$val_curr = (); }
                }
                elsif ( ref $val eq 'HASH' ) {

                    # $val_curr = $self->merge_config( $val, $val_curr );
                    $self->merge_config( $val, $val_curr );
                }
                else {
                    # $$dest{$key} = $val;
                    $val_curr = $val;
                }
            }
            else {
                fatal "Config key '$key' has type mismatch: current type is '"
                  . reftype($val_curr)
                  . "' but new value has type '"
                  . reftype($val) . "'";
            }
        }
        else {
            $$dest{$key} = $val;

            # if for $alias{$key}->@()
        }
    }
    $dest;
}

method config (%opt) {
    $data;
}

const our $config_builtin_toml => <<'...';
 charset = 'UTF-8'
 listen =':3223'
 enable-ssl = 1

[[path]]
 root = "/usr/share/WWW-srvpath/public"
 mount = "/"
 ssl-enabled = 1
 cert-bundle = "<: $certbundle :>"
 cert-file = "<: $keyfile :>"

 []
   name = "<: $localuser :>"
   crypt = "<: $crypt :>"

...

