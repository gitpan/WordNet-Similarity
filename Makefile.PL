# Makefile.PL  (for WordNet::Similarity ver 0.04)
# (Last Updated 03/25/2003 -- Sid)
#
# Generates the Makefile for the WordNet::Similarity CPAN modules. Requires
# WordNet::QueryData (1.26 or above) be installed and be accessible via the
# @INC list of paths. The WordNet data files also need to be accessed. The
# WordNet home directory is determined from the WNHOME environment variable
# (e.g. /usr/local/wordnet17). If the WNHOME environment variable does not
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
    print "The installation of WordNet::Similarity requires that WordNet and \n";
    print "the WordNet::QueryData module (ver 1.26 or above) be installed on\n";
    print "this machine and that the module be accessible via the \@INC\n";
    print "perl library paths. Make sure these are installed before installing\n";
    print "WordNet::Similarity.\n";
  }
  elsif($loaded < 2)
  {
    print "The WordNet::Similarity module installer determines the location of\n";
    print "WordNet from the WNHOME environment variable. If the WNHOME\n";
    print "environment variable has not been set up, either set it up, or specify\n";
    print "the location of your WordNet installation using the --WNHOME option.\n";
    print "Example usage:\n\n";
    print "perl Makefile.PL --WNHOME /usr/local/wordnet17\n\n";
  }
}

print "Creating Makefile and datafiles for WordNet::Similarity. Generation of\n";
print "datafiles may take a few minutes.\n";

# Include the QueryData package.
require WordNet::QueryData;
$loaded = 1;

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
my %offsetMnem;
my %mnemFreq;
my %offsetFreq;
my %newFreq;
my %posMap;
my %topHash;

GetOptions("WNHOME=s");

# Check if path to WordNet has been provided... If so... save it.
if(defined $opt_WNHOME)
{
    $wnPCPath = $opt_WNHOME."\\dict";
    $wnUnixPath = $opt_WNHOME."/dict";
}
else
{
    $wnPCPath = (defined $ENV{"WNHOME"}) ? $ENV{"WNHOME"} : "C:\\Program Files\\WordNet\\1.7.1";
    $wnUnixPath = (defined $ENV{"WNHOME"}) ? $ENV{"WNHOME"} : "/usr/local/WordNet-1.7.1";
    $wnPCPath = (defined $ENV{"WNSEARCHDIR"}) ? $ENV{"WNSEARCHDIR"} : $wnPCPath."\\dict";
    $wnUnixPath = (defined $ENV{"WNSEARCHDIR"}) ? $ENV{"WNSEARCHDIR"} : $wnUnixPath."/dict";    
}

# Output File...
$fname = "lib/WordNet/infocontent.dat";

# Initialize POS Map.
$posMap{"1"} = "n";
$posMap{"2"} = "v";


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


print STDERR "Mapping noun offsets to frequencies ... ";
open(DATA, $wnUnixPath."/data.noun") || open(DATA, $wnPCPath."\\noun.dat") || die "Unable to open data file.\n";
foreach(1 .. 29)
{
    $line=<DATA>;
}
while($line=<DATA>)
{
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


print STDERR "Mapping verb offsets to frequencies ... ";
open(DATA, $wnUnixPath."/data.verb") || open(DATA, $wnPCPath."\\verb.dat") || die "Unable to open data file.\n";
foreach(1 .. 29)
{
    $line=<DATA>;
}
while($line=<DATA>)
{
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


print STDERR "Cleaning junk from memory ... ";
undef %offsetMnem;
undef %mnemFreq;
print STDERR "done.\n";


print STDERR "Loading WordNet ... ";
$wn = WordNet::QueryData->new($wnUnixPath);
$wn = WordNet::QueryData->new($wnPCPath) if(!$wn);    
if(!$wn)
{
    print STDERR "\nUnable to create WordNet object.\n";
    exit;
}
print STDERR "done.\n";


print STDERR "Determining topmost nodes of all hierarchies ... ";
&createTopHash();
print STDERR "done.\n";

print STDERR "Webcrawling through WordNet ... ";
$offsetFreq{"n"}{0} = 0;
$offsetFreq{"v"}{0} = 0;
&updateFrequency(0, "n");
&updateFrequency(0, "v");
delete $newFreq{"n"}{0};
delete $newFreq{"v"}{0};
print STDERR "done.\n";


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


WriteMakefile(
    'NAME'		=> 'WordNet::Similarity',
    'VERSION_FROM'	=> 'lib/WordNet/Similarity.pm', # finds $VERSION
    'PREREQ_PM'		=> {'WordNet::QueryData' => '1.26'}, # e.g., Module::Name => 1.1
    'dist'              => {'COMPRESS' => 'gzip', 'SUFFIX' => 'gz'},
    'clean'             => {'FILES' => 'lib/WordNet/infocontent.dat'},
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      ('ABSTRACT_FROM'  => 'lib/WordNet/Similarity.pm', # retrieve abstract from module
       'AUTHOR'         => 'Siddharth Patwardhan <patw0006@d.umn.edu>, Ted Pedersen <tpederse@d.umn.edu>') : ()),
);


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


