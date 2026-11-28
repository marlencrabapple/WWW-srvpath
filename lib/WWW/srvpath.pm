use Object::Pad ':experimental(:all)';

package WWW::srvpath;

class WWW::srvpath : does(WWW::srvpath::Config) : does(WWW::srvpath::User) :
  does(WWW::srvpath::Util);

use utf8;
use v5.40;

our $VERSION = "0.01_04";

use builtin;

use Path::Tiny;
use Plack::Builder;
use List::Util qw'pairmap first all';
use IO::Handle::Common;

use Plack::App::File;

use WWW::srvpath::DirIndex;
use WWW::srvpath::Static::File;

use subs qw'on_psgi to_app';

field $runner : accessor;
field $middleware = [];
field $run_config : param = 0;
field $verbose    : param  //= false;
field $param      : reader //= {};
field $app        : reader;
field $builder    : reader = Plack::Builder->new;

ADJUST : params (:$user = undef, :$pwhash = undef, %param) {
    $param = \%param;

    dmsg $param;

    if ( all { $_ } ( $user, $pwhash ) ) {
        $self->add_user( $user, $pwhash );
    }

    if ( all { $_ } @ENV{qw'SRVPATH_USER SRVPATH_PWHASH'} ) {
        $self->add_user(
            pairmap { ( user => $a, $pwhash => $b ) }
            @ENV{qw'SRVPATH_USER SRVPATH_PWHASH'}
        );
    }

    foreach my ( $i, $user ) ( builtin::indexed $self->config->{userdb}->@* ) {
        $user = $self->add_user( $$user{name},
            map { ( $_ => $$user{$_} ) } grep { $_ ne 'name' } keys %$user );

        $self->config->{userdb}[$i] = $user;
    }

};

method to_psgi {
    $builder->to_app(@_);
}

*to_app = \&to_psgi;

ADJUST : params (
  : $autoindex //= 1,
  : $path  //= './',
  : $root //= $path,
  : $mount //= '/',
  : $cgi   //= builtin::false,
  %param
  ) {
    $path = path( $path // $root );

    if ( $path->is_dir ) {
        dmsg $path, $root;
        if ($autoindex) {
            $app = WWW::srvpath::DirIndex->new(
                root   => $root,
                mount  => $mount,
                config => $self->config
            );
        }
        else {
            $app = Plack::App::File->new(
                file  => $path,
                mount => $mount,
            );
        }
    }
    elsif ($cgi) {
        $app =
          CGI::Emulate::PSGI->handler( CGI::Compile->compile( $path, $path ) );
    }
    else {
        $app = Plack::App::File->new( file => $path );
    }

    $builder->mount( $app->mount => $app->to_app );

    if ($run_config) {
        $builder->mount(
            '/run_config',
            sub ($env) {
                my $req = Plack::Request->new($env);
                my $res = $req->new_response(200);

                $res->body( $self->json->encode( $self->config ) );
                $res->content_type( 'application/json; charset='
                      . $self->config->{charset}
                      . ';' );
                $res->finalize;
            }
        );
    }

    $builder->mount(
        '/s' => Plack::App::File->new( root => './share/static' )->to_app
    );

    $builder->mount(
        '/s/bulma.min.css' => Plack::App::File->new(
            file => './inc/bulma/css/bulma.min.css'
        )->to_app
    );

    $builder->mount(
        '/favicon.ico' =>
          Plack::App::File->new( file => './share/static/favicon.ico' )->to_app
    );

    $self->default_middleware;

  };

ADJUST : params (:$middleware //= []) {
    foreach my $mw (@$middleware) {
        my ( $pkg, $optstr ) = ( $mw =~ /^([a-z0-9:_]+)(?:=(.+))?$/ig );

        my %opt;

        foreach my $opt ( split /,/, $optstr ) {
            my ( $name, $val ) = ( $opt =~ // );
            $opt{$name} = $val // 1;
        }

        $builder->add_middleware( $pkg, %opt );
    }
};

ADJUST {
    dmsg $param;
    $self->merge_config($param);
}

method add_middleware ( $name, @arg ) {
    push @$middleware, $builder->add_middleware( $name, @arg );
}

method default_middleware {
    if ( $ENV{DEBUG} || $self->debug ) {
        $builder->add_middleware('Debug');
        $builder->add_middleware('StackTrace');
    }

    $builder->add_middleware_if(
        sub ($env) { !$env->{REMOTE_ADDR} },
        "Plack::Middleware::ReverseProxy"
    );

    $builder->add_middleware(
        'Auth::Basic',
        authenticator => sub ( $user, $pass, $env ) {
            foreach my ($dbuser) ( $self->userdb->@* ) {
                if ( $user eq $$dbuser{user}
                    && WWW::srvpath->valid_pass( $pass, $$dbuser{crypt} ) )
                {
                    return 1;
                }
            }
            return undef;
        }
    ) if scalar $self->userdb->@*;
}

__END__

=encoding utf-8

=head1 NAME

WWW::srvpath - It's new $module

=head1 SYNOPSIS

    use WWW::srvpath;

=head1 DESCRIPTION

WWW::srvpath is ...

=head1 LICENSE

Copyright (C) Ian Bradley.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Ian Bradley E<lt>crabapp@hikki.techE<gt>

=cut

