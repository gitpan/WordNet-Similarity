#!/usr/local/bin/perl -w
#
# wordVectors.pl version 0.06
# (Last updated 10/13/2003 -- Sid)
#
# Program to create word vectors (co-occurrence vectors) for all
# words in WordNet glosses.
#
# Copyright (c) 2002-2003
#
# Ted Pedersen, University of Minnesota, Duluth
# tpederse@d.umn.edu
#
# Siddharth Patwardhan, University of Utah, Salt Lake City
# sidd@cs.utah.edu
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
# along with this program; if not, write to: 
#
#    The Free Software Foundation, Inc., 
#    59 Temple Place - Suite 330, 
#    Boston, MA  02111-1307, USA.
#
#
#-----------------------------------------------------------------------------

use Getopt::Long;
use WordNet::QueryData;
use dbInterface;

# Declarations!
my $wn;              # WordNet::QueryData object.
my $fh;              # Filehandle, to hold data file handles.
my $wnPCPath;        # Path to WordNet data files (on Windows).
my $wnUnixPath;      # Path to WordNet data files (on Unix).
my $documentCount;   # Document Count (Gloss Count).
my $db;              # BerkeleyDB access object.
my %rows;            # Hash holding the rows of the matrix.
my %compounds;       # List of compounds in WordNet.
my %stopWords;       # List of stop words.
my %wordMatrix;      # Matrix of co-occurrences.
my %wordIndex;       # List of words word -> index mapping.
my %wordTF;          # Term Frequency (for each word).
my %wordDF;          # Document Frequency (for each word).
my %wFreq;           # Word Frequency.

# Get the options!
&GetOptions("version", "help", "wnpath=s", "noexamples", "compfile=s", "stopfile=s", "cutoff=f", "rhigh=i",  "rlow=i", "chigh=i", "clow=i");

# If the version information has been requested...
if(defined $opt_version)
{
    $opt_version = 1;     # Hack to prevent "Single occurrence of variable" warning.
    &printVersion();
    exit;
}

# If detailed help has been requested...
if(defined $opt_help)
{
    $opt_help = 1;        # Hack to prevent "Single occurrence of variable" warning.
    &printHelp();
    exit;
}

# If no database filename, error...
if(@ARGV)
{
    if(-e $ARGV[0])
    {
	my $getuser;
	print STDERR "File $ARGV[0] already exists. Overwrite? [y/n] ";
	$getuser = <STDIN>;
	$getuser =~ s/[\r\f\n]//g;
	$getuser =~ s/\s*//g;
	if(!($getuser =~ /^y$/ || $getuser =~ /^Y$/))
	{
	    print STDERR "Exiting.\n";
	    exit;
	}
	if(!(-w $ARGV[0]))
	{
	    print STDERR "Unable to overwrite $ARGV[0]. Exiting.\n";
	    exit;
	}
    }
}
else
{
    print "Specify name of database file.\n";
    &printUsage();
    exit;
}

# Check if compounds file is provided... if so, get the compounds.
if(defined $opt_compfile)
{
    print STDERR "Loading compounds... ";
    open (WORDS, "$opt_compfile") || die ("Couldnt open $opt_compfile.\n");
    while (<WORDS>)
    {
	s/[\r\f\n]//g;
	s/\s+//g;
	$compounds{$_} = 1;
    }
    close WORDS;
    print STDERR "done.\n";
}

# Load the stop words if specified
if(defined $opt_stopfile)
{
    print STDERR "Loading stoplist... ";
    open (WORDS, "$opt_stopfile") || die ("Couldnt open $opt_stopfile.\n");
    while (<WORDS>)
    {
	s/[\r\f\n]//g;
	s/\s+//g;
	$stopWords{$_} = 1;
    }
    close WORDS;
    print STDERR "done.\n";
}

# Hack to prevent "Single occurrence of variable" warning
$opt_noexamples = 1 if(defined $opt_noexamples);

