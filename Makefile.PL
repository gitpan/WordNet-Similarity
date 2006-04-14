# This -*- perl -*- script writes the Makefile for WordNet::Similarity
# (Last updated $Id: Makefile.PL,v 1.34 2006/02/19 19:11:09 sidz1979 Exp $)
#
# Generates the Makefile for the WordNet::Similarity CPAN modules. Requires
# WordNet::QueryData (1.39 or above) be installed and be accessible via the
# @INC list of paths. The WordNet data files also need to be accessed. The
# WordNet home directory is determined from the WNHOME environment variable
# (e.g. /usr/local/WordNet-2.1). If the WNHOME environment variable does not
# exist, the WordNet home directory can be specified to Makefile.PL via the
# WNHOME option. Example usage:
#
# perl Makefile.PL WNHOME=/usr/local/wordnet21
#
# ----------------------------------------------------------------------------

use 5.005;
use ExtUtils::MakeMaker;

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

END
{
    if(!$loaded)
    {
        print STDERR <<'EONL'
The installation of WordNet::Similarity requires that WordNet and
the WordNet::QueryData module (ver 1.39 or above) be installed on
this machine and that the module be accessible via the @INC perl
library paths.  Make sure these are installed before installing
WordNet::Similarity.
EONL
    }
    elsif($loaded < 2)
    {
        print STDERR <<'EOT';
The WordNet::Similarity module installer determines the location of
WordNet from the WNHOME environment variable.  If the WNHOME
environment variable has not been set, either set it, or specify the
location of your WordNet installation using the WNHOME option.

  Example usage:
  perl Makefile.PL WNHOME=/usr/local/WordNet-2.1

EOT
    }
}

# Global Variable declaration.
my $wn;
my $wnPCPath;
my $wnUnixPath;
my $totalCount;
my $offset;
my $icflag = 0;
my @line;
my @programs_to_install;
my %offsetMnem;
my %mnemFreq;
my %offsetFreq;
my %newFreq;
my %posMap;
my %topHash;

# Authors' names and email addresses
my $author1 = "Ted Pedersen <tpederse at d.umn.edu>";
my $author2 = "Siddharth Patwardhan <sidd at cs.utah.edu>";
my $author3 = "Satanjeev Banerjee <banerjee+ at cs.cmu.edu>";
my $author4 = "Jason Michelizzi <mich0212 at d.umn.edu>";

# tdp 12/16/03 renamed semCor1.7Freq.pl as semCorRaw.pl, and
# semTagFreq.pl as semCorFreq.pl

# run $short_tests when doing 'make test', but run $long_tests when
# doing 'make test_all'
my $short_tests = 't/access.t t/res.t t/lin.t t/jcn.t t/path.t t/lch.t';
$short_tests .= ' t/wup.t t/lesk.t t/vector_pairs.t t/vector.t t/hso.t t/random.t t/config/rootnode.t';
my $long_tests = 't/*.t t/config/*.t t/utils/*.t';
my $basic_tests = 't/random.t t/hso.t t/path.t t/lesk.t t/pod.t t/pod-coverage.t';
my $stage2_tests = 't/lch.t t/wup.t t/config/rootnode.t t/res.t t/jcn.t t/lin.t';
my $stage3_tests = 't/vector_pairs.t t/vector.t';
my $stage_all = 't/access.t';

@programs_to_install = qw(BNCFreq.pl brownFreq.pl compounds.pl
                          rawtextFreq.pl semCorRawFreq.pl semCorFreq.pl
                          similarity.pl  treebankFreq.pl wordVectors.pl
                          wnDepths.pl);

# Get the WNHOME option from the command line
my @tmpArgs = @ARGV;
@ARGV = ();
foreach my $arg (@tmpArgs)
{
    if($arg =~ /^WNHOME=(.*)/)
    {
        $opt_WNHOME=$1;
    }
    else
    {
        push(@ARGV, $arg);
    }
}

