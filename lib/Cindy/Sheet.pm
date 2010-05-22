# $Id: Sheet.pm 81 2010-05-21 12:03:07Z jo $
# Cindy::Sheet - Parsing Conten Injection Sheets
#
# Copyright (c) 2008 Joachim Zobel <jz-2008@heute-morgen.de>. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
package Cindy::Sheet;

#our @EXPORT= qw(parse_cis parse_cis_string); 

use strict;
use warnings;

use Parse::RecDescent;
use Cindy::Injection;
use Cindy::Log;

#$::RD_TRACE = 1;
#$::RD_HINT = 1;
#$::RD_WARN = 1;

sub PARSER { 
  return Parse::RecDescent->new(q%
       { my $selector = 'xpath'; }

xpath:  /\\"[^\\"]+\\"/ 
        {$return = substr($item[1], 1, -1);}
xpath:  /\\S+/
atname: /\\w[\\w\\d.:-]*/

action: /content|replace|omit-tag|condition|comment/
attribute: /attribute/
repeat: /repeat/
selector: /css|xpath/

# A condition is an xpath before a sublist
condition: xpath ..."{"
       {$item[1];}
# Empty injection (comment)
injection: .../\s*;/ {0;}
injection: xpath action <commit> xpath 
       {Cindy::Injection->new(@item[1,2,4], $selector);} 
injection: xpath attribute <commit> xpath atname  
       {Cindy::Injection->new(@item[1,2,4], $selector, 
                              atname => $item{atname});} 
injection: xpath repeat <commit> xpath condition(?) sublist  
       {Cindy::Injection->new(@item[1,2,4], $selector, 
                              sublist => $item{sublist}, 
                              xfilter => $item{'condition(?)'}->[0]);}
# No matches (uncommit to try the resync rule below) 
injection: <error> 
# resume parsing after the next separator and output the error
injection: /[^;]+;[^\\n]*\\n?/ warn

# The rest of the line after a ; is ignored
comment: /;/ <commit> <skip: qr/[^\\n]*/> /\\n?/
separator: comment(s)
separator: ..."}"
separator: .../\Z/
separator: <error:Expected ";" but found  "}.($text=~/(.*)\\n/,$1).qq{" instead.>
separator: /[^;]+;[^\\n]*\\n?/ warn

# Switch between selectors
usage: comment(s?) "use" selector separator 
       {$selector = $item{selector};}

# A single "statement"
full_injection: injection separator {$item[1];}

# Sublists
sub_injection: ..."}" <commit><reject>
sub_injection: full_injection
sub_injection_list: sub_injection(s) {[grep($_, @{$item[1]})];} 
sublist: "{" <commit> sub_injection_list "}" {$item[3];}

# Main injection list
injection_list: full_injection(s) {[grep($_, @{$item[1]})];} 
complete_injection_list: usage(?) injection_list /\Z/ {$item{injection_list};}
complete_injection_list: <error> | warn

# output error action
warn: {Cindy::Sheet::warn_on_errors($thisparser->{errors});}

%)
or die "Invalid RecDescent grammar.";
# Note that // is not a usable comment delimiter with XPath expressions
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

sub parse_cis_string($)
{
  return PARSER->complete_injection_list($_[0]);
}

1;