# Check if path to WordNet Data files has been provided ... If so ... save it.
print STDERR "Loading WordNet... ";
if(defined $opt_wnpath)
{
    $wnPCPath = $opt_wnpath;
    $wnUnixPath = $opt_wnpath;
    $wn = WordNet::QueryData->new($opt_wnpath);
}
else
{
    $wnPCPath = (defined $ENV{"WNHOME"}) ? $ENV{"WNHOME"} : "C:\\Program Files\\WordNet\\1.7.1";
    $wnUnixPath = (defined $ENV{"WNHOME"}) ? $ENV{"WNHOME"} : "/usr/local/WordNet-1.7.1";
    $wnPCPath = (defined $ENV{"WNSEARCHDIR"}) ? $ENV{"WNSEARCHDIR"} : $wnPCPath."\\dict";
    $wnUnixPath = (defined $ENV{"WNSEARCHDIR"}) ? $ENV{"WNSEARCHDIR"} : $wnUnixPath."/dict";
    if(defined $ENV{"WNHOME"})
    {
	$wn = WordNet::QueryData->new();
    }
    else
    {
	$wn = WordNet::QueryData->new("/usr/local/WordNet-1.7.1");
	$wn = WordNet::QueryData->new("C:\\Program Files\\WordNet\\1.7.1") if(!$wn);
    }
}
if(!$wn)
{
    print STDERR "Unable to create WordNet::QueryData object.\n";
    exit;
}
$wnPCPath = $wnUnixPath = $wn->dataPath() if($wn->can('dataPath'));
print STDERR "done.\n";

print STDERR "Creating word vectors...                                       ";
open(NIDX, $wnUnixPath."/data.noun") || open(NIDX, $wnPCPath."\\noun.dat") || die "Unable to open data file.\n";
open(VIDX, $wnUnixPath."/data.verb") || open(VIDX, $wnPCPath."\\verb.dat") || die "Unable to open data file.\n";
open(AIDX, $wnUnixPath."/data.adj") || open(AIDX, $wnPCPath."\\adj.dat") || die "Unable to open data file.\n";
open(RIDX, $wnUnixPath."/data.adv") || open(RIDX, $wnPCPath."\\adv.dat") || die "Unable to open data file.\n";

$documentCount = 0;
foreach $fh (NIDX, VIDX, AIDX, RIDX)
{
    my $line;
    my $word1;
    my $word2;
    my @parts;
    my @words;
    my @walk;
    my %tHash;

    while($line = <$fh>)
    {
	next if ($line =~ m/^\s/);
#	last if(($documentCount + 1) % 10000 == 0);
	$line =~ s/[\r\f\n]//g;
	$line =~ s/.*\|//;
	$line = lc($line);
	$line =~ s/\".*\"//g if(defined $opt_noexamples);
	@parts = split(/\;/, $line);
	@words = ();
	%tHash = ();
	while(@parts)
	{
	    $line = shift(@parts);
	    $line =~ s/\'//g;
	    $line =~ s/[^a-z0-9]+/ /g;
	    $line =~ s/^\s*//;
	    $line =~ s/\s*$//;
	    $line = &compoundify($line) if(defined $opt_compfile);
	    @walk = split(/\s+/,$line);
	    @walk = &_removeStopWords(@walk) if(defined $opt_stopfile);
	    @walk = &_stem(@walk);
	    @walk = &_removeStopWords(@walk) if(defined $opt_stopfile);
	    push @words, @walk;
	}
	foreach $word1 (@words)
	{
	    $tHash{$word1} = 1;
	    $wordTF{$word1}++;
	    foreach $word2 (@words)
	    {
		$wordMatrix{$word1}{$word2}++;
	    }
	}
	foreach $word1 (keys %tHash)
	{
	    $wordDF{$word1}++;
	}
	$documentCount++;
	print STDERR "\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b";
	printf STDERR "%6d (of approximately 111400) done.", $documentCount;
    }
}
print STDERR "\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b";
printf STDERR "%6d (of approximately 111400) done.", $documentCount;
close(NIDX);
close(VIDX);
close(AIDX);
close(RIDX);
print STDERR "\n";

print STDERR "Inconsistent TERMFREQ and DOCFREQ hashes.\n" if(scalar(keys(%wordTF)) != scalar(keys(%wordDF)));

