#!/usr/local/bin/perl -w
#
# semTagFreq.pl version 0.01
# (Updated 02/10/2003 -- Sid)
#
# A helper tool perl program for the distance.pl program. 
# This program is used to generate the frequency count data 
# files which are used by the Jiang Conrath, Resnik and Lin 
# measures to calculate the information content of a synset in 
# WordNet. The output is generated in a format as required by
# the WordNet::Similarity modules (ver 0.01) for computing
# semantic relatedness.
#
#
# Copyright (c) 2003,
# Siddharth Patwardhan, University of Minnesota, Duluth
# patw0006@d.umn.edu
# Ted Pedersen, University of Minnesota, Duluth
# tpederse@d.umn.edu
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to 
#
# The Free Software Foundation, Inc., 
# 59 Temple Place - Suite 330, 
# Boston, MA  02111-1307, USA.
#
# -----------------------------------------------------------------

# Include the QueryData package.
use WordNet::QueryData;

# Include library to get Command-Line options.
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

# Get Command-Line options.
&GetOptions("help", "version", "wnpath=s", "outfile=s");

# Check if help has been requested ... If so ... display help.
if(defined $opt_help)
{
    $opt_help = 1;
    &showHelp;
    exit;
}

# Check if version number has been requested ... If so ... display version.
if(defined $opt_version)
{
    $opt_version = 1;
    &showVersion;
    exit;
}

# Check if path to WordNet Data files has been provided ... If so ... save it.
if(defined $opt_wnpath)
{
    $wnPCPath = $opt_wnpath;
    $wnUnixPath = $opt_wnpath;
}
else
{
    $wnPCPath = (defined $ENV{"WNHOME"}) ? $ENV{"WNHOME"} : "C:\\Program Files\\WordNet\\1.7";
    $wnUnixPath = (defined $ENV{"WNHOME"}) ? $ENV{"WNHOME"} : "/usr/local/wordnet1.7";
    $wnPCPath = (defined $ENV{"WNSEARCHDIR"}) ? $ENV{"WNSEARCHDIR"} : $wnPCPath."\\dict";
    $wnUnixPath = (defined $ENV{"WNSEARCHDIR"}) ? $ENV{"WNSEARCHDIR"} : $wnUnixPath."/dict";    
}

if(defined $opt_outfile)
{
    $fname = $opt_outfile;
}
else
{
    &showUsage;
    print "Type 'semTagFreq.pl --help' for detailed help.\n";
    exit;
}

# Initialize POS Map.
$posMap{"1"} = "n";
$posMap{"2"} = "v";


# Loading the Sense Indices.
print STDERR "Loading sense indices ... ";
open(IDX, $wnUnixPath."/index.sense") || open(IDX, $wnPCPath."\\sense.idx") || die "Unable to open sense index file.\n";
while(<IDX>)
{
    chomp;
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
    chomp;
    @line = split / /;
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
$wn = WordNet::QueryData->new();
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


print STDERR "Wrote file '$fname'.\n";


# Recursive subroutine that calculates the cumulative frequencies
# of all synsets in WordNet.
# INPUT PARAMS  : $offset  .. Offset of the synset to update.
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

# Subroutine to display Usage
sub showUsage
{
    print "Usage: semTagFreq.pl [{ --outfile FILE [--wnpath PATH] | --help | --version }]\n";
}

# Subroutine to show detailed help.
sub showHelp
{
    &showUsage;
    print "\nA helper tool perl program for the distance.pl program.\n";
    print "This program is used to generate the frequency count data\n";
    print "files which are used by the Jiang Conrath, Resnik and Lin\n";
    print "measures to calculate the information content of synsets in\n";
    print "WordNet. Files 'infocontent.dat' and 'top.dat' are\n";
    print "generated by the program. These are used by distance.pl for\n";
    print "some of the measures.\n";
    print "\nOptions:\n";
    print "--outfile     Name of the output file (FILE) to write out the\n";
    print "              information content data to.\n";
    print "--wnpath      Option to specify the path to the WordNet data\n";
    print "              files as PATH.\n";
    print "--help        Displays this help screen.\n";
    print "--version     Displays version information.\n";
}

# Subroutine to display version information.
sub showVersion
{
    print "semTagFreq.pl  -  version 0.01\n";
    print "Copyright (c) 2003, Siddharth Patwardhan & Ted Pedersen\n";
}

