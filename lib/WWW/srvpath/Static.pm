use Object::Pad ':experimental(:all)';

package WWW::srvpath::Static;
role WWW::srvpath::Static;

use utf8;
use v5.44;

use MIME::Types 'by_suffix';
use Plack::MIME;

Plack::MIME->set_fallback( sub { ( by_suffix $_[0] )[0] } );

method mime_type : common ($ext) {
    Plack::MIME->mime_type($ext);
}
