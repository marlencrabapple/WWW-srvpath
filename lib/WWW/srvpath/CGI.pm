#!/usr/bin/env perl

use Object::Pad ':experimental(:all)';

package WWW::srvpath::CGI;

class WWW::srvpath::CGI : does(WWW::srvpath::Base) : does(Adjust::Params) :
  isa( Plack::App::WrapCGI);

use utf8;
use v5.44;

