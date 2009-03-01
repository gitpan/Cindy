# $Id: Cindy.pm,v 1.3 2008-11-25 18:28:08 jo Exp $
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

our $VERSION = '0.03';

our @EXPORT= qw(get_html_doc get_xml_doc 
                parse_html_string parse_xml_string 
                parse_cis parse_cis_string
                inject);

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

sub inject($$$)
{
  my ($data, $doc, $descriptions) = @_;
  my $docroot = get_root_copy($doc);
#  my $dataroot = get_root_copy($data);
  my $dataroot = $data->getDocumentElement();
  # Create a root description to hold the description list 
  my $descroot = Cindy::Injection->new(
      '.', 'none', '.', $descriptions);
   
  # There are 2 steps because all xpath matches have to be done on the 
  # unmodified document.
  
  # Connect the copied docroot with the output document.
  # This has to be done before the tree is matched.
  my $out = XML::LibXML::Document->new($doc->getVersion, $doc->getEncoding);
  $out->setDocumentElement($docroot);
  
  # Step 1: match
  my @injections = $descroot->matchAt($dataroot, $docroot);
  
  # Step 2: inject the matches
  foreach my $func (@injections) {&{$func}();}

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
called a Content Injection Sheet. The syntax of this CIS file
remotely resembles CSS. The actions for content modification are
those implemented by TAL.

=head2 CIS SYNTAX

The syntax for content injection sheets is pretty simple. In most cases
it is

  <source path> <action> <target path> ;

The source and target path are xpath expressions. The action describes 
how to move the data. The whitespace before the terminating ; is required,
since xpath expressions may end with a colon. The xpath expressions must 
not contain whitespaces. If the syntax for an action is different this
is documented with the action.

Everything form a ; to the end of the line is ignored and can be used 
for comments. 

=head2 CIS ACTIONS

All source paths for actions other than repeat should locate one node.
Otherwise only the first one is used. The action is executed for all 
target nodes. 

All xpath expressions are matched before the actions are executed. 
The source nodes are not modified during the execution. 
Order of execution does matter. If a e.g. target node 
is omitted, an action that changes its content will not have any 
effect. 

  true()    omit-tag  <target> ;
  <source>  content   <target> ;

So the above is not equvalent to the replace action.

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

The repeat action is the CIS equivalent of a template engines loop. For 
each match of the source path the source node and the target node are 
used as root nodes for a sequence of actions. The syntax is

  <source>  repeat   <target> {
    <actions>
  } ;

=head1 AUTHOR

Joachim Zobel <jz-2008@heute-morgen.de> 

=head1 SEE ALSO

See Cindy/Sheet.pm for the RecDescent grammar for content injection sheets. 

