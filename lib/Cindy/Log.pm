# $Id: Log.pm 117 2013-01-27 15:01:24Z jo $
# Cindy::Log - Logging for Cindy
#
# Copyright (c) 2008 Joachim Zobel <jz-2008@heute-morgen.de>. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#


package Cindy::Log;

use strict;
use warnings;

use base qw(Exporter);

our @EXPORT= qw(DEBUG INFO WARN ERROR FATAL); 

## no critic (ProhibitStringyEval);
# Strings are evaled to avoid compile time checking
# DO NOT FORGET TO CHECK iF THESE MODULES COMPILE
# if you changed them.
BEGIN {
  eval (q|
    use Cindy::Log::Apache2;
    1;
  |)
  or eval(q|
    use Log::Log4perl qw(:easy);
    1;
  |)
  or eval(q|
    use Cindy::Log::Default;
    1;
  |);
}
## use critic

1;

