#!/usr/local/bin/perl -w
#
# semCor17Freq.pl version 0.01
# (Updated 02/10/2003 -- Sid)
#
# This program reads the SemCor 1.7 files and computes the frequency 
# counts for each synset in WordNet, ignoring the sense tags in the corpus
# (treating it like a raw text corpus). These frequency counts are used by 
# various measures of semantic relatedness to calculate the information 
# content values of concepts. The output is generated in a format as 
# required by the WordNet::Similarity modules (ver 0.01) for computing
# semantic relatedness.
#
# Copyright (c) 2002-2003
# Ted Pedersen, University of Minnesota, Duluth
# tpederse@d.umn.edu
# Satanjeev Banerjee, Carnegie Mellon University, Pittsburgh
# banerjee+@cs.cmu.edu
# Siddharth Patwardhan, University of Minnesota, Duluth
# patw0006@d.umn.edu
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
#
#
#-----------------------------------------------------------------------------

# Variable declarations
my $wn;
my $wnver;
my $line;
my $sentence;
my @parts;
my %compounds;
my %stopWords;
my %offsetFreq;
my %newFreq;
my %topHash;

# Some modules used
use Getopt::Long;
use WordNet::QueryData;

# First check if no commandline options have been provided... in which case
# print out the usage notes!
if($#ARGV == -1)
{
    &minimalUsageNotes();
    exit;
}

# Now get the options!
&GetOptions("version", "help", "compfile=s", "stopfile=s", "outfile=s");

# If the version information has been requested
if(defined $opt_version)
{
    $opt_version = 1;
    &printVersion();
    exit;
}

# If detailed help has been requested
if(defined $opt_help)
{
    $opt_help = 1;
    &printHelp();
    exit;
}

# Look for the Compounds file... exit if not specified.
if(!defined $opt_compfile)
{
    &minimalUsageNotes();
    exit;
}

if(defined $opt_outfile)
{
    $outfile = $opt_outfile;
}
else
{
    &minimalUsageNotes();
    exit;
}

# Load the compounds
print STDERR "Loading compounds... ";
open (WORDS, "$opt_compfile") || die ("Couldnt open $opt_compfile.\n");
while (<WORDS>)
{
    s/[\r\f\n]//g;
    $compounds{$_} = 1;
}
close WORDS;
print STDERR "done.\n";

# Load the stop words if specified
if(defined $opt_stopfile)
{
    print STDERR "Loading stoplist... ";
    open (WORDS, "$opt_stopfile") || die ("Couldnt open $opt_stopfile.\n");
    while (<WORDS>)
    {
	s/[\r\f\n]//g;
	$stopWords{$_} = 1;
    }
    close WORDS;
    print STDERR "done.\n";
}

# Load up WordNet
print STDERR "Loading WordNet... ";
$wn=WordNet::QueryData->new();
die "Unable to create WordNet object.\n" if(!$wn);
print STDERR "done.\n";

# Load the topmost nodes of the hierarchies
print STDERR "Loading topmost nodes of the hierarchies... ";
&createTopHash();
print STDERR "done.\n";

# Read the input, form sentences and process each
print STDERR "Computing frequencies... ";
$sentence = "";
while($line=<>)
{
    $line=~s/[\r\f\n]//g;
    while($line =~ /<wf([^>]+)>/g)
    {
	$tagAttribs = $1;
	if($tagAttribs =~ /cmd=done/)
	{
	    if($tagAttribs =~ /lemma=([^ ]+) /)
	    {
		&updateFrequency($1) if(!defined $stopWords{$1});
	    }
	}
    }
}
print STDERR "done.\n";

# Propagating frequencies up the WordNet hierarchies... 
print STDERR "Propagating frequencies up through WordNet... ";
$offsetFreq{"n"}{0} = 0;
$offsetFreq{"v"}{0} = 0;
&propagateFrequency(0, "n");
&propagateFrequency(0, "v");
delete $newFreq{"n"}{0};
delete $newFreq{"v"}{0};
print STDERR "done.\n";

# Print the output to file
print STDERR "Writing output file... ";
open(OUT, ">$outfile") || die "Unable to open $outfile for writing.\n";
print OUT "wnver::".$wn->version()."\n";
foreach $pos ("n", "v")
{
    foreach $offset (sort {$a <=> $b} keys %{$newFreq{$pos}})
    {
	print OUT "$offset$pos $newFreq{$pos}{$offset}";
	print OUT " ROOT" if($topHash{$pos}{$offset});
	print OUT "\n";
    }
}
close(OUT);
print "done.\n";

# ----------------- Subroutines start Here ----------------------

# Subroutine to update frequency tokens on "seeing" a 
# word in text
sub updateFrequency
{
    my $word;
    my $pos;
    my $form;
    my @senses;
    my @forms;

    $word = shift;
    foreach $pos ("n", "v")
    {
	@senses = $wn->querySense($word."\#".$pos);
	@forms = $wn->validForms($word."\#".$pos);
	foreach $form (@forms)
	{
	    push @senses, $wn->querySense($form);
	}
	foreach (@senses)
	{
	    $offsetFreq{$pos}{$wn->offset($_)}++;
	}
    }
}

# Recursive subroutine that propagates the frequencies up
# the WordNet hierarchy
sub propagateFrequency
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
	$newFreq{$pos}{$node} = ($offsetFreq{$pos}{$node})?$offsetFreq{$pos}{$node}:0;
	return ($offsetFreq{$pos}{$node})?$offsetFreq{$pos}{$node}:0;
    }
    $sum = 0;
    if($#{$retValue} >= 0)
    {
	foreach $hyponym (@hyponyms)
	{
	    $sum += &propagateFrequency($hyponym, $pos);
	}
    }
    $newFreq{$pos}{$node} = (($offsetFreq{$pos}{$node})?$offsetFreq{$pos}{$node}:0) + $sum;
    return (($offsetFreq{$pos}{$node})?$offsetFreq{$pos}{$node}:0) + $sum;
}

# Subroutine that returns the hyponyms of a given synset.
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

# Subroutine to print detailed help
sub printHelp
{
    &printUsage();
    print "\nThis program computes the information content of concepts, by\n";
    print "counting the frequency of their occurrence in the Brown Corpus.\n";
    print "Options: \n";
    print "--compfile       Used to specify the file COMPFILE containing the \n";
    print "                 list of compounds in WordNet.\n";
    print "--outfile        Specifies the output file OUTFILE.\n";
    print "--stopfile       STOPFILE is a list of stop listed words that will\n";
    print "                 not be considered in the frequency count.\n";
    print "--help           Displays this help screen.\n";
    print "--version        Displays version information.\n\n";
}

# Subroutine to print minimal usage notes
sub minimalUsageNotes
{
    &printUsage();
    print "Type semCor17Freq.pl --help for detailed help.\n";
}

# Subroutine that prints the usage
sub printUsage
{
    print "semCor17Freq.pl [{--compfile COMPFILE --outfile OUTFILE [--stopfile STOPFILE] [FILE...] | --help | --version }]\n"
}

# Subroutine to print the version information
sub printVersion
{
    print "semCor17Freq.pl version 0.01\n";
    print "Copyright (c) 2002-2003 Ted Pedersen, Satanjeev Banerjee & Siddharth Patwardhan.\n";
}
