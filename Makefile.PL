# This -*- perl -*- script writes the Makefile for WordNet::Similarity
# (Last Updated 1/07/2004 -- Jason)
#
# Generates the Makefile for the WordNet::Similarity CPAN modules. Requires
# WordNet::QueryData (1.30 or above) be installed and be accessible via the
# @INC list of paths. The WordNet data files also need to be accessed. The
# WordNet home directory is determined from the WNHOME environment variable
# (e.g. /usr/local/WordNet-2.0). If the WNHOME environment variable does not
# exist, the WordNet home directory can be specified to Makefile.PL via the
# --WNHOME option. Example usage:
#
# perl Makefile.PL --WNHOME /usr/local/wordnet17
#

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
the WordNet::QueryData module (ver 1.30 or above) be installed on
this machine and that the module be accessible via the @INC perl
library paths.  Make sure tese are installed before installing
WordNet::Similarity.
EONL
    }
    elsif($loaded < 2)
    {
	print STDERR <<'EOT';
The WordNet::Similarity module installer determines the location of
WordNet from the WNHOME environment variable.  If the WNHOME
environment variable has not been set, either set it, or specify the
location of your WordNet installation using the --WNHOME option.

  Example usage:
  perl Makefile.PL --WNHOME /usr/local/WordNet-1.7.1

EOT
    }
}

# Get Options.
use Getopt::Long;

# Global Variable declaration.
my $wn;
my $wnPCPath;
my $wnUnixPath;
my $totalCount;
my $offset;
my $fname;
my @line;
my @programs_to_install;
my %offsetMnem;
my %mnemFreq;
my %offsetFreq;
my %newFreq;
my %posMap;
my %topHash;

GetOptions("WNHOME=s");

# tdp 12/16/03 renamed semCor1.7Freq.pl as semCorRaw.pl, and
# semTagFreq.pl as semCorFreq.pl

# run $short_tests when doing 'make test', but run $long_tests when
# doing 'make test_all'
my $short_tests = 't/access.t t/res.t t/lin.t t/jcn.t t/path.t t/lch.t';
$short_tests .= ' t/wup.t t/lesk.t t/hso.t t/random.t t/config/rootnode.t';
my $long_tests = 't/*.t t/config/*.t t/utils/*.t';

@programs_to_install = qw(readDB.pl BNCFreq.pl brownFreq.pl compounds.pl
			  rawtextFreq.pl semCorRawFreq.pl semCorFreq.pl
			  similarity.pl  treebankFreq.pl wordVectors.pl
			  wnDepths.pl);

WriteMakefile(
    'NAME'		  => 'WordNet::Similarity',
    'PREREQ_PM'		=> {'WordNet::QueryData' => '1.30'},
    'CONFIGURE'         => \&configSub,
    'VERSION_FROM'	  => 'lib/WordNet/Similarity.pm', # finds $VERSION
    'EXE_FILES'         => [ map "utils/$_", @programs_to_install ],
    'dist'              => {'COMPRESS' => 'gzip -9f', 'SUFFIX' => 'gz'},
    'clean'             => {'FILES' => 'lib/WordNet/ic-semcor.dat lib/WordNet/*depths-*.dat'},
#    'test'              => {TESTS => 't/*.t t/config/*.t t/utils/*.t'},
    'test'            => {TESTS => $short_tests},
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
    ('ABSTRACT_FROM'   => 'lib/WordNet/Similarity.pm', # retrieve abstract from module
     'AUTHOR'          => 'Siddharth Patwardhan <sidd at cs.utah.edu>, Ted Pedersen <tpederse at d.umn.edu>, Jason Michelizzi <mich0212 at d.umn.edu>') : ()),
);

my $wnver = $wn->version();
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

To continue the installation process run:

    make
    make test
    make install

You may also run a series of more rigorous tests by running 'make test_all'
instead of 'make test'.

EOIN


