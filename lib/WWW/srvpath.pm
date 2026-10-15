use Object::Pad ':experimental(:all)';

package WWW::srvpath;

class WWW::srvpath : does(WWW::srvpath::Config) : does(WWW::srvpath::User);

use utf8;
use v5.40;

our $VERSION = "0.01";

use builtin;
use Path::Try;
use List::Util 'all';
use MIME::Types 'by_suffix';
use Plack::Builder;
use Plack::App::Directory;
use Plack::MIME;
use List::Util qw'first all';
use IO::Handle::Common;

use WWW::srvpath::User;
use WWW::srvpath::Util;

Plack::MIME->set_fallback( sub { ( by_suffix $_[0] )[0] } );

field $debug   : param : accessor //= $ENV{DEBUG};
field $root    : param //= '.';
field $mount   : param //= '/';
field $verbose : param //= false;
field $index   : param //= false;

field $app;
field $builder { Plack::Builder->new }

ADJUSTPARAMS($param) {
    if ( all { $_ } @$param{qw'user pwhash'} ) {
        $self->add_user( @$param{qw'user pwhash'} );
    }

    if ( all { $_ } @ENV{qw'SRVPATH_USER SRVPATH_PWHASH'} ) {
        $self->add_user( $ENV{SRVPATH_USER}, $ENV{SRVPATH_PWHASH} );
    }

    foreach my $user ( $self->config->{userdb}->@* ) {
        $self->add_user( $$user{name},
            map { ( $_ => $$user{$_} ) } grep { $_ ne 'name' } keys %$user );
    }
}

method to_psgi {
    $builder->to_app(@_);
}

method to_app {
    $self->to_psgi(@_);
}

ADJUST {
    $app = Plack::App::Directory->new( root => $root );

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

    $builder->mount( $mount => $app->to_app );

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