# Write out the make file
WriteMakefile(
              'NAME'         => 'WordNet::Similarity',
              'PREREQ_PM'    => {'WordNet::QueryData' => '1.39',
                                 'Text::Similarity'   => '0.02'},
              'CONFIGURE'    => \&configSub,
              'VERSION_FROM' => 'lib/WordNet/Similarity.pm', # finds $VERSION
              'EXE_FILES'    => [ map "utils/$_", @programs_to_install ],
              'dist'         => {'COMPRESS' => 'gzip -9f', 'SUFFIX' => 'gz'},
              'clean'        => {'FILES' => 'lib/WordNet/ic-semcor.dat lib/WordNet/wordvectors.dat lib/WordNet/*depths-*.dat'},
              ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
               ('ABSTRACT_FROM'   => 'lib/WordNet/Similarity.pm', # retrieve abstract from module
                'AUTHOR'          => '$author1, $author2, $author3, $author4') : ())
              );

my $wnver = $wn->version();

if($icflag)
{
    print STDERR <<"EOIN";

*** IMPORTANT NOTE: The information content files generated during this
process have been generated for WordNet version ${wnver}. If, at a later
date, the version of WordNet being used on this system changes and the
current version is no longer accessible to the measures (via \$WNHOME
or via command-line options), THEN the measures will no longer be able
to use the default information content files that have just been generated.
Alternate information content files will need to be explicitly specified
using configuration files for the respective measures.  An alternative
is to re-run this installation from scratch at that time.  For more
information regarding configuration files, see the man-pages/pods.
EOIN
}

print STDERR <<"EOLST";

To continue the installation process run:

    make
    make test
    make install

You may also run a series of more rigorous tests by running 'make test_all'
instead of 'make test'. NOTE: Most of the rigorous test will fail if the
default data files were not installed.

EOLST


