#!/usr/local/bin/perl -w
#
# similarity.pl Version 0.06
# (Updated 10/18/2003 -- Sid)
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
# Copyright (c) 2003,
#
# Siddharth Patwardhan, University of Utah, Salt Lake City
# sidd@cs.utah.edu
#
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

BEGIN
{
    # Include the QueryData package.
    use WordNet::QueryData 1.30;
    
    # Include library to get Command-Line options.
    use Getopt::Long;
    
    # If no Command-Line arguments given ... show minimal help screen ... exit.
    if($#ARGV < 0)
    {
	print "Usage: similarity.pl [{--type TYPE [--config CONFIGFILE] [--allsenses] [--offsets]";
	print " [--trace] [--wnpath PATH] [--simpath SIMPATH] {--interact | --file FILENAME | WORD1 WORD2}\n";
	print "                     |--help \n";
	print "                     |--version }]\n";
	print "Type similarity.pl --help for detailed help.\n";
	exit;
    }
    
    # Get Command-Line options.
    &GetOptions("help", "version", "wnpath=s", "simpath=s", "type=s", 
		"config=s", "file=s", "trace", "allsenses", "offsets",  "interact");
    
    # To be able to use a local install of similarity modules.
    if(defined $opt_simpath)
    {
      my @tmpINC = @INC;
      @INC = ($opt_simpath);
      push(@INC, @tmpINC); 
    }
}

# Declarations:
my $wn;       # WordNet::QueryData object.
my $measure;  # WordNet::Similarity object.
my $type;     # WordNet::Similarity module name.

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
if(!defined $opt_type)
{
    print STDERR "Required switch '--type' missing.\n";
    &showUsage;
    exit;
}

# If the file option has not been provided, then 
# the two words must be on the command line.
# Get the two words if they have been provided.
if(!(defined $opt_file) && !(defined $opt_interact) && $#ARGV < 1)
{
    print STDERR "Required parameter(s) missing.\n";
    &showUsage;
    exit;
}

# Initialize the WordNet::QueryData module.
print STDERR "Loading WordNet... ";
$wn = (defined $opt_wnpath) ? WordNet::QueryData->new($opt_wnpath) : WordNet::QueryData->new();
if(!$wn)
{
    print STDERR "Unable to create WordNet object.\n";
    exit;
}
print STDERR "done.\n";

# Load the WordNet::Similarity module.
print STDERR "Loading Module... ";
$type = $opt_type;
$opt_type =~ s/::/\//g;
$opt_type .= ".pm";
require $opt_type;
if(defined $opt_config)
{
    $measure = $type->new($wn, $opt_config);
}
else
{
    $measure = $type->new($wn);
}

# If object not created.
if(!$measure)
{
    print STDERR "Unable to create WordNet::Similarity object.\n";
    exit;
}

# If serious error... stop.
($error, $errorString) = $measure->getError();
if($error > 1)
{
    print STDERR $errorString."\n";
    exit;
}

# Set the appropriate trace params.
if(defined $opt_trace)
{
    $measure->{'trace'} = ((defined $opt_offsets) ? 2 : 1);
}
else
{
    if($measure->{'trace'})
    {
	$opt_trace = 1;
	$measure->{'trace'} = ((defined $opt_offsets) ? 2 : 1);
    }
}
print STDERR "done.\n";

# Get the module initialization parameters.
if(defined $opt_trace)
{
    my $loctr = $measure->getTraceString();
    print "\n$loctr\n" if($loctr !~ /^\s*$/);
}
print STDERR $errorString."\n" if($error == 1);

# Process the input data...
if(defined $opt_interact)
{
    my ($con1, $con2);

    print "Starting interactive mode (Enter blank fields to end session)...\n";
    $con1 = $con2 = "x";               # Hack to start the interactive while loop.
    while($con1 ne "" && $con2 ne "")
    {
	print "Concept \#1: ";
	$con1 = <STDIN>;
	$con1 =~ s/[\r\f\n]//g;
	$con1 =~ s/^\s+//;
	$con1 =~ s/\s+$//;
	last if($con1 eq "");
	print "Concept \#2: ";
	$con2 = <STDIN>;
	$con2 =~ s/[\r\f\n]//g;
	$con2 =~ s/^\s+//;
	$con2 =~ s/\s+$//;
	last if($con2 eq "");
	print "$con1  $con2\n" if(defined $opt_trace);
	&process($con1, $con2);
	print "\n" if(defined $opt_trace);
    }
}
elsif(defined $opt_file)
{
    open(DATA, $opt_file) || die "Unable to open file: $opt_file\n";
    while(<DATA>)
    {
	s/[\r\f\n]//g;
	s/^\s+//;
	s/\s+$//;
	@words = split /\s+/;
	if(scalar(@words) && defined $words[0] && defined $words[1])
	{
	    print "$words[0]  $words[1]\n" if(defined $opt_trace);
	    &process($words[0], $words[1]);
	    print "\n" if(defined $opt_trace);
	}
    }      
    close(DATA);
}
else
{
    &process(shift, shift);
}


## ------------------- Subroutines Start Here ------------------- ##

# Subroutine that processes two words (finds relatedness).
sub process
{
    my $input1 = shift;
    my $input2 = shift;
    my $word1 = $input1;
    my $word2 = $input2;
    my $wps;
    my @w1options;
    my @w2options;
    my @senses1;
    my @senses2;
    my %distanceHash;

    if(!(defined $word1 && defined $word2))
    {
	print STDERR "Undefined input word(s).\n";
	return;
    }
    $word1 =~ s/[\r\f\n]//g;
    $word1 =~ s/^\s+//;
    $word1 =~ s/\s+$//;
    $word1 =~ s/\s+/_/g;
    $word2 =~ s/[\r\f\n]//g;
    $word2 =~ s/^\s+//;
    $word2 =~ s/\s+$//;
    $word2 =~ s/\s+/_/g;
    @w1options = &getWNSynsets($word1);
    @w2options = &getWNSynsets($word2);
    if(!(scalar(@w1options) && scalar(@w2options)))
    {
	print STDERR "'$word1' not found in WordNet.\n" if(!scalar(@w1options));
	print STDERR "'$word2' not found in WordNet.\n" if(!scalar(@w2options));
	return;
    }
    @senses1 = ();
    @senses2 = ();
    foreach $wps (@w1options)
    {
	if($wps =~ /\#([nvar])\#/)
	{
	    push(@senses1, $wps) if($measure->{$1});
	}
    }
    foreach $wps (@w2options)
    {
	if($wps =~ /\#([nvar])\#/)
	{
	    push(@senses2, $wps) if($measure->{$1});
	}
    }
    if(!scalar(@senses1) || !scalar(@senses2))
    {
	print STDERR "Possible part(s) of speech of word(s) cannot be handled by module.\n";
	return;
    }

    %distanceHash = &getDistances([@senses1], [@senses2]);

    if(defined $opt_allsenses)
    {
	my $key;
	print "$input1  $input2  (all senses)\n";
	foreach $key (sort {$distanceHash{$b} <=> $distanceHash{$a}} keys %distanceHash)
	{
	    my ($op1, $op2) = split(/\s+/, $key);
	    &printSet($op1);
	    print "  ";
	    &printSet($op2);
	    print "  $distanceHash{$key}\n";
	}
    }
    else
    {
	my ($key) = sort {$distanceHash{$b} <=> $distanceHash{$a}} keys %distanceHash;
	my ($op1, $op2) = split(/\s+/, $key);
	&printSet($op1);
	print "  ";
	&printSet($op2);
	print "  $distanceHash{$key}\n";	
    }
}

# Subroutine to get all possible synsets corresponding to a word(#pos(#sense))
sub getWNSynsets
{
    my $word = shift;
    my $pos;
    my $sense;
    my $key;
    my @senses;

    return () if(!defined $word);

    # First separately handle the case when the word is in word#pos or 
    # word#pos#sense form.
    if($word =~ /\#/)
    {
	if($word =~ /^([^\#]+)\#([^\#])\#([^\#]+)$/)
	{
	    $word = $1;
	    $pos = $2;
	    $sense = $3;
	    return () if($sense !~ /[0-9]+/ || $pos !~ /^[nvar]$/);
	    @senses = $wn->querySense($word."\#".$pos);
	    foreach $key (@senses)
	    {
		if($key =~ /\#$sense$/)
		{
		    return ($key);
		}
	    }
	    return ();
	}
	elsif($word =~ /^([^\#]+)\#([^\#]+)$/)
	{
	    $word = $1;
	    $pos = $2;
	    return () if($pos !~ /[nvar]/);
	}
	else
	{
	    return ();
	}
    }
    else
    {
	$pos = "nvar";
    }

    # Get the senses corresponding to the raw form of the word.
    @senses = ();
    foreach $key ("n", "v", "a", "r")
    {
	if($pos =~ /$key/)
	{
	    push(@senses, $wn->querySense($word."\#".$key));
	}
    }

    # If no senses corresponding to the raw form of the word,
    # ONLY then look for morphological variations.
    if(!scalar(@senses))
    {
	foreach $key ("n", "v", "a", "r")
	{
	    if($pos =~ /$key/)
	    {
		my @tArr = ();
		push(@tArr, $wn->validForms($word."\#".$key));
		push(@senses, $wn->querySense($tArr[0])) if(defined $tArr[0]);
	    }
	}
    }

    return @senses;
}

# Subroutine to compute relatedness between all pairs of senses.
sub getDistances
{
    my $list1 = shift;
    my $list2 = shift;
    my $synset1;
    my $synset2;
    my $tracePrinted = 0;
    my %retHash = ();

    return {} if(!defined $list1 || !defined $list2);

  LEVEL2:
    foreach $synset1 (@{$list1})
    {
	foreach $synset2 (@{$list2})
	{
	    $retHash{"$synset1 $synset2"} = $measure->getRelatedness($synset1, $synset2);
	    ($err, $errString) = $measure->getError();
	    if($err)
	    {
		print STDERR "$errString\n";
		last LEVEL2;
	    }
	    if(defined $opt_trace)
	    {
		my $loctr = $measure->getTraceString();
		if($loctr !~ /^\s*$/)
		{
		    print "$synset1 $synset2:\n";
		    print "$loctr\n";
		    $tracePrinted = 1;
		}
	    }
	}
    }
    print "\n\n" if(defined $opt_trace && $tracePrinted);

    return %retHash;
}

# Print routine to print synsets...
sub printSet
{
    my $synset = shift;
    my $offset;
    my $printString = "";
    
    if($synset =~ /(.*)\#([nvar])\#(.*)/)
    {
	if(defined $opt_offsets)
	{
	    $offset = $wn->offset($synset);
	    $printString = sprintf("$1\#$2\#%08d", $offset);
	    $printString =~ s/\s+$//;
	    $printString =~ s/^\s+//;
	}
	else
	{
	    $printString = "$synset";
	    $printString =~ s/\s+$//;
	    $printString =~ s/^\s+//;
	}
    }
    print "$printString";
}

# Subroutine to show minimal help.
sub showUsage
{
    print "Usage: similarity.pl [{--type TYPE [--config CONFIGFILE] [--allsenses] [--offsets]";
    print " [--trace] [--wnpath PATH] [--simpath SIMPATH] {--interact | --file FILENAME | WORD1 WORD2}\n";
    print "                     |--help \n";
    print "                     |--version }]\n";
}

# Subroutine to show detailed help.
sub showHelp
{
    &showUsage;
    print "\nDisplays the semantic similarity between the base forms of WORD1 and\n";
    print "WORD2 using various similarity measures described in Budanitsky Hirst\n";
    print "(2001). The parts of speech of WORD1 and/or WORD2 can be restricted\n";
    print "by appending the part of speech (n, v, a, r) to the word.\n";
    print "(For eg. car#n will consider only the noun forms of the word 'car' and\n";
    print "walk#nv will consider the verb and noun forms of 'walk').\n";
    print "Individual senses of can also be given as input, in the form of\n";
    print "word#pos#sense strings (For eg., car#n#1 represents the first sense of\n";
    print "the noun 'car').\n\n";
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
    print "               'WordNet::Similarity::vector' Gloss Vector overlap measure.\n";
    print "               'WordNet::Similarity::edge'   Simple edge-counts (inverted).\n";
    print "               'WordNet::Similarity::wup'    Wu Palmer measure.\n";
    print "               'WordNet::Similarity::random' A random measure.\n";
    print "--config      Module-specific configuration file CONFIGFILE. This file\n";
    print "              contains the configuration that is used by the\n";
    print "              WordNet::Similarity modules during initialization. The format\n";
    print "              of this file is specific to each modules and is specified in\n";
    print "              the module man pages and in the documentation of the\n";
    print "              WordNet::Similarity package.\n";
    print "--allsenses   Displays the relatedness between every sense pair of the\n";
    print "              two input words WORD1 and WORD2.\n";
    print "--offsets     Displays all synsets (in the output, including traces) as\n";
    print "              synset offsets and part of speech, instead of the \n";
    print "              word#partOfSpeech#senseNumber format used by QueryData.\n";
    print "              With this option any WordNet synset is displayed as \n";
    print "              word#partOfSpeech#synsetOffset in the output.\n";
    print "--trace       Switches on 'Trace' mode. Displays as output on STDOUT,\n";
    print "              the various stages of the processing. This option overrides\n";
    print "              the trace option in the module configuration file (if\n";
    print "              specified).\n";
    print "--interact    Starts the interactive mode. Useful for demoes, for debugging\n";
    print "              and to play around with the measures.\n";
    print "--file        Allows the user to specify an input file FILENAME\n";
    print "              containing pairs of word whose semantic similarity needs\n";
    print "              to be measured. The file is assumed to be a plain text\n";
    print "              file with pairs of words separated by newlines, and the\n";
    print "              words of each pair separated by a space.\n";
    print "--wnpath      Option to specify the path of the WordNet data files\n";
    print "              as PATH. (Defaults to /usr/local/WordNet-1.7.1/dict on Unix\n";
    print "              systems and C:\\WordNet\\1.7.1\\dict on Windows systems)\n";
    print "--simpath     If the relatedness module to be used, is locally installed,\n";
    print "              then SIMPATH can be used to indicate the location of the local\n";
    print "              install of the measure.\n";
    print "--help        Displays this help screen.\n";
    print "--version     Displays version information.\n\n";
    print "\nNOTE: The environment variables WNHOME and WNSEARCHDIR, if present,\n";
    print "are used to determine the location of the WordNet data files.\n";
    print "Use '--wnpath' to override this.\n\n";
    print "ANOTHER NOTE: During any given session, only one of three modes of input\n";
    print "can be specified to the program -- command-line input (WORD1 WORD2), file\n";
    print "input (--file option) or the interactive input (--interact option). If more\n";
    print "than one mode of input is invoked at a given time, only one of those modes\n";
    print "will work, according to the following levels of priority:\n";
    print "  interactive mode (--interact option) has highest priority.\n";
    print "  file input (--file option) has medium priority.\n";
    print "  command-line input (WORD1 WORD2) has lowest priority.\n";
}

# Subroutine to display version information.
sub showVersion
{
    print "similarity.pl  version 0.06\n";
    print "Copyright (c) 2003, Siddharth Patwardhan & Ted Pedersen\n";
}

