#!perl -w
use strict;
use Test::More tests => 3;
require_ok("Email::LocalDelivery");
require_ok("Email::LocalDelivery::Mbox");
require_ok("Email::LocalDelivery::Maildir");