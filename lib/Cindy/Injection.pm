# $Id: Injection.pm,v 1.1.1.1 2008-11-20 22:08:36 jo Exp $
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
# Helper wrapper
#
sub find_matches($$) {
  my ($data, $xpath) = @_;

  my @data_nodes = ();

  my $found = eval {$data->find( $xpath );};
  if ($@) {
    ERROR "Error searching $xpath:$@";
  } else {
    DEBUG "Matched '$xpath', found $found.";

    if ($found->isa('XML::LibXML::NodeList')) {
      @data_nodes = $found->get_nodelist();
    } else {
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
# This function does the xpath matching. It recurses into
# subsheets. While doing this it creates closures for later 
# execution. This is necessary since no changes to the 
# document tree can take place before all the matches are 
# done.
# returns an array of closures to be executed later.
# 
sub matchAt($$$)
{
  my ($self, $data, $doc) = @_;

  my @data_nodes = find_matches($data, $self->{xdata}); 
  my @doc_nodes  = find_matches($doc, $self->{xdoc});
  if (!@doc_nodes) {
    INFO "No docnodes found for $self->{xdoc}.";
  }
  
  if (defined($self->{subsheet})) {
    # assert $action eq 'repeat'
    
    my @rtn = ();
    # Recursively match the subsheets 
    foreach my $locdoc (@doc_nodes) {
      # Keeping the parent in a variable won't
      # work since the parent changes.
      # my $parent = $locdoc->parentNode;
      foreach my $locdata (@data_nodes) {
        # Data for each data node is injected into a
        # seperate copy.
        my $newdoc = $locdoc->cloneNode(1);

        # Data is injected into the copy
        foreach my $subdesc (@{($self->{subsheet})}) {
          DEBUG "Calling match for doc. "
                    .$newdoc->nodeName." (".$newdoc->nodeType.").\n";
          push(@rtn,
               $subdesc->matchAt($locdata, $newdoc));
        }

        # The copy is inserted before the original
        push(@rtn, sub {     
          my $parent = $locdoc->parentNode;
          if  ( defined($parent) ) {
            DEBUG "Inserting the new node "
                    .debugNode($newdoc)." as a child of "
                    .debugNode($parent)." before "
                    .debugNode($locdoc).".";
            $parent->insertBefore($newdoc, $locdoc);
          }
        }) unless ($self->{action} eq 'none');
      }
      # The original is removed 
      push(@rtn, sub {
        my $parent = $locdoc->parentNode;
        if  ( defined($parent) ) {
          DEBUG "Removing the node ".debugNode($locdoc).".";
          $parent->removeChild($locdoc);
        }
      }) unless ($self->{action} eq 'none');
    }
    return @rtn;
  } else {
    if ( @data_nodes != 1  ) {
      my $cnt = scalar(@data_nodes);
      INFO "$cnt data nodes where 1 was expected for action $self->{action}.";
    }
    if ($self->{action} eq 'none') {
      DEBUG "Empty sheet encountered.";
      return ();
    } else {
      return map {makeAction($self->{action},
                             $data_nodes[0], 
                             $_,
                             $self->{atname});} @doc_nodes;        
    }
  }
          
}

sub dbg_dump($)
{
  my ($x) = @_; 
  return 'undef' if (!defined($x));
  return $x->toString() if ($x->can('toString'));
  return $x;
}

#
# return a funtion to execute the named action by calling the
# Action::<action> function.
#
sub makeAction($$$;$)
{
  my ($action, $data, $node, $opt) = @_;

  #get_logger->level($DEBUG);

  return sub {
    my $sdata =  
    DEBUG "Doing $action on ".dbg_dump($node)." with ".
            dbg_dump($data).":";

    $action =~ s/-/_/g;
    no strict qw(refs);
    my $rtn = &{"Cindy::Action::$action"}($node, $data, $opt);
    use strict qw(refs);

    DEBUG $node->toString()."\n\n";  

    return $rtn;
  }
}

1;

