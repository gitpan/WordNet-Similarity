#!/usr/local/bin/perl -w
#
# similarity.pl Version 0.01
# (Updated 02/10/2003 -- Sid)
#
# Implementation of semantic relatedness measures between words as 
# described in Budanitsky and Hirst (1995) "Semantic distance in 
# WordNet: An Experimental, application-oriented evaluation of five 
# measures." The measures described and implemented are 
#
# (1) Leacock and Chodorow (1998)
# (2) Jiang and Conrath (1997)
# (3) Resnik (1995)
# (4) Lin (1998)
# (5) Hirst St. Onge (1998)
#
# This program uses the Wordnet::Similarity perl modules for computing
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
# ------------------------------------------------------------------


# Include the QueryData package.
use WordNet::QueryData;

# Include library to get Command-Line options.
use Getopt::Long;

# Variables that are used.
my $sourceWord1;         # The source word entered by the user.
my $sourceWord2;         # The source word entered by the user.
my $word1;               # Contains the first word of the two.
my $word2;               # Contains the second word of the two.
my $type;                # The type of measure to use.
my $wn;                  # Contains an instance of WordNet used by QueryData.
my $traceFlag;           # Flag indicating "verbose" mode.
my $offsetFlag;          # Flag indicating if offsets are printed in the output.

