use Object::Pad ':experimental(:all)';

package WWW::srvpath::Config;
role WWW::srvpath::Config : does(WWW::srvpath::Base);

use utf8;
use v5.44;

use TOML::Tiny;    #'from_toml';
use Path::Tiny;
use File::ConfigDir;
use Const::Fast;
use IO::Handle::Common;
use WWW::srvpath::Util;

sub optdef_canonalias (%optdef) {
    map {
        (
            $_ => [
                $_,
                reftype( $optdef{$_} ) eq 'ARRAY' ? $optdef{$_}->@*
                : reftype( $optdef{$_} ) eq 'HASH'
                  && $optdef{$_}->{alias}
                  && refstr( $optdef{$_}->{alias} ) eq 'ARRAY'
                ? $optdef{$_}->{alias}->@*
                : ()
            ]
        )
    } keys %optdef;
}

sub find_alias (%optdef) {
    foreach my ( $canon, $allname ) (

        # Maybe its better to flatten the names in the foreach?
        map {
            (
                $_ => [
                    $_,
                    reftype( $optdef{$_} ) eq 'ARRAY' ? $optdef{$_}->@*
                    : reftype( $optdef{$_} ) eq 'HASH'
                      && $optdef{$_}->{alias}
                      && refstr( $optdef{$_}->{alias} ) eq 'ARRAY'
                    ? $optdef{$_}->{alias}->@*
                    : ()
                ]
            )
        } keys %optdef
      )
    {
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

field $toml = TOML::Tiny->new;
field $file = [
    map  { path("$_/srvpath.toml") }
    grep { $_ } @CONFIGDIR_DEFAULT
];
field $data : reader = {};

# Default configuration files. May warn on error but will fall back to minimal
# inline config
ADJUST {
    dmsg $file;
};

# User provided/non-default config files. Fatal when path does not exist.
ADJUST : params (:$config = []) {
    $self->load_config($_)
      for @$config;

    dmsg $self, $data;
};

method default_config () {
    for my $path (@$file) {
        if ( !$self->$self->try_config($file) ) {
            if ( $path->parent eq $CONFIGDIR_DEFAULT[0] ) {
                $$file[0]->spew_utf8();
            }
        }
    }
    $self->try_config($_) for $file->@*;
}

method try_config ( $file, %opt ) {
    $self->load_config( $file, %opt, try => 1 );
}

method load_config ( $file, %opt ) {
    my $path = path($file)->realpath;

    if ( !$path->exists ) {
        return undef if $opt{try};
        fatal "Config file '$file' does not exist.";
    }

    my $data_merge = $toml->decode( path($path)->slurp_utf8 );
    $self->merge_config($data_merge);
}

method merge_config ( $data_merge, $dest = $data ) {

    # dmsg $data_merge, $dest;
    foreach my ( $key, $val ) ( $data_merge->%* ) {
        if ( my $val_curr = $$dest{$key} ) {
            if (   ( !ref $val && !ref $val_curr )
                || ( ref $val eq ref $val_curr ) )
            {
                if ( ref $val eq 'ARRAY' ) {
                    push @$val_curr, @$val;
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
                  . ref $val_curr
                  . "' but new value has type '"
                  . ref $val . "'";
            }
        }
        else {
            $$dest{$key} = $val;
        }
    }
    $dest;
}

method config (%opt) {
    $data;
}

const our $config_builtin_toml => <<'...';
[global]
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

