# $Id: Sheet.pm 107 2011-04-18 17:42:42Z jo $
# Cindy::Sheet - Parsing Conten Injection Sheets
#
# Copyright (c) 2008 Joachim Zobel <jz-2008@heute-morgen.de>. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
package Cindy::Sheet;

use strict;
use warnings;

use Cindy::CJSGrammar;
use Cindy::Injection;
use Cindy::Log;

#$::RD_TRACE = 1;
#$::RD_HINT = 1;
#$::RD_WARN = 1;

sub PARSER { 
  return Cindy::CJSGrammar->new()
  or die "Faild to create CJSGrammar.";
}

sub warn_on_errors($)
{
  my ($errors) = @_;
  if ($errors and @{$errors}) {
    foreach my $ref (@{$errors}) {
      my ($error, $line) = @$ref;
      Cindy::Log::WARN "line $line: $error\n";
    }
  }
  return 0; 
}

#
# parse_cis
#
# file - The name of the file to read the injection sheet from
#
# return: A reference to a array of injections obtained from 
#         parsing. 
#
sub parse_cis($)
{
  my ($file) = @_;
  open(my $CIS, '<', $file) 
  or die "Failed to open $file:$!";
  my $text;
  read($CIS, $text, -s $CIS);
  close($CIS);
  my $rtn = PARSER->complete_injection_list($text);
  # warn_on_errors($parser->{errors});
  return $rtn;
}

#
# parse_cis_string
#
# $ - The injection sheet as a string
#
# return: A reference to a array of injections obtained from 
#         parsing. 
#
sub parse_cis_string($)
{
  return PARSER->complete_injection_list($_[0]);
}

1;

