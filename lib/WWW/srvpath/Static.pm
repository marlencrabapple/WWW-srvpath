use Object::Pad ':experimental(:all)';

package WWW::srvpath::Static;
role WWW::srvpath::Static;

use MIME::Types 'by_suffix';
use Plack::MIME;

Plack::MIME->set_fallback( sub { ( by_suffix $_[0] )[0] } );