# Config subroutine that generates the ic-semcor.dat data file
# also generates a WordNet depths file by running utils/wnDepths.pl
sub configSub
{
    my $missing_modules = 0;

    print STDERR "Creating Makefile and datafiles for WordNet::Similarity. Generation of\n";
    print STDERR "datafiles may take a few minutes.\n";

    # Include the QueryData package.
    require WordNet::QueryData;
    $loaded = 1;

    # Check if path to WordNet has been provided... If so... save it.
    if(defined $opt_WNHOME)
    {
	$wnPCPath = $opt_WNHOME."\\dict";
	$wnUnixPath = $opt_WNHOME."/dict";
    }
    else
    {
	$wnPCPath = (defined $ENV{"WNHOME"}) ? $ENV{"WNHOME"} : "C:\\Program Files\\WordNet\\2.0";
	$wnUnixPath = (defined $ENV{"WNHOME"}) ? $ENV{"WNHOME"} : "/usr/local/WordNet-2.0";
	$wnPCPath = (defined $ENV{"WNSEARCHDIR"}) ? $ENV{"WNSEARCHDIR"} : $wnPCPath."\\dict";
	$wnUnixPath = (defined $ENV{"WNSEARCHDIR"}) ? $ENV{"WNSEARCHDIR"} : $wnUnixPath."/dict";
    }

    # Output File...
    $fname = "lib/WordNet/ic-semcor.dat";

    # Initialize POS Map.
    $posMap{"1"} = "n";
    $posMap{"2"} = "v";

    print STDERR "Loading WordNet ... ";
    $wn = WordNet::QueryData->new($wnUnixPath);
    $wn = WordNet::QueryData->new($wnPCPath) if(!$wn);
    if(!$wn)
    {
	print STDERR "\nUnable to create WordNet object.\n";
	exit;
    }
    $wnUnixPath = $wnPCPath = $wn->dataPath() if($wn->can('dataPath'));
    print STDERR "done.\n";

    # JM 1-7-04
    # added the follow to generate a WordNet depths file for DepthFinder.pm
    #
    # Generate depths files:
    #
    print STDERR "Creating WordNet depths file.\n";
    my $wnversion = $wn->version();
    my $synsetsfile = "lib/WordNet/synsetdepths-$wnversion.dat";
    my $taxonomyfile = "lib/WordNet/treedepths-$wnversion.dat";
    system ($^X, "utils/wnDepths.pl", "--outfile=$taxonomyfile",
	    "--depthfile=$synsetsfile");
    if (-z $synsetsfile or -z $taxonomyfile) {
      print STDERR "Error: failed to create WordNet depths file\n";
    }
    # done with depths files

    # Loading the Sense Indices.
    print STDERR "Loading sense indices ... ";
    open(IDX, $wnUnixPath."/index.sense") || open(IDX, $wnPCPath."\\sense.idx") || die "Unable to open sense index file.\n";
    $loaded = 2;
    while(<IDX>)
    {
	s/[\r\f\n]//;
	@line = split / +/;
	if($line[0] =~ /%([12]):/)
	{
	    $posHere = $1;
	    $line[1] =~ s/^0*//;
	    push @{$offsetMnem{$line[1].$posMap{$posHere}}}, $line[0];
	}
    }
    close(IDX);
    print STDERR "done.\n";


    # Loading the frequency counts from 'cntlist'.
    print STDERR "Loading cntlist ... ";
    open(CNT, $wnUnixPath."/cntlist") || open(CNT, $wnPCPath."\\cntlist") || die "Unable to open cntlist.\n";
    while(<CNT>)
    {
	s/[\r\f\n]//;
	@line = split / +/;
	if($line[1] =~ /%[12]:/)
	{
	    $mnemFreq{$line[1]}=$line[0];
	}
    }
    close(CNT);
    print STDERR "done.\n";


    # Mapping offsets to frequencies.
    print STDERR "Mapping noun offsets to frequencies ... ";
    open(DATA, $wnUnixPath."/data.noun") || open(DATA, $wnPCPath."\\noun.dat") || die "Unable to open data file.\n";
    while($line=<DATA>)
    {
	next if($line =~ /^\s/);
	$line =~ /^([0-9]+)\s+/;
	$offset = $1;
	$offset =~ s/^0*//;
	if(exists $offsetMnem{$offset."n"})
	{
	    foreach $mnem (@{$offsetMnem{$offset."n"}})
	    {
		if($offsetFreq{"n"}{$offset})
		{
		    $offsetFreq{"n"}{$offset} += ($mnemFreq{$mnem}) ? $mnemFreq{$mnem} : 0;
		}
		else
		{
		    # [old]
		    # Using initial value of 1 for add-1 smoothing. (added 06/22/2002)
		    # $offsetFreq{$offset} = ($mnemFreq{$mnem}) ? $mnemFreq{$mnem} : 0;
		    # [/old]
		    # No more add-1 (09/13/2002)
		    $offsetFreq{"n"}{$offset} = ($mnemFreq{$mnem}) ? $mnemFreq{$mnem} : 0;
		}
	    }
	}
	else
	{
	    # Code added for Add-1 smoothing (06/22/2002)
	    # Code changed... no more add-1 (09/13/2002)
	    $offsetFreq{"n"}{$offset} = 0;
	}
    }
    close(DATA);
    print STDERR "done.\n";


    # Mapping offsets to frequencies.
    print STDERR "Mapping verb offsets to frequencies ... ";
    open(DATA, $wnUnixPath."/data.verb") || open(DATA, $wnPCPath."\\verb.dat") || die "Unable to open data file.\n";
    while($line=<DATA>)
    {
	next if($line =~ /^\s/);
	$line =~ /^([0-9]+)\s+/;
	$offset = $1;
	$offset =~ s/^0*//;
	if(exists $offsetMnem{$offset."v"})
	{
	    foreach $mnem (@{$offsetMnem{$offset."v"}})
	    {
		if($offsetFreq{"v"}{$offset})
		{
		    $offsetFreq{"v"}{$offset} += ($mnemFreq{$mnem}) ? $mnemFreq{$mnem} : 0;
		}
		else
		{
		    # [old]
		    # Using initial value of 1 for add-1 smoothing. (added 06/22/2002)
		    # $offsetFreq{$offset} = ($mnemFreq{$mnem}) ? $mnemFreq{$mnem} : 0;
		    # [/old]
		    # No more add-1 (09/13/2002)
		    $offsetFreq{"v"}{$offset} = ($mnemFreq{$mnem}) ? $mnemFreq{$mnem} : 0;
		}
	    }
	}
	else
	{
	    # Code added for Add-1 smoothing (06/22/2002)
	    # Code changed... no more add-1 (09/13/2002)
	    $offsetFreq{"v"}{$offset} = 0;
	}
    }
    close(DATA);
    print STDERR "done.\n";


    # Making some space in memory.
    print STDERR "Cleaning junk from memory ... ";
    undef %offsetMnem;
    undef %mnemFreq;
    print STDERR "done.\n";


    # What are the topmost nodes?
    print STDERR "Determining topmost nodes of all hierarchies ... ";
    &createTopHash();
    print STDERR "done.\n";


    # Propagating frequency counts up the trees.
    print STDERR "Webcrawling through WordNet ... ";
    $offsetFreq{"n"}{0} = 0;
    $offsetFreq{"v"}{0} = 0;
    &updateFrequency(0, "n");
    &updateFrequency(0, "v");
    delete $newFreq{"n"}{0};
    delete $newFreq{"v"}{0};
    print STDERR "done.\n";


    # Writing the default infocontent file.
    print STDERR "Writing infocontent file ... ";
    open(DATA, ">$fname") || die "Unable to open data file for writing.\n";
    print DATA "wnver::".$wn->version()."\n";
    foreach $offset (sort {$a <=> $b} keys %{$newFreq{"n"}})
    {
	print DATA $offset."n ".$newFreq{"n"}{$offset};
	print DATA " ROOT" if($topHash{"n"}{$offset});
	print DATA "\n";
    }
    foreach $offset (sort {$a <=> $b} keys %{$newFreq{"v"}})
    {
	print DATA $offset."v ".$newFreq{"v"}{$offset};
	print DATA " ROOT" if($topHash{"v"}{$offset});
	print DATA "\n";
    }
    close(DATA);
    print STDERR "done.\n";
    print STDERR "Wrote file $fname (WordNet ver ".$wn->version().").\n";


    # Check if PDL is installed.
#    print STDERR "Dependency check for PDL ... ";
#    eval
#    {
#	require PDL;
#    };
#
#    if($@)
#    {
#	print STDERR "failed.\n";
#	$missing_modules++;
#    }
#    else
#    {
#	print STDERR "ok.\n";
#    }


    # Check if the BerkeleyDB Perl module is installed.
    print STDERR "Dependency check for BerkeleyDB (Perl module) ... ";
    eval
    {
	require BerkeleyDB;
    };

    if($@)
    {
	print STDERR "failed.\n";
	$missing_modules++;
    }
    else
    {
	print STDERR "ok.\n";
    }


    # If failed dedpendencies, install only selected modules.
    if($missing_modules)
    {
	my $rHash = {};
	my $pmHash = {};
	print STDERR <<'EOFD';
*** Failed dependencies for module Wordnet::Similarity::vector.pm
    Not installing WordNet::Similarity::vector.pm

    Module vector.pm requires that BerkeleyDB and the Perl
    interface to BerkeleyDB be installed on your system.
    BerkeleyDB can be obtained from http://www.sleepycat.com
    and the Perl interface to BerkeleyDB can be obtained from
    http://search.cpan.org/dist/BerkeleyDB

    For now this installation will continue without installing
    the WordNet::Similarity::vector module.  The installation
    can be re-run once BerkeleyDB and BerkeleyDB.pm are installed.

EOFD

	$pmHash->{'lib/string_compare.pm'} = "\$(INST_LIB)/string_compare.pm";
	$pmHash->{'lib/stem.pm'}           = "\$(INST_LIB)/stem.pm";
	$pmHash->{'lib/get_wn_info.pm'}    = "\$(INST_LIB)/get_wn_info.pm";
	$pmHash->{'lib/WordNet/Similarity.pm'}   = "\$(INST_LIB)/WordNet/Similarity.pm";
	$pmHash->{"lib/WordNet/treedepths-$wnversion.dat"} = "\$(INST_LIB)/WordNet/treedepths-$wnversion.dat";
	$pmHash->{"lib/WordNet/synsetdepths-$wnversion.dat"} = "\$(INST_LIB)/WordNet/synsetdepths-$wnversion.dat";
# mich0212 12/1/03
# relation.dat renamed lesk-relation.dat
	$pmHash->{'lib/WordNet/lesk-relation.dat'}    = "\$(INST_LIB)/WordNet/lesk-relation.dat";
# mich0212 12/1/03
# infocontent.dat renamed ic-semcor.dat
# tdp 12/16/03
# infocontent.dat renamed ic-semcor.dat again, was ic-semtag.dat
	$pmHash->{'lib/WordNet/ic-semcor.dat'} = "\$(INST_LIB)/WordNet/ic-semcor.dat";
	$pmHash->{'lib/WordNet/Similarity/random.pm'} = "\$(INST_LIB)/WordNet/Similarity/random.pm";
	$pmHash->{'lib/WordNet/Similarity/path.pm'}   = "\$(INST_LIB)/WordNet/Similarity/path.pm";
	$pmHash->{'lib/WordNet/Similarity/hso.pm'}    = "\$(INST_LIB)/WordNet/Similarity/hso.pm";
	$pmHash->{'lib/WordNet/Similarity/jcn.pm'}    = "\$(INST_LIB)/WordNet/Similarity/jcn.pm";
	$pmHash->{'lib/WordNet/Similarity/lch.pm'}    = "\$(INST_LIB)/WordNet/Similarity/lch.pm";
	$pmHash->{'lib/WordNet/Similarity/lesk.pm'}   = "\$(INST_LIB)/WordNet/Similarity/lesk.pm";
	$pmHash->{'lib/WordNet/Similarity/lin.pm'}    = "\$(INST_LIB)/WordNet/Similarity/lin.pm";
	$pmHash->{'lib/WordNet/Similarity/res.pm'}    = "\$(INST_LIB)/WordNet/Similarity/res.pm";
# Vector must not be installed...
#	$pmHash->{'lib/WordNet/Similarity/vector.pm'} = "\$(INST_LIB)/WordNet/Similarity/vector.pm";
	$pmHash->{'lib/WordNet/Similarity/wup.pm'}    = "\$(INST_LIB)/WordNet/Similarity/wup.pm";
	$pmHash->{'lib/WordNet/Similarity/DepthFinder.pm'} = "\$(INST_LIB)/WordNet/Similarity/DepthFinder.pm";
	$pmHash->{'lib/WordNet/Similarity/ICFinder.pm'} = "\$(INST_LIB)/WordNet/Similarity/ICFinder.pm";
	$pmHash->{'lib/WordNet/Similarity/LCSFinder.pm'} = "\$(INST_LIB)/WordNet/Similarity/LCSFinder.pm";
	$pmHash->{'lib/WordNet/Similarity/PathFinder.pm'} = "\$(INST_LIB)/WordNet/Similarity/PathFinder.pm";

	$rHash->{"PM"} = $pmHash;

	return $rHash;
    }

    return {};
}


