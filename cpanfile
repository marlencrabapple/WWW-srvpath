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
        'Adjust::Params' => '0.01_06',
        'Path::Try'          => '0.01_03',
        'IO::Handle::Common' => '0.01_08',
        'IPC::Nosh'          => '0.01_05',
        'Frame'              => '0.01_08'
    }
);

foreach my ( $author, $modules ) (%pinned) {
    foreach my ( $name, $ver ) (%$modules) {
        requires $name, $ver,
          dist => "$author/" . distname($name) . "-$ver-TRIAL.tar.gz";
    }
}

requires 'meta';
requires 'Object::Pad';
requires 'Const::Fast';
requires 'Crypt::Argon2';
requires 'Cwd';
requires 'File::HomeDir';
requires 'File::ConfigDir';
requires 'IO::Socket::SSL';
requires 'Net::SSLeay';
requires 'Plack::App::Directory';
requires 'Plack::Builder';
requires 'Plack::MIME';
requires 'Plack::Runner';
requires 'MIME::Types';
requires 'Syntax::Keyword::Dynamically';
requires 'TOML::Tiny';
requires 'JSON::MaybeXS';
requires 'Time::Moment';
requires 'Time::Piece';
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

