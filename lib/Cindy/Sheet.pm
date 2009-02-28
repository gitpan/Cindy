# $Id: Sheet.pm,v 1.1.1.1 2008-11-20 22:08:36 jo Exp $
# Cindy::Sheet - Parsing Conten Injection Sheets
#
# Copyright (c) 2008 Joachim Zobel <jz-2008@heute-morgen.de>. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
package Cindy::Sheet;

#our @EXPORT= qw(parse_cis parse_cis_string); 
 
use Parse::RecDescent;
use Cindy::Injection;
use Cindy::Log;
# For debugging
use Data::Dumper;


my $parser = Parse::RecDescent->new(q%

xpath:  /\\"[^\\"]+\\"/ 
        {$return = substr($item[1], 1, -1);}
xpath:  /\\S+/
atname: /\\w[\\w\\d.:-]*/

action: /content|replace|omit-tag|condition/
attribute: /attribute/
repeat: /repeat/

injection: xpath action xpath  
       {Cindy::Injection->new(@item[1..3]);} 
injection: xpath attribute xpath atname  
       {Cindy::Injection->new(@item[1..3], $item{atname});} 
injection: xpath repeat xpath "{" injection_list "}"  
       {Cindy::Injection->new(@item[1..3], $item{injection_list});}
# TODO: Improve handling of empty injections 
injection: {Cindy::Injection->new('.', 'none', '.', undef);}

injection_list: injection(s /;[^\\n]*\\n/)
        | {Cindy::Sheet::warn_on_errors($thisparser->{errors});}

%)
or die "Invalid RecDescent grammar.";
# Note that // is not a usable comment delimiter with XPath expressions
# comment: "#" /[^\\n]*/ "\\n"

#$::RD_TRACE = 1;

sub parse_cis($)
{
  my ($file) = @_;
  open(CIS, $file) 
  or die "Failed to open $file:$!";
  my $text;
  read(CIS, $text, -s CIS);
  close($text);
 #print Dumper($parser->injection_list($text));
  return $parser->injection_list($text);
}

sub warn_on_errors($)
{
  my ($errors) = @_;
  if ($errors and @{$errors}) {
    foreach my $error (@{$errors}) {
      WARN $error;
    }
  } else {
    WARN "Parsing did not find any rules."; 
  }  
}

sub parse_cis_string($)
{
  return $parser->injection_list($_[0]);
}

1;

