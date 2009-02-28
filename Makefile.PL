use 5.010000;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Cindy',
    VERSION_FROM      => 'lib/Cindy.pm', # finds $VERSION
    PREREQ_PM   => {
	    'XML::LibXML'	=> '0', 
    }, 
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Cindy.pm', # retrieve abstract from module
       AUTHOR         => 'JZOBEL (jz-2009@heute-morgen.de)') : ()),
);
