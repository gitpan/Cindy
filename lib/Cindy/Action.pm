# $Id: Action.pm,v 1.2 2008-11-23 14:58:44 jo Exp $
# Cindy::Action - Action (content, replace,...) implementation
#
# Copyright (c) 2008 Joachim Zobel <jz-2008@heute-morgen.de>. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#

#
# The funtions  in this package manipulate the 
# given node using the given data.  
# 

package Cindy::Action;

use strict;
use warnings;

use XML::LibXML;

#
# Helpers/Wrappers
#

#
# Evaluate data node as boolean
#
sub is_true($)
{
  my ($data) = @_;

  return 0 if (!$data); 

  return $data->textContent if ($data->can('textContent'));

  return $data->value if ($data->can('value')); 

}

#
# Get list of child nodes
#
sub copy_children($$)
{
  my ($data, $node) =@_;

  if (defined($data)) {
    if ($data->isa('XML::LibXML::Attr') ) {
      # Replace an attribute node with a text node
      return ($node->ownerDocument->createTextNode(
                      $data->textContent));
    } else {
      return map {$_->cloneNode(1);} $data->childNodes() ;
    }
  } else {
    return ();
  }
}

#
# The node only survives if data exists and its content
# evalutes to true. 
#
sub condition($$) 
{
  my ($node, $data) = @_;  

	#	remove node 
  if  (!is_true($data)) {
    my $parent = $node->parentNode;
    $parent->removeChild( $node )
    or warn "Node ".$node->nodeName
            ." could not be removed from ".$node->nodeName.".";
  }

  return 0;
}

#
# The node gets a copy of the data children to replace
# the existing ones. This copies the text held by data
# as well as possible element nodes (e.g. <b>) 
#
sub content($$) 
{
  my ($node, $data) = @_;  

  # An a node without children will remove all
  # target children. If however no node matched,
  # the target node will be left unchanged. 
  if (defined($data)) {
    $node->removeChildNodes();	
  }
  foreach my $child (copy_children($data, $node)) {
    $node->appendChild($child);
  }

  return 0;
}

#
# The node is removed and the parent node gets 
# the data children instead. 
#
sub replace($$) 
{
  my ($node, $data) = @_;  

  my $parent = $node->parentNode;
  
  foreach my $child (copy_children($data, $node)) {
    $parent->insertBefore($child, $node);
  }

  # An a node without children will remove all
  # target children. If however no node matched,
  # the target node will be left unchanged. 
  if (defined($data)) {
    $parent->removeChild($node);
  }

  return 0;
}

#
# If data and its text content evaluate to true the node is 
# removed and the parent node gets the children instead.
#
sub omit_tag($$) 
{
  my ($node, $data) = @_;  

  if (is_true($data)) {
    my $parent = $node->parentNode;

    foreach my $child ($node->childNodes()) {
      $parent->insertBefore($child->cloneNode(1), $node);
    }
  
    $parent->removeChild($node);
  }
  return 0;
}

#
# Sets or removes an attribute from an element node.
# If data is undefined the element is removed, otherwise
# the data text content is used as the attribute value. 
# Note the additional parameter name which passes the
# attribute name. 
#
sub attribute($$$) 
{
  my ($node, $data, $name) = @_;  

  if ($data) {
    my $value = $data;
    #TODO: Think about this:
    $value = $data->textContent if ($data->can('textContent'));
    $value = $data->value if ($data->can('value'));
    $node->setAttribute($name, $value);    
  } else {
    $node->removeAttribute($name);
  }

  return 0;
}

1;