# Config subroutine that generates the ic-semcor.dat data file
# also generates a WordNet depths file by running utils/wnDepths.pl
sub configSub
{
    my $tryTests = $basic_tests;
    my $dataCount = 0;

    print STDERR << "EOFST";
Creating Makefile and datafiles for WordNet::Similarity.
Generation of datafiles may take a few minutes.
    
Some of the similarity modules require access to certain
data files (information content files and word vector files)
in order to execute completely and correctly. "Default"
data files can be generated now, and be stored along with
the modules. In the absence of user-specified data files,
these "default" files would be used by the modules.

EOFST

    my $qAns = "y";
    print STDERR "Would you like to generate and install default data files?\n";
    print STDERR "((y)es, (n)o, (q)uery-before-each) [y] ";
    my $line = <STDIN>;
    $line =~ s/[\r\f\n]//;
    $line =~ s/^\s+//;
    $line =~ s/\s+$//;
    $qAns = $line if(defined $line && $line ne "");
    while($qAns !~ /^[yYnNqQ]$/)
    {
        $qAns = "y";
        print STDERR "((y)es, (n)o, (q)uery-before-each) [y] ";
        $line = <STDIN>;
        $line =~ s/[\r\f\n]//;
        $line =~ s/^\s+//;
        $line =~ s/\s+$//;
        $qAns = $line if(defined $line && $line ne "");
    }
    print STDERR "\n";
    print STDERR "Installing all the default data files.\n" if($qAns =~ /^[yY]$/);
    print STDERR "Continuing without installing the default data files.\n" if($qAns =~ /^[nN]$/);
    print STDERR "You will be asked before each data file is installed.\n" if($qAns =~ /^[qQ]$/);
   
    # Include the QueryData package.
    require WordNet::QueryData;
    $loaded = 1;
    my $wndictpath;

    # Check if path to WordNet has been provided... If so... save it.
    if(defined $opt_WNHOME)
    {
	$wnPCPath = $opt_WNHOME."\\dict";
	$wnUnixPath = $opt_WNHOME."/dict";
    }
    else
    {
	$wnPCPath = (defined $ENV{"WNHOME"}) ? $ENV{"WNHOME"} : "C:\\Program Files\\WordNet\\2.1";
	$wnUnixPath = (defined $ENV{"WNHOME"}) ? $ENV{"WNHOME"} : "/usr/local/WordNet-2.1";
	$wnPCPath = (defined $ENV{"WNSEARCHDIR"}) ? $ENV{"WNSEARCHDIR"} : $wnPCPath."\\dict";
	$wnUnixPath = (defined $ENV{"WNSEARCHDIR"}) ? $ENV{"WNSEARCHDIR"} : $wnUnixPath."/dict";
    }

    # Load WordNet::QueryData, get version and path to datafiles...
    print STDERR "Checking WordNet::QueryData ... ";
    $wndictpath = $wnUnixPath;
    $wn = WordNet::QueryData->new($wnUnixPath);
    $wndictpath = $wnPCPath if(!$wn);
    $wn = WordNet::QueryData->new($wnPCPath) if(!$wn);
    if(!$wn)
    {
	print STDERR "\nUnable to create WordNet::QueryData object.\n";
	exit;
    }
    $loaded = 2;
    $wndictpath = $wnUnixPath = $wnPCPath = $wn->dataPath() if($wn->can('dataPath'));
    print STDERR "done.\n\n";

    # Query if depth files should be installed...
    my $infAns = "n";
    if($qAns =~ /^[qQ]$/)
    {
        $infAns = "";
        while($infAns !~ /^[yYnN]$/)
        {
            $infAns = "y";
            print STDERR "Would you like to install the default WordNet depth files ((y)es, (n)o)?\n";
            print STDERR "(These files are accessed by most of the modules) [y] ";
            my $line = <STDIN>;
            $line =~ s/[\r\f\n]//;
            $line =~ s/^\s+//;
            $line =~ s/\s+$//;
            $infAns = $line if(defined $line && $line ne "");
        }
    }
    elsif($qAns =~ /^[yY]$/)
    {
        $infAns = "y";
    }

    # JM 1-7-04
    # added the follow to generate a WordNet depths file for DepthFinder.pm
    #
    # Generate depths files:
    #
    my $wnversion = $wn->version();
    my $synsetsfile = "lib/WordNet/synsetdepths-$wnversion.dat";
    my $taxonomyfile = "lib/WordNet/treedepths-$wnversion.dat";
    if($infAns =~ /^[yY]$/)
    {
        print STDERR "Creating WordNet depth files.\n";
        print STDERR "This will take a few minutes.\n";
        system ($^X, "utils/wnDepths.pl", 
                "--outfile=$taxonomyfile",
                "--depthfile=$synsetsfile",
                "--wnpath=$wndictpath");
        if (-z $synsetsfile or -z $taxonomyfile) {
            print STDERR "Error: failed to create WordNet depths file\n";
        }
        else
        {
            $dataCount++;
        }
        # done with depths files
    }
    print STDERR "\n" if($qAns !~ /^[nN]$/);

    # Query if infocontent file should be created...
    $infAns = "n";
    if($qAns =~ /^[qQ]$/)
    {
        $infAns = "";
        while($infAns !~ /^[yYnN]$/)
        {
            $infAns = "y";
            print STDERR "Would you like to install a default information content file ((y)es, (n)o)?\n";
            print STDERR "(This file is accessed by the res, lin and jcn modules) [y] ";
            my $line = <STDIN>;
            $line =~ s/[\r\f\n]//;
            $line =~ s/^\s+//;
            $line =~ s/\s+$//;
            $infAns = $line if(defined $line && $line ne "");
        }
    }
    elsif($qAns =~ /^[yY]$/)
    {
        $infAns = "y";
    }

    # Depending on whether infocontent file must be installed.
    my $fname = "lib/WordNet/ic-semcor.dat";
    if($infAns =~ /^[yY]$/)
    {
        # Installing the default infocontent file...
        print STDERR "Creating information content file.\n";
        print STDERR "This will take a few minutes.\n";

        # Generate infocontent file:
        #
        system ($^X, "utils/semCorFreq.pl", 
                "--outfile=$fname",
                "--wnpath=$wndictpath");
        if (-z $fname) 
        {
            print STDERR "Error: Failed to create default infocontent file.\n";
        }
        else
        {
            my $icVersion = &getICVersion($fname);
            $icflag = 1;
            print STDERR "Wrote file $fname (WordNet ver ".$icVersion.").\n";
            $dataCount++;
            $tryTests .= " $stage2_tests" if($dataCount == 2);
        }
        # done with infocontent file
    }
    print STDERR "\n" if($qAns !~ /^[nN]$/);

    # Query if word vectors file must be created...
    $infAns = "n";
    if($qAns =~ /^[qQ]$/)
    {
        $infAns = "";
        while($infAns !~ /^[yYnN]$/)
        {
            $infAns = "y";
            print STDERR "Would you like to install a default word vectors file ((y)es, (n)o)?\n";
            print STDERR "(This file is accessed by the vector module) [y] ";
            my $line = <STDIN>;
            $line =~ s/[\r\f\n]//;
            $line =~ s/^\s+//;
            $line =~ s/\s+$//;
            $infAns = $line if(defined $line && $line ne "");
        }
    }
    elsif($qAns =~ /^[yY]$/)
    {
        $infAns = "y";
    }

    # Depending on whether word vectors file must be installed.
    my $wvfile = "lib/WordNet/wordvectors.dat";
    if($infAns =~ /^[yY]$/)
    {
        # Installing the default word vectors file...
        print STDERR "Generating word vectors file.\n";
        print STDERR "This will take a few minutes.\n";

        # Generate wordvectors file:
        #
        system ($^X, "-Ilib", "utils/wordVectors.pl", 
                "--compfile=samples/wn21compounds.txt",
                "--stopfile=samples/stoplist.txt",
                "--chigh=1000", "--clow=5", 
                "--wnpath=$wndictpath", $wvfile);
        if (-z $wvfile) 
        {
            print STDERR "Error: Failed to create default word vectors file.\n";
        }
        else
        {
            print STDERR "Wrote vectors file ($wvfile).\n";
            $dataCount++;
            $tryTests .= " $stage3_tests";
            $tryTests .= " $stage_all" if($dataCount == 3);
        }
        # done with wordvectors file
    }
    print STDERR "\n" if($qAns !~ /^[nN]$/);

    my %retRef = ();
    $retRef{'test'}{'TESTS'} = $tryTests;
    return \%retRef;
}

