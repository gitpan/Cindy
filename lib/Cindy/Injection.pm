# $Id: Injection.pm 68 2010-04-23 20:49:07Z jo $
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

sub new($$$$;$$)
{
  my ($class, $xdata, $action, $xdoc, $opt, $xfilter) = @_;

  #get_logger->level($DEBUG);

  my $self = {
    xdata  => $xdata,
    action  => $action,
    xdoc => $xdoc,
  };

  # The meaning of the optional argument differs
  # depending on the action. 
  $self->{atname} = $opt if ( $action eq 'attribute' );
  $self->{subsheet} = $opt if ( $action eq 'repeat'
                             or $action eq 'none' );
  $self->{xfilter} = $xfilter if ( $action eq 'repeat' );

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
  DEBUG "Matched $cnt $what nodes for action "
    .$self->{action}.".";

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
# Check if the injection matches a filter expression.
# return ($self) in case of a match, () otherwise. 
#
sub filter 
{
  my ($self) = @_;
  my $xfilter = $self->{xfilter};
  if ( not $xfilter 
       # avoid filtering the remove action
    or $self->{action} ne 'repeat') {
    return ($self); 
  }

  INFO "Filtering with $xfilter.";  

  my $fragment = XML::LibXML::DocumentFragment->new();
  my $context = XML::LibXML::Element->new( 'ROOT' );
  my $doc = XML::LibXML::Element->new( 'DOC' );
  my $data = XML::LibXML::Element->new( 'DATA' );

  $fragment->appendChild($context);
  $context->appendChild($doc);
  $context->appendChild($data);

  $doc->appendChild($self->{doc}->cloneNode(1)); # if ($self->{doc}->toString());
  $data->appendChild($self->{data}->cloneNode(1)); # if ($self->{data}->toString());

  my @found = find_matches($context, 
                  "self::node()[boolean($xfilter)]");
  if ( scalar(@found) >= 1 ) { 
      DEBUG "Match. Kept.";
      return ($self);
  } else {
    DEBUG "No match. Removed.";
    return;
  }
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
    { # Check for removals
      my ($cnt_bef, $cnt_aft) =
          (scalar(@{$self->{subsheet}}), scalar(@subsheets));
      DEBUG "Length of subsheet reduced from $cnt_bef to $cnt_aft."
          if ($cnt_bef != $cnt_aft);
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
# The subsheet is a list of injections. It
# may get longer during the steps of run.
# The doc side is matched first because the 
# in case of repeat the matched doc fragments
# are copied.
sub run($;$$)
{
  my ($self, $dataroot, $docroot) = @_;
  $dataroot ||= $self->{data}; 
  $docroot  ||= $self->{doc};

  return ($self) unless $self->{subsheet};

  # Match all doc nodes.
  DEBUG "WILL MATCH DOC";
  $self->subsheetsDo(sub {$_[0]->matchDoc($docroot)});
  # Append remove to all repeat nodes
  DEBUG "WILL APPEND REMOVE";
  $self->subsheetsDo(sub {$_[0]->appendRemoveToRepeat();});
  # Match all data nodes
  DEBUG "WILL MATCH DATA";
  $self->subsheetsDo(sub {$_[0]->matchData($dataroot)});
  # Filter all subsheets
  DEBUG "WILL FILTER";
  $self->subsheetsDo(sub {$_[0]->filter($self->{xfilter})});
  # Execute the actions.
  DEBUG "WILL EXECUTE"; 
  $self->subsheetsDo(sub {$_[0]->execute();});  

  # Recursion into the subsheets subsheets.
  DEBUG ">>>>> WILL RUN";
  $self->subsheetsDo(sub {$_[0]->run();});  
  DEBUG ">>>>> DID RUN";  

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