# Pruning columns...
%rows = %wordTF;
if(defined $opt_chigh || defined $opt_clow)
{
    print STDERR "Pruning columns... ";
    my $word;
    my %tmpTF = %wordTF;
    my %tmpDF = %wordDF;
    %wordTF = ();
    %wordDF = ();
    my $c = 0;
    foreach $word (sort {$tmpTF{$b} <=> $tmpTF{$a}} keys %tmpTF)
    {
      next if(defined $opt_chigh && $tmpTF{$word} > $opt_chigh);
      last if(defined $opt_clow && $tmpTF{$word} < $opt_clow);
      $wordTF{$word} = $tmpTF{$word};
      $wordDF{$word} = $tmpDF{$word};
      $c++;
    }
    print STDERR "done.\n";
}

# Assigning indices to words... pruning cut-off words...
print STDERR "Writing dimensions...                       ";
my $word;
my @words = keys %wordTF;
my $final = scalar(@words);
my $c = 0;
unlink $ARGV[0];
$db = dbInterface->new($ARGV[0], "Dimensions", 1);
if(!$db)
{
    print STDERR "Unable to create dbInterface object.\n";
    exit;
}
foreach $word (@words)
{
    if(defined $opt_cutoff && &_tfidf($word) > $opt_cutoff)
    {
	delete $wordTF{$word};
	delete $wordDF{$word};
	next;
    }
    $wordIndex{$word} = $c;
    print STDERR "Unable to setValue for $word\n" if(!$db->setValue($word, "$c $wordTF{$word} $wordDF{$word}"));
    print STDERR "\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b";
    printf STDERR "%6d of %6d done.", $c, $final;
    $c++;
}
print STDERR "\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b";
printf STDERR "%6d of %6d done.", $c, $final;
$db->finalize();
print STDERR "\n";

# Write out the document count...
print STDERR "Writing the document count... ";
$db = dbInterface->new($ARGV[0], "DocumentCount", 1);
if(!$db)
{
    print STDERR "Unable to create dbInterface object.\n";
    exit;
}
print STDERR "Unable to setValue for $documentCount\n" if(!$db->setValue($documentCount, $documentCount));
$db->finalize();
print STDERR "done.\n";

# Writing out the Word Vectors to the database...
print STDERR "Writing word vectors...                       ";
$final = scalar(keys(%wordMatrix));
$c = 0;
$db = dbInterface->new($ARGV[0], "Vectors", 1);
if(!$db)
{
    print STDERR "Unable to create dbInterface object.\n";
    exit;
}
foreach $word (sort {$rows{$b} <=> $rows{$a}} keys %wordMatrix)
{
    my $key;
    my $value;
    
    next if(defined $opt_rhigh && $opt_rhigh < $rows{$word});
    last if(defined $opt_rlow && $opt_rlow > $rows{$word});
    $value = "";
    foreach $key (keys %{$wordMatrix{$word}})
    {
        if(defined $wordIndex{$key})
        {
	    $value .= "$wordIndex{$key} ".($wordMatrix{$word}{$key})." ";
	}
    }
    $value =~ s/\s+$//;
    print STDERR "Unable to setValue for $word\n" if(!$db->setValue($word, $value));
    print STDERR "\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b";
    printf STDERR "%6d of %6d done.", $c, $final;
    $c++;
}
print STDERR "\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b";
printf STDERR "%6d of %6d done.", $c, $final;
$db->finalize();
print STDERR "\n";

# ----------------- Subroutines Start Here ----------------------