# Returns the WordNet version used in generating an infocontent file.
sub getICVersion
{
    my $fname = shift;
    return "" if(!defined $fname);
    return "" if(!open(ICFILE, $fname));
    my $line = <ICFILE>;
    close(ICFILE);
    $line =~ s/[\r\f\n]//;
    $line =~ s/^\s+//;
    $line =~ s/\s+$//;
    my $wnver = "";
    $wnver = $1 if($line =~ /wnver\s*::\s*(.*)/);
    return $wnver;
}

# What follows is some magic that makes some low-level modifications to
# the text that is about to be written to the Makefile.  We have to put
# this in the MY package so that the call to SUPER works correctly. The
# documentation for ExtUtils::MakeMaker has information on what we're
# actually doing here under the section 'Overriding MakeMaker Methods'.
#
# Essentially, we override MakeMaker's test() method and insert some
# extra text to add a new target, test_all.

package MY;

# override test() method to add a new target, test_all
sub test
{
    my $self = shift;
    my $text = $self->SUPER::test (@_);

    # here we make a copy of the Makefile portion made by SUPER::test(),
    # and then use the copy to make our own rule: test_all
    my $newtext = $text;
    $newtext =~ s/test(?!_harness)/test_all/g;
    $newtext =~ s/TEST/TEST_ALL/g;

    # don't forget the /m modifier:
    $newtext =~ s/(?<=TEST_ALL_FILES = ).*$/${long_tests}/m;

    $text .= $newtext;

    return $text;
}

# override the special_targets method to add test_all to the list of
# phony targets
sub special_targets
{
    my $self = shift;

    my $str = $self->SUPER::special_targets (@_);

    # add test_all to the list of phony targets
    $str =~ s/(\.PHONY:.* test\b)/$1 test_all/;

    return $str;
}

