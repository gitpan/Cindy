# $Id: Cindy.pm 16 2009-08-15 14:18:37Z jo $
# Cindy - Content INjection 
#
# Copyright (c) 2008 Joachim Zobel <jz-2008@heute-morgen.de>. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#

package Cindy;

use strict;
use warnings;

use base qw(Exporter);

our $VERSION = '0.05';

our @EXPORT= qw(get_html_doc get_xml_doc 
                parse_html_string parse_xml_string 
                parse_cis parse_cis_string
                inject dump_xpath_profile);

use XML::LibXML;
use Cindy::Sheet;
#use Memoize;
#memoize('get_doc');
 
my $parser = XML::LibXML->new();

sub get_html_doc($)
{
  my ($file)  = @_;
  return $parser->parse_html_file($file);
}

sub get_xml_doc($)
{
  my ($file)  = @_;
  return $parser->parse_file($file);
}

sub parse_html_string($)
{
  my ($string)  = @_;
  return $parser->parse_html_string($_[0]);
}

sub parse_xml_string($)
{
  return $parser->parse_string($_[0]);
}

sub parse_cis($)
{
  return Cindy::Sheet::parse_cis($_[0]);
}

sub parse_cis_string($)
{
  return Cindy::Sheet::parse_cis_string($_[0]);
}

#
# Get a copied doc. root for modification.
#
sub get_root_copy($)
{
  my ($doc)   = @_;
  my $root  = $doc->documentElement();
  return $root->cloneNode( 1 );
}

sub dump_xpath_profile()
{
  Cindy::Injection::dump_profile();
}

sub inject($$$)
{
  my ($data, $doc, $descriptions) = @_;
  my $docroot = get_root_copy($doc);
#  my $dataroot = get_root_copy($data);
  my $dataroot = $data->getDocumentElement();
  # Create a root description with action none 
  # to hold the description list 
  my $descroot = Cindy::Injection->new(
      '.', 'none', '.', $descriptions);
   
  # Connect the copied docroot with the output document.
  # This has to be done before the tree is matched.
  my $out = XML::LibXML::Document->new($doc->getVersion, $doc->getEncoding);
  $out->setDocumentElement($docroot);
 
  # Run the sheet 
  $descroot->run($dataroot, $docroot);  

  return $out;
}

1;


__END__

=head1 NAME

Cindy - use unmodified XML or HTML documents as templates.

=head1 SYNOPSIS

  use Cindy;
  
  my $doc = get_html_doc('cindy.html');
  my $data = get_xml_doc('cindy.xml');
  my $descriptions = parse_cis('cindy.cjs');
  
  my $out = inject($data, $doc, $descriptions);
  
  print $out->toStringHTML();

=head1 DESCRIPTION

C<Cindy> does Content INjection into XML and HTML documents.
The positions for the modifications as well as for the data
are identified by xpath expressions. These are kept in a seperate file
called a Content inJection Sheet. The syntax of this CJS  file (the ending 
.cis implies a japanese charset in the apache defaults)
remotely resembles CSS. The actions for content modification are
those implemented by TAL.

=head2 CJS SYNTAX

The syntax for content injection sheets is pretty simple. In most cases
it is

  <source path> <action> <target path> ;

The source and target path are xpath expressions. The action describes 
how to move the data. The whitespace before the terminating ; is required,
since xpath expressions may end with a colon. The xpath expressions must 
not contain whitespaces. If the syntax for an action is different this
is documented with the action.

Everything from a ; to the end of the line is ignored and can be used 
for comments. 

=head2 CJS ACTIONS

Actions locate data and document nodes and perform an operation that
creates a modified document.

All source paths for actions other than repeat should locate one node.
Otherwise the action is executed for all source nodes on the same target.
The action is executed for all target nodes. 

Actions are executed in the order they appear in the sheet. Subsheets 
are executed after the enclosing sheet. 

The following example illustrates the effect of exectuion order. 
If a target node is omitted, an action that changes its content 
will not have any effect. 

  true()    omit-tag  <target> ;
  <source>  content   <target> ;

So the above is not equvalent to the replace action.

Execution matches document nodes and then data nodes. Thereafter 
the actions are executed. Since execution of a repeat action copies
the document node for each repetition, changes to this node
done after the repeat are lost. At last this is recursively done for 
all subsheets.

As an unfortunate consequence matches on subsheet doc nodes do see the 
changes done by actions from enclosing sheets. This behaviour will 
hopefully change in future releases.

=head3 content

All child nodes of the target node are replaced by child nodes of the 
source node. This means that the text of the source tag with all tags 
it contains replaces the content of the target tag. If data is not
a node, it is treated as text.

=head3 replace

The child nodes of the source node replace the target node and all its 
content. THis means that the target tag including any content is replaced
by the content of the subtag. This is equivalent to

  <source>  content   <target> ;
  true()    omit-tag  <target> ;

=head3 omit-tag

The source node is used as a condition. If it exists and if its text 
content evaluates to true the target node is replaced by its children.
This means that if the source tag exists and its content is not '' or
0 the target tag is removed while its content remains.

=head3 attribute

The syntax has an additional field atname

  <source>  content   <target> <atname> ;

that holds the name of the attribute. If the source node exists, its 
content replaces or sets the value of the atname attribute of the 
target node. If the source node does not exist the attribute atname
is removed from the target node.

=head3 condition

The source node is used as a condition. If it exists and if its text 
content evaluates to true nothing is done. Otherwise the target node 
and its children are removed. This means that the target tag is removed 
if the source tage does not exist or contains '', 0 or 0.0 whileit is 
left untouched otherwise.

=head3 repeat

The repeat action is the CJS equivalent of a template engines loop. For 
each match of the source path the source node and the target node are 
used as root nodes for a sequence of actions. The syntax is

  <source>  repeat   <target> {
    <actions>
  } ;

=head1 AUTHOR

Joachim Zobel <jz-2008@heute-morgen.de> 

=head1 SEE ALSO

See Cindy/Sheet.pm for the RecDescent grammar for content injection sheets. 

