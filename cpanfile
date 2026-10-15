use utf8;
use v5.44;
use subs qw'requires recommends on feature';

requires 'perl', 'v5.44';
requires 'Const::Fast';

use Const::Fast;

sub distname ($pkgname) {
    const my $pkg2dist => qr/::/;
    ( $pkgname =~ s/$pkg2dist/-/rg );
}

const our %pinned => (
    CRABAPP => {
        'Path::Try'          => '0.01_2',
        'IO::Handle::Common' => '0.01_3',
        'IPC::Nosh'          => '0.01.4',
        'Frame'              => '0.1.6.0'
    }
);

foreach my ( $author, $modules ) (%pinned) {
    foreach my ( $name, $ver ) (%$modules) {
        requires $name, $ver,
          dist => "$author/" . distname($name) . "-$ver-TRIAL.tar.gz";
    }
}

requires 'perl', 'v5.44';
requires 'meta';

requires 'Object::Pad';
requires 'Const::Fast';
requires 'Crypt::Argon2';
requires 'Cwd';
requires 'File::ConfigDir';

# requires 'IO::Handle::Common', '0.01_3',
# dist => "CRABAPP/IO-Handle-Common-0.01_3-TRIAL.tar.gz";

requires 'IO::Socket::SSL';

# requires 'IPC::Nosh', '0.01.4',
# dist => "CRABAPP/IO-Nosh-0.01.4-TRIAL.tar.gz";

requires 'Net::SSLeay';

# requires 'Path::Try', '0.01_3';

requires 'Plack::App::Directory';
requires 'Plack::Builder';
requires 'Plack::MIME';
requires 'Plack::Runner';
requires 'MIME::Types';

requires 'Syntax::Keyword::Dynamically';

# serialization
requires 'TOML::Tiny';
requires 'JSON::MaybeXS';

requires 'Time::Moment';
requires 'Time::Piece';

# app server and interface with reverse proxy i.e. nginx
#requires 'Frame';
requires 'Starlet';
requires 'Server::Starter';

on 'test' => sub {
    requires 'Test::More', '0.98';
};

on 'develop' => sub {
    requires 'Module::Build::Tiny';
    requires 'Devel::Trace';
    requires 'Plack::Middleware::StackTrace';
    recommends 'Minilla';
    recommends 'Perl::Critic';
    recommends 'Perl::Tidy';
    recommends 'Carton';
    recommends 'App::FatPacker';
}

