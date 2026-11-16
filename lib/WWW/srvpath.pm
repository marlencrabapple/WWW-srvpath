use Object::Pad ':experimental(:all)';

package WWW::srvpath;

class WWW::srvpath : does(WWW::srvpath::Config) : does(WWW::srvpath::User) :
  does(WWW::srvpath::Util);

use utf8;
use v5.40;

our $VERSION = "0.01_02";

use builtin;
use Path::Try;
use List::Util 'all';
use MIME::Types 'by_suffix';
use Plack::Builder;
use Plack::App::Directory;
use Plack::MIME;
use List::Util qw'pairmap first all';
use IO::Handle::Common;
use WWW::srvpath::DirIndex;

use subs qw'on_psgi to_app';

Plack::MIME->set_fallback( sub { ( by_suffix $_[0] )[0] } );

# field $path                     //= '.';
# field $mount                    //= '/';
field $verbose : param //= false;

# field $index                    //= false;
field $param //= {};

field $app;
field $builder = Plack::Builder->new;

ADJUST : params (:$user = undef, :$pwhash = undef, %param) {
    $param = \%param;
    if ( all { $_ } ( $user, $pwhash ) ) {
        $self->add_user( $user, $pwhash );
    }

    if ( all { $_ } @ENV{qw'SRVPATH_USER SRVPATH_PWHASH'} ) {
        $self->add_user(
            pairmap { ( user => $a, $pwhash => $b ) }
            @ENV{qw'SRVPATH_USER SRVPATH_PWHASH'}
        );
    }

    foreach my $user ( $self->config->{userdb}->@* ) {
        $user = $self->add_user( $$user{name},
            map { ( $_ => $$user{$_} ) } grep { $_ ne 'name' } keys %$user );

        $self->config->{userdb} = $user;

        # $self->config->write;
    }
  }

  method to_psgi {
    $builder->to_app(@_);
}

*to_app = \&to_psgi;

ADJUST : params (
  : $index //= 1,
  : $path  //= './',
  : $root //= $path,
  : $mount //= '/',
  : $cgi   //= builtin::false,
  %param
  ) {
    $path = path( $path // $root );

    if ( $path->is_dir ) {
        if ($index) {
            if ( $index == 1 ) {

                # $app = Plack::App::Directory->new( root => $root );
                $app = WWW::srvpath::DirIndex->new(
                    root   => $root,
                    config => $self->config
                );
            }
            else {
                $app = Plack::App::File->new(
                    root  => $path,
                    mount => $mount,
                    index => 1
                );
            }
        }
        else {
            $app = Plack::App::File->new( root => $path );
        }

    }
    elsif ($cgi) {
        $app =
          CGI::Emulate::PSGI->handler( CGI::Compile->compile( $path, $path ) );
    }
    else {
        $app = Plack::App::File->new( file => $path );
    }

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

                # dmsg $dbuser;
                if ( $user eq $$dbuser{user}
                    && WWW::srvpath->valid_pass( $pass, $$dbuser{crypt} ) )
                {
                    return 1;
                }
            }
            return undef;
        }
    ) if scalar $self->userdb->@*;

    $builder->mount( $mount => $app->to_app );
    $builder->mount(
        '/run_config',
        sub ($env) {
            my $req = Plack::Request->new($env);
            my $res = $req->new_response(200);

            $res->body( $self->json->encode( $self->config ) );
            $res->content_type(
                'application/json; charset=' . $self->config->{charset} . ';' );
            $res->finalize;
        }
    );

    $builder->mount(
        '/s' => Plack::App::File->new( root => './static' )->to_app
    );
    $builder->mount(
        '/s/bulma.min.css' => Plack::App::File->new(
            file => './inc/bulma/css/bulma.min.css'
        )->to_app
    );

    $builder->mount(
        '/favicon.ico' =>
          Plack::App::File->new( file => './static/favicon.ico' )->to_app
    );

    #  $r->get( '/s/:path' => StaticSrv->new( root => './static' )->to_route );
    # $r->get(
    #     '/s/bulma.min.css' => sub ( $c, @arg ) {
    #         const my $static =>
    #           StaticSrv->new( file => './inc/bulma/css/bulma.min.css' );

    #         my $res = $c->req->new_response;
    #         $res->status(200);
    #         $res->body( $static->file->openr_raw );
    #         $res;
    #     }
    # );

    # $r->get(
    #     'favicon.ico' => sub ( $c, @arg ) {
    #         const my $static =>
    #           StaticSrv->new( file => './static/favicon.ico' );

    #         my $res = $c->req->new_response;
    #         $res->status(200);
    #         $res->body( $static->file->openr_raw );
    #         $res;
    #     }
    # );

  }

  #   method root

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

