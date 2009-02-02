# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Cindy.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 2;
BEGIN { use_ok('Cindy') };

#########################

use Cindy;

my $cis = q|

/data/title/@test content   /html/head/title ;
/data/content     content   /html/body/h2[1] ;
/data/replace     replace   /html/body/p[1]/b[1] ;
/data/omit        omit-tag  /html/body/p[1]/b[2] ;
/data/size        attribute /html/body/p[1]/font size ;
/data/color       attribute /html/body/p[1]/font color ;
/data/color       attribute /html/body/p[2]/span[2]/font color ;
/data/cfalse      condition /html/body/p[2]/span[1] ;
/data/ctrue       condition /html/body/p[2]/span[2] ;
false()           condition /html/body/p[2]/span[3] ;
/data/repeat/row  repeat    /html/body/table/tr {
  ./value           content   ./td[1] ;
  ./text            content   ./td[2] 
} ;
/data/repeat/row  repeat      /html/body/select/option {
  ./value           attribute   .  value ;
  ./selected        attribute   .  selected ;
  ./text            content     . 
} ;

|;

my $data = q|<?xml version="1.0" encoding="utf-8" ?>
<data>
  <title test="This is the Cindy Test Page" />
  <content>Hello Test</content>
	<replace>This is NOT bold.</replace>
	<omit>1</omit>
	<!-- attributes are done with content -->
	<size>+2</size>
	<color>red</color>
  <repeat>
    <row>
      <value>1</value>
      <text>one</text>
    </row>
    <row>
      <value>2</value>
      <text>two</text>
      <selected>1</selected>
    </row>
    <row>
      <value>3</value>
      <text>three</text>
    </row>
  </repeat>
	<cfalse>0</cfalse>
	<ctrue>1</ctrue>
</data>
|;

my $doc = q|<html xmlns="http://www.w3.org/1999/xhtml">
<head>
  <title>This is an Error</title>
</head>

<body>

<a href="http://www.heute-morgen.de/test/About_Cindy.html">About</a>

<h2 test="I will survive">This is an Error for content</h2>
<p><b>This is an Error for replace</b>
<b><i>This is not bold,</i> too.</b>
This is <font>Big and Red</font></p>
<p><span>Das wird <b>entfernt</b>.</span>
<span>Das <font>bleibt</font>.</span>
<span>Das <font>verschwindet.</font>.</span>
</p>

<table>
	<tr>
    <td>0</td>
		<td>Text</td>
  </tr>
</table>

<select>
	<option value="test">Text</option>
</select>

</body>
</html>
|;

my $expected =  q|<html xmlns="http://www.w3.org/1999/xhtml">
<head><title>This is the Cindy Test Page</title></head>
<body>

<a href="http://www.heute-morgen.de/test/About_Cindy.html">About</a>

<h2 test="I will survive">Hello Test</h2>
<p>This is NOT bold.
<i>This is not bold,</i> too.
This is <font size="+2" color="red">Big and Red</font></p>
<p>
<span>Das <font color="red">bleibt</font>.</span>

</p>

<table>
<tr>
<td>1</td>
		<td>one</td>
  </tr>
<tr>
<td>2</td>
		<td>two</td>
  </tr>
<tr>
<td>3</td>
		<td>three</td>
  </tr>
</table>
<select><option value="1">one</option>
<option value="2" selected>two</option>
<option value="3">three</option></select>
</body>
</html>
|;

#use Cindy;

my $xdoc  = parse_html_string($doc);
my $xdata = parse_xml_string ($data);
my $xcis  = parse_cis_string ($cis);

my $check = inject($xdata, $xdoc, $xcis);

is ($check->toStringHTML(), $expected, 'Full');