# Recursive subroutine that calculates the cumulative frequencies
# of all synsets in WordNet.
# INPUT PARAMS  : $offset  .. Offset of the synset to update.
#                 $pos     .. Part-of-Speech ("n", "v").
# RETRUN VALUES : $freq    .. The cumulative frequency calculated for
#                             the node.
sub updateFrequency
{
    my $node;
    my $pos;
    my $sum;
    my $retValue;
    my $hyponym;
    my @hyponyms;

    $node = shift;
    $pos = shift;
    if($newFreq{$pos}{$node})
    {
	return $newFreq{$pos}{$node};
    }
    $retValue = &getHyponymOffsets($node, $pos);
    if($retValue)
    {
	@hyponyms = @{$retValue};
    }
    else
    {
	$newFreq{$pos}{$node} = $offsetFreq{$pos}{$node};
	return $offsetFreq{$pos}{$node};
    }
    $sum = 0;
    if($#{$retValue} >= 0)
    {
	foreach $hyponym (@hyponyms)
	{
	    $sum += &updateFrequency($hyponym, $pos);
	}
    }
    $newFreq{$pos}{$node} = $offsetFreq{$pos}{$node} + $sum;
    return $offsetFreq{$pos}{$node} + $sum;
}


# Creates and loads the topmost nodes hash.
sub createTopHash
{
    my $word;
    my $wps;
    my $upper;
    my $fileIsGood;
    my %wpsOffset;

    undef %wpsOffset;
    foreach $word ($wn->listAllWords("n"))
    {
	foreach $wps ($wn->querySense($word."\#n"))
	{
	    if(!$wpsOffset{$wn->offset($wps)})
	    {
		($upper) = $wn->querySense($wps, "hype");
		if(!$upper)
		{
		    $topHash{"n"}{$wn->offset($wps)} = 1;	
		}
		$wpsOffset{$wn->offset($wps)} = 1;
	    }
	}
    }
    undef %wpsOffset;
    foreach $word ($wn->listAllWords("v"))
    {
	foreach $wps ($wn->querySense($word."\#v"))
	{
	    if(!$wpsOffset{$wn->offset($wps)})
	    {
		($upper) = $wn->querySense($wps, "hype");
		if(!$upper)
		{
		    $topHash{"v"}{$wn->offset($wps)} = 1;
		}
		$wpsOffset{$wn->offset($wps)} = 1;
	    }
	}
    }
}


# Subroutine that returns the hyponyms of a given synset.
# INPUT PARAMS  : $offset  .. Offset of the given synset.
#                 $pos     .. Part-of-Speech ("n", "v").
# RETURN PARAMS : @offsets .. Offsets of the hyponyms of $offset.
sub getHyponymOffsets
{
    my $offset;
    my $wordForm;
    my $hyponym;
    my @hyponyms;
    my @retVal;

    $offset = shift;
    $pos = shift;
    if($offset == 0)
    {
	@retVal = keys %{$topHash{$pos}};
	return [@retVal];
    }
    $wordForm = $wn->getSense($offset, $pos);
    @hyponyms = $wn->querySense($wordForm, "hypo");
    if(!@hyponyms || $#hyponyms < 0)
    {
	return undef;
    }
    @retVal = ();
    foreach $hyponym (@hyponyms)
    {
	$offset = $wn->offset($hyponym);
	push @retVal, $offset;
    }
    return [@retVal];
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

# overrride test() method to add a new target, test_all
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
