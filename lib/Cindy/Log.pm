# $Id: Log.pm 6 2009-05-14 18:19:17Z jo $
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

1;

