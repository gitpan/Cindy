# $Id: Log.pm,v 1.1.1.1 2008-11-20 22:08:36 jo Exp $
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
use Cindy::Log::Default;
1;
|);
}

1;