# If no Command-Line arguments given ... show minimal help screen ... exit.
if($#ARGV < 0)
{
    &showUsage;
    print "Type similarity.pl --help for detailed help.\n";
    exit;
}

# Get Command-Line options.
GetOptions("help", "version", "wnpath=s", "type=s", "file=s", "trace", "allsenses", "offsets");

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

# Which similarity measure must be used ... 
if(defined $opt_type)
{
    $type = $opt_type;
}
else
{
    print STDERR "Required switch '--type' missing.\n";
    &showUsage;
    exit;
}

# Check for the trace option ... 
if(defined $opt_trace)
{
    $traceFlag=1;
    $opt_trace=1;
}
else
{
    $traceFlag=0;
}

# Check if WordNet offsets are desired.
if(defined $opt_offsets)
{
    $offsetFlag = 1;
    $opt_offsets = 1;
}
else
{
    $offsetFlag = 0;
}

# If the file option has not been provided, then 
# the two words must be on the command line.
# Get the two words if they have been provided.
if(!(defined $opt_file) && $#ARGV < 1)
{
    print STDERR "Required parameter(s) missing.\n";
    &showUsage;
    exit;
}
else
{
    $sourceWord1 = shift;
    $sourceWord2 = shift;
}

# Initialize the QueryData module.
print STDERR "Loading WordNet... ";
$wn = (defined $opt_wnpath) ? WordNet::QueryData->new($opt_wnpath) : WordNet::QueryData->new();
if(!$wn)
{
    print STDERR "Unable to create WordNet object.\n";
    exit;
}
print STDERR "done.\n";

# Load the similarity measure module.
print STDERR "Loading Module... ";
$type =~ s/::/\//g;
$type .= ".pm";
require $type;
$measure = $opt_type->new($wn);
if(!$measure)
{
    print STDERR "Unable to create similarity object.\n";
    exit;
}
($error, $errorString) = $measure->getError();
if($error > 1)
{
    print STDERR $errorString."\n";
    exit;
}
$measure->{'trace'} = (($offsetFlag) ? 2 : 1) if($traceFlag);
print STDERR "done.\n";
print STDERR $errorString."\n" if($error == 1);

# Process the input data...
if(defined $opt_file)
{
    open(DATA, $opt_file) || die "Unable to open file: $opt_file\n";
    while(<DATA>)
    {
	s/[\r\f\n]//g;
	s/^\s*//;
	s/\s*$//;
	@words = split /\s+/;
	if(@words)
	{
	    if(defined $words[0] && defined $words[1])
	    {
		$sourceWord1 = $words[0];
		$sourceWord2 = $words[1];
		last if(&getValidForms() == 0);
		&coreProcess();
	    }
	}
    }      
    close(DATA);
}
else
{
    exit if(&getValidForms() == 0);
    &coreProcess();
}

## ------------------- Subroutines Start Here ------------------- ##

# Get the similarity between the words or between all senses of 
# the words.
sub coreProcess
{
    my $dist;
    
    # If relatedness between all senses of the word have been
    # requested.
    if(defined $opt_allsenses)
    {
	my $retHash;
	my $key1;
	my $key2;
	$opt_allsenses = 1;
	
	# What are the words being measured.
	print "$word1  $word2  (allsenses)\n";
	
	# Getting the hash containing the relatedness.
	$retHash = &allDistances($word1, $word2);
	if(defined $retHash)
	{
	    foreach $key1 (keys %{$retHash})
	    {
		foreach $key2 (keys %{${$retHash}{$key1}})
		{
		    print "$key1  $key2  ${$retHash}{$key1}{$key2}\n";
		}
	    }
	}
	else
	{
	    print STDERR "$errorString\n";
	    $errorString = "No error.";
	}
    }
    else
    {
	# Getting the similarity between the words.
	$dist = &distance($word1, $word2);
	
	# Putting back the underscores.
	$word1 =~ s/ +/_/g;
	$word2 =~ s/ +/_/g;
	
	# Printing the output.
	if(defined $dist)
	{
	    print "$word1  $word2  $dist\n";
	}
	else
	{
	    print STDERR "$errorString\n";
	    $errorString = "No error.";
	}
    }
}

# Get the Valid forms of <Word1> and <Word2> from WordNet.
# INPUT PARAMS  : none
# RETURN VALUES : 1      .. on success.
#                 0      .. if unsuccessful.
sub getValidForms
{
    $word1 = &_getValidForm($sourceWord1, $forms);
    $word2 = &_getValidForm($sourceWord2, $forms);
    if(!$word1)
    {
	print STDERR "Word '$sourceWord1' not defined in WordNet.\n";
	return 0;
    }
    if(!$word2)
    {
	print STDERR "Word '$sourceWord2' not defined in WordNet.\n";
	return 0;    
    }
    return 1;
}

# Subroutine to get the valid form of the given word.
# (for specified parts of speech) 
# The validForms function of QueryData is used to get the 
# valid forms of the word for the specified parts of speech 
# and the first valid form is returned taken in the following 
# order -- nouns, verbs, adjectives, adverbs.
# INPUT PARAMS  : $word .. the input word.
# RETURN VAULES : $validWord .. the valid form of $word or
#                 undef      .. if no valid form exists.
sub _getValidForm
{
    my $word;
    my $wordWithPOS;
    my $pos;
    my @forms;

    $word = shift;
    foreach $pos ("n", "v", "a", "r")
    {
	if($measure->{$pos})
	{
	    $wordWithPOS = $word."\#$pos";
	    @forms = $wn->validForms($wordWithPOS);
	    if(@forms)
	    {
		return $1 if($forms[0] =~ /([^\#]*)(\#.*)?/);
	    }
	}
    }
    return undef;
}

# Returns the maximum relatedness of two words.
# INPUT PARAMS  : $word1    .. one of the two words.
#                 $word2    .. the second word of the two whose 
#                              semantic similarity needs to be measured.
# RETURN VALUES : $distance .. the semantic similarity between the two
#                              words.
sub distance
{
    my $word1;
    my $word2;
    my $synset1;
    my $synset2;
    my $selSynset1;
    my $selSynset2;
    my $dist;
    my $minDist;
    my $err;
    my $errString;
    my @synsets1;
    my @synsets2;

    $word1 = shift;
    $word2 = shift;

    # Get the offsets of all the synsets of <Word1> ... 
    @synsets1 = &_getSynsets($word1);

    # Get the offsets of all the synsets of <Word2> ... 
    @synsets2 = &_getSynsets($word2);
    
    # For each offset1-offset2 pair calculate the similarity value for
    # each pair ... select the pair with the smallest similarity.
    $minDist = -1;

  OUTSIDE:
    foreach $synset1 (@synsets1)
    {
	foreach $synset2 (@synsets2)
	{
	    $dist = $measure->getRelatedness($synset1, $synset2);
	    ($err, $errString) = $measure->getError();
	    if($err)
	    {
		print STDERR "$errString\n";
		last OUTSIDE;
	    }
	    if($traceFlag)
	    {
		print $measure->getTraceString();
	    }
	    if($dist > $minDist)
	    {
		$selSynset1 = $synset1;
		$selSynset2 = $synset2;
		$minDist = $dist;
	    }
	}
    }
    
    return $minDist;
}

# Calculates and returns relatedness between every pair of synsets of
# two given words.
# INPUT PARAMS  : $word1     .. one of the two words.
#                 $word2     .. the second word of the two whose 
#                               semantic relatedness needs to be measured.
# RETURN VALUES : %distances .. a hash of hashes with the semantic relatedness
#                               every pair of synsets of the two words.
sub allDistances
{
    my $word1;
    my $word2;
    my $synset1;
    my $synset2;
    my $err;
    my $errString;
    my @synsets1;
    my @synsets2;
    my %returnHash;

    $word1 = shift;
    $word2 = shift;

    # Get the offsets of all the synsets of <Word1> ... 
    @synsets1 = &_getSynsets($word1);

    # Get the offsets of all the synsets of <Word2> ... 
    @synsets2 = &_getSynsets($word2);
    
    # For each offset1-offset2 pair calculate the similarity value for
    # each pair ... select the pair with the smallest similarity.
    %returnHash = ();

  LEVEL2:
    foreach $synset1 (@synsets1)
    {
	foreach $synset2 (@synsets2)
	{
	    $returnHash{$synset1}{$synset2} = $measure->getRelatedness($synset1, $synset2);
	    ($err, $errString) = $measure->getError();
	    if($err)
	    {
		print STDERR "$errString\n";
		last LEVEL2;
	    }
	    if($traceFlag)
	    {
		print $measure->getTraceString();
	    }
	}
    }

    return {%returnHash};
}

# Subroutine to get all the synsets for a given word.
# INPUT PARAMS  : $word    .. the input word.
# RETURN VALUES : @synsets .. array of wps strings representing synsets.
sub _getSynsets
{
    my $word;
    my $pos;
    my @synsets;

    $word = shift;
    @synsets = ();
    foreach $pos ("n", "v", "a", "r")
    {
	push(@synsets, $wn->querySense($word."\#$pos")) if($measure->{$pos});
    }

    return @synsets;
}

# Subroutine to show minimal help.
sub showUsage
{
    print "Usage: similarity.pl [{--type TYPE [--allsenses] [--offsets] [--trace] [--file FILENAME]";
    print " [--wnpath PATH] WORD1 WORD2 |--help |--version }]\n";
}

# Subroutine to show detailed help.
sub showHelp
{
    &showUsage;
    print "\nDisplays the semantic similarity between the base forms of \n";
    print "WORD1 and WORD2 using various similarity measures described\n";
    print "in Budanitsky Hirst (2001).\n\n";
    print "Options:\n";
    print "--type        Switch to select the type of similarity measure\n";
    print "              to be used while calculating the semantic\n";
    print "              relatedness. The following strings are defined.\n";
    print "               'WordNet::Similarity::lch'    The Leacock Chodorow measure.\n";
    print "               'WordNet::Similarity::jcn'    The Jiang Conrath measure.\n";
    print "               'WordNet::Similarity::res'    The Resnik measure.\n";
    print "               'WordNet::Similarity::lin'    The Lin measure.\n";
    print "               'WordNet::Similarity::hso'    The Hirst St. Onge measure.\n";
    print "               'WordNet::Similarity::lesk'   Adapted Lesk measure.\n";
    print "               'WordNet::Similarity::edge'   Simple edge-counts (inverted).\n";
    print "               'WordNet::Similarity::random' A random measure.\n";
    print "--allsenses   Displays the relatedness between every sense pair of the\n";
    print "              two input words WORD1 and WORD2.\n";
    print "--offsets     Displays all synsets (in the output, including traces) as\n";
    print "              synset offsets and part of speech, instead of the \n";
    print "              word#partOfSpeech#senseNumber format used by QueryData.\n";
    print "              With this option any WordNet synset is displayed as \n";
    print "              word#partOfSpeech#synsetOffset in the output.\n";
    print "--trace       Switches on 'Trace' mode. Displays as output on STDOUT,\n";
    print "              the various stages of the processing.\n";
    print "--file        Allows the user to specify an input file FILENAME\n";
    print "              containing pairs of word whose semantic similarity needs\n";
    print "              to be measured. The file is assumed to be a plain text\n";
    print "              file with pairs of words separated by newlines, and the\n";
    print "              words of each pair separated by a space.\n";
    print "--wnpath      Option to specify the path of the WordNet data files\n";
    print "              as PATH. (Defaults to /usr/local/wordnet1.7/dict on Unix\n";
    print "              systems and C:\\wn17\\dict on Windows systems)\n";
    print "--help        Displays this help screen.\n";
    print "--version     Displays version information.\n";
    print "\nNOTE: The environment variables WNHOME and WNSEARCHDIR, if present,\n";
    print "are used to determine the location of the WordNet data files.\n";
    print "Use '--wnpath' to override this.\n";
}

# Subroutine to display version information.
sub showVersion
{
    print "similarity.pl  version 0.01\n";
    print "Copyright (c) 2003, Siddharth Patwardhan & Ted Pedersen\n";
}