# Form all possible compounds within a sentence
sub compoundify
{
    my $block;
    my $string;
    my $done;
    my $temp;
    my $firstPointer;
    my $secondPointer;
    my @wordsArray;
    
    # get the block of text
    $block = shift;
    
    # get all the words into an array
    @wordsArray = ();
    while ($block =~ /(\w+)/g)
    {
	push @wordsArray, $1;
    }
    
    # now compoundify, GREEDILY!!
    $firstPointer = 0;
    $string = "";
    
    while($firstPointer <= $#wordsArray)
    {
	$secondPointer = $#wordsArray;
	$done = 0;
	while($secondPointer > $firstPointer && !$done)
	{
	    $temp = join ("_", @wordsArray[$firstPointer..$secondPointer]);
	    if(exists $compounds{$temp})
	    {
		$string .= "$temp "; 
		$done = 1;
	    }
	    else 
	    { 
		$secondPointer--; 
	    }
	}
	if(!$done) 
	{ 
	    $string .= "$wordsArray[$firstPointer] "; 
	}
	$firstPointer = $secondPointer + 1;
    }
    $string =~ s/ $//;
    
    return $string;    
}

# Subroutine to stem a list of words...
# INPUT PARAMS  : @words        .. list of words.
# RETURN VALUES : @stemmedWords .. Stemmed list.
sub _stem
{
    my $word;
    my @words = @_;
    my @stemmedWords = ();

    foreach $word (@words)
    {
	my @wnForms = $wn->validForms($word);
	my @tmp = @wnForms;
	my $tp;
	if($#wnForms > 0)
	{
	    @wnForms = ();
	    foreach $tp (@tmp)
	    {
		push(@wnForms, $tp) if($tp =~ /\#n$/);
	    }
	}
	$word = $wnForms[0] if($#wnForms == 0);
	$word =~ s/\#.*//;
	push @stemmedWords, $word;
    }

    return @stemmedWords;
}

# Subroutine to remove stop words...
# INPUT PARAMS  : @words        .. list of words.
# RETURN VALUES : @cleanWords .. clean list.
sub _removeStopWords
{
    my $word;
    my $prt;
    my @words = @_;
    my @comp;
    my @cleanWords = ();

    foreach $word (@words)
    {
	@comp = split(/_+/, $word);
	foreach $prt (@comp)
	{
	    if(!$stopWords{$prt})
	    {
		push @cleanWords, $word;
		last;
	    }
	}
    }

    return @cleanWords;
}

# Subroutine to filter words with information content below
# a certain cutoff...
sub _tfidf
{
    my $word = shift;
    if(defined $wordTF{$word} && defined $wordDF{$word} && $wordDF{$word} > 0)
    {
	return 0 if(!defined $documentCount || $documentCount < 1);
	return $wordTF{$word}*log($documentCount/$wordDF{$word});
    }
    return 0;
}

# Subroutine to print detailed help
sub printHelp
{
    &printUsage();
    print "\nThis program writes out word vectors computed from WordNet glosses in\n";
    print "a BerkeleyDB database (Hash) specified by filename DBFILE.\n";
    print "Options: \n";
    print "--compfile       Option specifying the the list of compounds present\n";
    print "                 in WordNet in the file COMPOUNDS. This list is used\n";
    print "                 for compound detection.\n";
    print "--stopfile       Option specifying a list of stopwords to not be\n";
    print "                 considered while counting.\n";
    print "--wnpath         WNPATH specifies the path of the WordNet data files.\n";
    print "                 Ordinarily, this path is determined from the \$WNHOME\n";
    print "                 environment variable. But this option overides this\n";
    print "                 behavior.\n";
    print "--noexamples     Removes examples from the glosses before processing.\n";
    print "--cutoff         Option used to restrict the dimensions of the word\n";
    print "                 vectors with an tf/idf cutoff. VALUE is the cutoff\n";
    print "                 above which is an acceptable tf/idf value of a word.\n";
    print "--rhigh          RHIGH is the upper frequency cutoff of the words\n";
    print "                 selected to have a word-vector entry in the database.\n";
    print "--rlow           RLOW is the lower frequency cutoff of the words\n";
    print "                 selected to have a word-vector entry in the database.\n";
    print "--chigh          CHIGH is the upper frequency cutoff of words that form\n";
    print "                 the dimensions of the word-vectors.\n";
    print "--clow           CLOW is the lower frequency cutoff of words that form\n";
    print "                 the dimensions of the word-vectors.\n";
    print "--help           Displays this help screen.\n";
    print "--version        Displays version information.\n\n";
}

# Subroutine to print minimal usage notes
sub minimalUsageNotes
{
    &printUsage();
    print "Type wordVectors.pl --help for detailed help.\n";
}

# Subroutine that prints the usage
sub printUsage
{
    print "Usage: wordVectors.pl [{ [--compfile COMPOUNDS] [--stopfile STOPLIST] [--wnpath WNPATH]";
    print " [--noexamples] [--cutoff VALUE] [--rhigh RHIGH] [--rlow RLOW] [--chigh CHIGH] [--clow CLOW] DBFILE\n";
    print "                      | --help \n";
    print "                      | --version }]\n";
}

# Subroutine to print the version information
sub printVersion
{
    print "wordVectors.pl version 0.06\n";
    print "Copyright (c) 2003 Siddharth Patwardhan & Ted Pedersen.\n";
}
