# $Id: Injection.pm 65 2010-04-01 17:22:14Z jo $
# Cindy::Injection - Injections are the elements of content injection 
# sheets.
#
# Copyright (c) 2008 Joachim Zobel <jz-2008@heute-morgen.de>. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#

package Cindy::Injection;

use strict;
use warnings;

use XML::LibXML;

use Cindy::Log;
use Cindy::Profile;
require Cindy::Action;

sub new($$$$;$)
{
  my ($class, $xdata, $action, $xdoc, $opt) = @_;

  #get_logger->level($DEBUG);

  my $self = {
    xdata  => $xdata,
    action  => $action,
    xdoc => $xdoc,
  };

  # The meaning of the optional argument differs
  # depending on the action. 
  $self->{atname} = $opt if ($action eq 'attribute');
  $self->{subsheet} = $opt if ( $action eq 'repeat'
                             or $action eq 'none' );

  return bless($self, $class); 
}

#
# Make a copy
#
sub clone($)
{
  my ($self) = @_;

  my %rtn = %{$self};

  return bless(\%rtn, ref($self));
}

my $prof = Cindy::Profile->new();
sub dump_profile()
{
  $prof = Cindy::Profile->new();
}
END {
  $prof = undef;
}

#
# Wrapper for find.
#
sub find_matches($$) {
  my ($data, $xpath) = @_;

  my @data_nodes = ();

  DEBUG "Matching '$xpath'.";

  # No xpath, no results
  return @data_nodes unless ($xpath);

  my $cp = Cindy::Profile::before();   
  my $found = $data;
  # . matches happen very often and are quite expensive
  if ($xpath ne '.') {
    $found = eval {$data->find( $xpath );};
  }
  $prof->after($cp, $xpath);
  if ($@) {
    ERROR "Error searching $xpath:$@";
  } else {
    if ($found->isa('XML::LibXML::NodeList')) {
      @data_nodes = $found->get_nodelist();
      DEBUG "Found "
              # toString is not called automagically
              .join('|', map {$_->toString();} @data_nodes).'.';
    } else {
      DEBUG "Matched '$xpath', found $found.";
      @data_nodes = ($found);
    }
  }

  return @data_nodes;
}

#
# Helper for debugging
#
sub debugNode($)
{
  my ($nd) = @_;
  return $nd. '/' .$nd->nodeName." (".$nd->nodeType.")";
}

#
# Matches all doc nodes
#
sub matchDoc($$)
{
  my ($self, $doc) = @_;
  return $self->match($doc, 'doc');
}

#
#Matches all data nodes 
# 
sub matchData($$)
{
  my ($self, $data) = @_;
  return $self->match($data, 'data');
}

#
# Does doc/data matching. The xpath from xdoc/xdata
# is used to match nodes that are then stored as doc/data
# properties of cloned nodes. A list of such nodes is 
# returned.
#
# self - This injection.
# $context - The context node for the match.
# $what - One of 'doc' or 'data'.
# return - A list of self clones holding the matches.
#
sub match($$$)
{
  my ($self, $context, $what) = @_;

  # Find the nodes matching the xpath
  my @nodes = find_matches($context, $self->{"x$what"}); 

  my $cnt = scalar(@nodes);
  DEBUG "Matched $cnt $what nodes.";

  my @rtn = ();
  foreach my $node (@nodes) {
    # clone self
    my $clone = $self->clone();
    $clone->{$what} = $node;
    push(@rtn, $clone);
  } 
  
  return @rtn;
}

#
# Execute a member function on all subsheet elements
# and replace the subsheet with the concatenated returns
# of the calls.
#
sub subsheetsDo($$)
{
  my ($self, $do) = @_;
  DEBUG "Entered subsheetsDo.";

  # Without a subsheet, nothing is done.
  if ($self->{subsheet}) {
    DEBUG "Found subsheet.";

    my @subsheets = ();
    foreach my $inj (@{$self->{subsheet}}) {
      push(@subsheets, &{$do}($inj));
    }
    $self->{subsheet} = \@subsheets;
  }
}

#
# Returns an additional remove action to remove the original 
# of the target doc node after a sequence of replace actions.
#
sub appendRemoveToRepeat()
{
  my ($self) = @_;

  if ($self->{'action'} eq 'repeat') {
    DEBUG "Appending remove.";

    # rmv has the same doc node as inj.
    my $rmv = $self->clone();

    # We need a cheap match, since matchData
    # will be done. The result of the match will 
    # be ignored anyway.
    $rmv->{xdata} = '.';
    $rmv->{action} = 'remove';

    return ($self, $rmv); 
  }
  
  return ($self);
}
  
#
# Executes nodes where doc and data have been matched 
# before. Execution directly changes the doc.
#
sub execute()
{
  my ($self) = @_;

  DEBUG "Will execute $self->{action}.";

  if ($self->{action} eq 'repeat') {
    $self->{doc} =
    action($self->{action},
           $self->{data},
           $self->{doc},
           $self->{atname});
  } else {
    action($self->{action},
           $self->{data},
           $self->{doc},
           $self->{atname});
  }

  return ($self);
}

#
# This does all the work on the subsheet.
#
sub run($;$$)
{
  my ($self, $dataroot, $docroot) = @_;
  $dataroot ||= $self->{data}; 
  $docroot  ||= $self->{doc};

  return ($self) unless $self->{subsheet};

  DEBUG "Entered run.";

  # Match all doc nodes.
  $self->subsheetsDo(sub {$_[0]->matchDoc($docroot)});
  # Append remove to all repeat nodes
  $self->subsheetsDo(sub {$_[0]->appendRemoveToRepeat();});
  # Match all data nodes
  $self->subsheetsDo(sub {$_[0]->matchData($dataroot)});

  # Execute the actions. 
  $self->subsheetsDo(sub {$_[0]->execute();});  

  # Recursion into the subsheets subsheets.
  $self->subsheetsDo(sub {$_[0]->run();});  

  return ($self);
}

#
# Stringifies a node.
#
sub dbg_dump($)
{
  my ($x) = @_; 
  return 'undef' if (!defined($x));
  return $x->toString() if ($x->can('toString'));
  return $x;
}

#
# A funtion to execute the named action by calling the
# Action::<action> function.
#
sub action($$$;$)
{
  my ($action, $data, $node, $opt) = @_;

  DEBUG "Doing $action on ".dbg_dump($node)." with ".
            dbg_dump($data).":";

  $action =~ s/-/_/g;
  # This is possibel with strict refs
  my $call = \&{"Cindy::Action::$action"};
  my $rtn = &$call($node, $data, $opt);

  DEBUG $node->toString()."\n\n";  

  return $rtn;
}

1;

# UNFUG?:
# Match all 1st level actions.
# Match all 2nd level actions without copying.
# Execute all 1st level actions.
# Copy all nodes involved in repeat actions with their 
#   associated 2nd level actions.
# Execute all 2nd level actions.
# 

#
# Do all doc matches and store the results. This includes the 
#   subsheet matches.
# The result is a list actions with its doc. paths replaced with nodes.
# This is done for subsheets as well.
#

# 
# Do all doc matches and store the results. This includes the 
#   subsheet matches.
# Repeat actions are treated specially. They spawn of a remove action.
#   This needs to be done before data matching expands the repeats.
# Match the data. Note that this does not copy the previously matched
#   doc nodes. Only references are copied. Otherwise 
#   actions on subsheets would be lost when copying the doc nodes
#   while doing a repeat action.
# Execute all actions. Note that executing repeat clones the doc nodes.
#



