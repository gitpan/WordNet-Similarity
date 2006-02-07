# get_wn_info.pm version 1.01
# (Last updated $Id: get_wn_info.pm,v 1.10 2005/12/11 22:37:02 sidz1979 Exp $)
#
# Package used by WordNet::Similarity::lesk module that
# computes semantic relatedness of word senses in WordNet
# using gloss overlaps.
#
# Copyright (c) 2005,
#
# Ted Pedersen, University of Minnesota, Duluth
# tpederse at d.umn.edu
#
# Satanjeev Banerjee, Carnegie Mellon University, Pittsburgh
# banerjee+ at cs.cmu.edu
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

package get_wn_info;

use stem;
use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

@ISA = qw(Exporter);

%EXPORT_TAGS = ();

@EXPORT_OK = ();

@EXPORT = ();

$VERSION = '1.01';

# function to set up the wordnet object and the various boundary indices
sub new
{
    my $className;
    my $self = {};
    my $wn;
    my $stemmingReqd;
    my $stemmer;

    # get the class name
    $className = shift;

    # get wordnet object
    $wn = shift;
    $self->{'wn'} = $wn;

    # check WordNet::QueryData version
    $wn->VERSION(1.39);

    # check if stemming called for 
    $stemmingReqd = shift;
    $self->{'stem'} = $stemmingReqd;


    if($stemmingReqd)
    {
	$stemmer = stem->new($wn);
	$self->{'stemmer'} = $stemmer;
    }

    # set up various boundaries.
    $self->{'glosBoundaryIndex'} = 0;
    $self->{'exampleBoundaryIndex'} = 0;
    $self->{'synonymBoundaryIndex'} = 0;
    bless($self, $className);

    return $self;
}

# NOTE: Thanks to Wybo Wiersma for contributing optimizations
#       in the following code.

# function to take a set of synsets and to return their
# hypernyms. both input and output will be arrays of fully qualified
# WordNet senses (in WORD#POS#SENSE format).
sub hype
{
    my $self = shift;
    my $wn = $self->{'wn'};
    my ($synsetsh, $outprep) = @_;

    # check if this is a request for the input-output types of this
    # function
    return(1, 1) if(defined($outprep));

    my %newsynsetsh;
    foreach my $syns (keys %{$synsetsh})
    {
	# check if in word-pos-sense format
        # TODO: Return error code instead of "exit"
	if($syns !~ /\#\w\#\d+/)
	{
	    print STDERR "$syns is not in WORD\#POS\#SENSE format!\n";
	    exit;
	}
	
	# get the hypernyms
	my @hypernyms = $wn->querySense($syns, "hypes");
	
	# put the hypernyms in a hash. this way we will avoid multiple
	# copies of the same hypernym
	my $temp;
	foreach $temp (@hypernyms)
	{
	    $newsynsetsh{$temp} = 1;
	}
    }
    
    # return the hypernyms in an hash ref 
    return(\%newsynsetsh);
}

# function to take a set of synsets and to return their
# hyponyms. both input and output will be arrays of fully qualified
# WordNet senses (in WORD#POS#SENSE format).
sub hypo
{
    my $self = shift;
    my $wn = $self->{'wn'};
    my ($synsetsh, $outprep) = @_;
    
    # check if this is a request for the input-output types of this
    # function
    return(1, 1) if(defined($outprep));
    
    my %hyponymHash;
    foreach my $syns (keys %{$synsetsh})
    {
	# check if in word-pos-sense format
        # TODO: Replace error message and exit with return error code.
	if($syns !~ /\#\w\#\d+/)
	{
	    print STDERR "$syns is not in WORD\#POS\#SENSE format!\n";
	    exit;
	}
	
	# get the hyponyms
	my @hyponyms = $wn->querySense($syns, "hypos");
	
	# put the hyponyms in a hash. this way we will avoid multiple
	# copies of the same hyponym
	my $temp;
	foreach $temp (@hyponyms)
	{
	    $hyponymHash{$temp} = 1;
	}
    }
    
    # return the hyponyms in an hash ref
    return(\%hyponymHash);
}

# function to take a set of synsets and to return their
# holonyms. both input and output will be arrays of fully qualified
# WordNet senses (in WORD#POS#SENSE format).
sub holo
{
    my $self = shift;
    my $wn = $self->{'wn'};
    my ($synsetsh, $outprep) = @_;
    my %holonymHash = ();
    
    # check if this is a request for the input-output types of this
    # function
    return(1, 1) if(defined($outprep));

    foreach my $syns (keys %{$synsetsh})
    {
	# check if in word-pos-sense format
        # TODO: Replace error message and exit with return error code.
	if($syns !~ /\#\w\#\d+/)
	{
	    print STDERR "$syns is not in WORD\#POS\#SENSE format!\n";
	    exit;
	}
	
	# get the holonyms
	my @holonyms = $wn->querySense($syns, "holo");
	
	# put the holonyms in a hash. this way we will avoid multiple
        # copies of the same holonym
	my $temp;
	foreach $temp (@holonyms)
	{
	    $holonymHash{$temp} = 1;
	}
    }
    
    # return the holonyms in an hash ref 
    return(\%holonymHash);
}

# function to take a set of synsets and to return their
# meronyms. both input and output will be arrays of fully qualified
# WordNet senses (in WORD#POS#SENSE format).
sub mero
{
    my $self = shift;
    my $wn = $self->{'wn'};
    my ($synsetsh, $outprep) = @_;
    my %meronymHash = ();
    
    # check if this is a request for the input-output types of this
    # function
    return (1, 1) if(defined($outprep));
    
    foreach my $syns (keys %{$synsetsh})
    {
	# check if in word-pos-sense format
        # TODO: Replace error message and exit with return error code.
	if($syns !~ /\#\w\#\d+/)
	{
	    print STDERR "$syns is not in WORD\#POS\#SENSE format!\n";
	    exit;
	}
	
	# get the meronyms
	my @meronyms = $wn->querySense($syns, "mero");
	
	# put the meronyms in a hash. this way we will avoid multiple
	# copies of the same meronym
	my $temp;
	foreach $temp (@meronyms)
	{
	    $meronymHash{$temp} = 1;
	}
    }
    
    # return the meronyms in an hash ref 
    return(\%meronymHash);
}

# function to take a set of synsets and to return their
# attributes. both input and output will be arrays of fully qualified
# WordNet senses (in WORD#POS#SENSE format).
sub attr
{
    my $self = shift;
    my $wn = $self->{'wn'};
    my ($synsetsh, $outprep) = @_;
    my %attrHash = ();
    
    # check if this is a request for the input-output types of this
    # function
    return (1, 1) if(defined($outprep));
    
    foreach my $syns (keys %{$synsetsh})
    {
	# check if in word-pos-sense format
	if($syns !~ /\#\w\#\d+/)
	{
	    print STDERR "$syns is not in WORD\#POS\#SENSE format!\n";
	    exit;
	}
	
	# get the attrs
	my @attrs = $wn->querySense($syns, "attr");
	
	# put the attrs in a hash. this way we will avoid multiple
	# copies of the same attr
	my $temp;
	foreach $temp (@attrs)
	{
	    $attrHash{$temp} = 1;
	}
    }
    
    # return the attrs in an hash ref 
    return(\%attrHash);
}

# function to take a set of synsets and to return their also-see
# synsets. both input and output will be arrays of fully qualified
# WordNet senses (in WORD#POS#SENSE format).
sub also
{
    my $self = shift;
    my $wn = $self->{'wn'};
    my ($synsetsh, $outprep) = @_;
    my %alsoSeeHash = ();
    
    # check if this is a request for the input-output types of this
    # function
    return (1, 1) if(defined($outprep));

    foreach my $syns (keys %{$synsetsh})
    {
	# check if in word-pos-sense format
	if($syns !~ /\#\w\#\d+/)
	{
	    print STDERR "$syns is not in WORD\#POS\#SENSE format!\n";
	    exit;
	}
	
	# get the also see synsets 
	my @alsoSees = $wn->queryWord($syns, "also");
	
	# put the synsets in a hash. this way we will avoid multiple
	# copies of the same synset
	my $temp;
	foreach $temp (@alsoSees)
	{
	    $alsoSeeHash{$temp} = 1;
	}
    }
    
    # return the synsets in an hash ref 
    return(\%alsoSeeHash);
}

# function to take a set of words and to return their derived forms. 
# both input and output will be arrays of fully qualified
# WordNet senses (in WORD#POS#SENSE format).
sub deri
{
    my $self = shift;
    my $wn = $self->{wn};
    my ($wordsh, $outprep) = @_;
    my %deriHash = ();

    return (1, 1) if(defined($outprep));

    foreach my $word (keys %{$wordsh}) 
    {
        # TODO: Replace error message and exit with return error code.
	if($word !~ m/\#\w+\#\d+/) 
        {
	    print STDERR "$word is not in WORD#POS#SENSE format!\n";
	    exit 1;
	}
	my @deris = $wn->queryWord($word, "deri");

	foreach my $temp (@deris) 
        {
	    $deriHash{$temp} = 1;
	}
    }
    return(\%deriHash);
}

# function to take a set of synsets and to return their domain
# synsets. both input and output will be arrays of fully qualified
# WordNet senses (in WORD#POS#SENSE format).
sub domn
{
    my $self = shift;
    my $wn = $self->{wn};
    my ($wordsh, $outprep) = @_;
    my %domnHash = ();

    return(1, 1) if(defined($outprep));

    foreach my $word (keys %{$wordsh})
    {
        # TODO: Replace error message and exit with return error code.
	if($word !~ m/\#\w+\#\d+/)
        {
	    print STDERR "$word is not in WORD#POS#SENSE format!\n";
	    exit 1;
	}
	my @domns = $wn->queryWord($word, "domn");

	foreach my $temp (@domns) 
        {
	    $domnHash{$temp} = 1;
	}
    }
    return (\%domnHash);
}

# function to take a set of synsets and to return their domain term
# synsets. both input and output will be arrays of fully qualified
# WordNet senses (in WORD#POS#SENSE format).
sub domt
{
    my $self = shift;
    my $wn = $self->{wn};
    my ($wordsh, $outprep) = @_;
    my %domtHash = ();

    return (1, 1) if(defined($outprep));

    foreach my $word (keys %{$wordsh})
    {
        # TODO: Replace error message and exit with return error code.
	if($word != m/\#\w+\#\d+/)
        {
	    print STDERR "$word is not in WORD#POS#SENSE format!\n";
	    exit 1;
	}
	my @domts = $wn->queryWord ($word, "domt");

	foreach my $temp (@domts)
        {
	    $domtHash{$temp} = 1;
	}
    }
    return (\%domtHash);

}

# function to take a set of synsets and to return their similar-to
# synsets. both input and output will be arrays of fully qualified
# WordNet senses (in WORD#POS#SENSE format).
sub sim
{
    my $self = shift;
    my $wn = $self->{'wn'};
    my ($synsetsh, $outprep) = @_;
    my %simHash = ();
    
    # check if this is a request for the input-output types of this
    # function
    return (1, 1) if(defined($outprep));

    foreach my $syns (keys %{$synsetsh})
    {
	# check if in word-pos-sense format
        # TODO: Replace error message and exit with return error code.
	if($syns !~ /\#\w\#\d+/)
	{
	    print STDERR "$syns is not in WORD\#POS\#SENSE format!\n";
	    exit;
	}
	
	# get the sim synsets 
	my @sims = $wn->querySense($syns, "sim");
	
	# put the synsets in a hash. this way we will avoid multiple
	# copies of the same synset
	my $temp;
	foreach $temp (@sims)
	{
	    $simHash{$temp} = 1;
	}
    }
    
    # return the synsets in an hash ref 
    return(\%simHash);
}

# function to take a set of synsets and to return their entailment
# synsets. both input and output will be arrays of fully qualified
# WordNet senses (in WORD#POS#SENSE format).
sub enta
{
    my $self = shift;
    my $wn = $self->{'wn'};
    my ($synsetsh, $outprep) = @_;
    my %entailsHash = ();
    
    # check if this is a request for the input-output types of this
    # function
    return (1, 1) if(defined($outprep));

    foreach my $syns (keys %{$synsetsh})
    {
	# check if in word-pos-sense format
        # TODO: Replace error message and exit with return error code.
	if($syns !~ /\#\w\#\d+/)
	{
	    print STDERR "$syns is not in WORD\#POS\#SENSE format!\n";
	    exit;
	}
	
	# get the entails synsets
	my @entails = $wn->querySense($syns, "enta");
	
	# put the entails synsets in a hash. this way we will avoid
	# multiple copies of the same entails synset
	my $temp;
	foreach $temp (@entails)
	{
	    $entailsHash{$temp} = 1;
	}
    }
    
    # return the causs in an hash ref 
    return(\%entailsHash);
}

# function to take a set of synsets and to return their cause
# synsets. both input and output will be arrays of fully qualified
# WordNet senses (in WORD#POS#SENSE format).
sub caus
{
    my $self = shift;
    my $wn = $self->{'wn'};
    my ($synsetsh, $outprep) = @_;
    my %causeHash = ();
    
    # check if this is a request for the input-output types of this
    # function
    return(1, 1) if(defined($outprep));

    foreach my $syns (keys %{$synsetsh})
    {
	# check if in word-pos-sense format
        # TODO: Replace error message and exit with return error code.
	if($syns !~ /\#\w\#\d+/)
	{
	    print STDERR "$syns is not in WORD\#POS\#SENSE format!\n";
	    exit;
	}
	
	# get the cause synsets
	my @cause = $wn->querySense($syns, "caus");
	
	# put the cause synsets in a hash. this way we will avoid
	# multiple copies of the same cause synset
	my $temp;
	foreach $temp (@cause)
	{
	    $causeHash{$temp} = 1;
	}
    }
    
    # return the causs in an hash ref 
    return(\%causeHash);
}

# function to take a set of synsets and to return their participle
# synsets. both input and output will be arrays of fully qualified
# WordNet senses (in WORD#POS#SENSE format).
sub part
{
    my $self = shift;
    my $wn = $self->{'wn'};
    my ($synsetsh, $outprep) = @_;
    my %partHash = ();
    
    # check if this is a request for the input-output types of this
    # function
    return(1, 1) if(defined($outprep));

    foreach my $syns (keys %{$synsetsh})
    {
	# check if in word-pos-sense format
        # TODO: Replace error message and exit with return error code.
	if($syns !~ /\#\w\#\d+/)
	{
	    print STDERR "$syns is not in WORD\#POS\#SENSE format!\n";
	    exit;
	}
	
	# get the part synsets
	my @part = $wn->queryWord($syns, "part");
	
	# put the part synsets in a hash. this way we will avoid
	# multiple copies of the same part synset
	my $temp;
	foreach $temp (@part)
	{
	    $partHash{$temp} = 1;
	}
    }
    
    # return the causs in an hash ref 
    return(\%partHash);
}

# function to take a set of synsets and to return their pertainym
# synsets. both input and output will be arrays of fully qualified
# WordNet senses (in WORD#POS#SENSE format).
sub pert
{
    my $self = shift;
    my $wn = $self->{'wn'};
    my ($synsetsh, $outprep) = @_;
    my %pertHash = ();
    
    # check if this is a request for the input-output types of this
    # function
    return (1, 1) if(defined($outprep));

    foreach my $syns (keys %{$synsetsh})
    {
	# check if in word-pos-sense format
        # TODO: Replace error message and exit with return error code.
	if($syns !~ /\#\w\#\d+/)
	{
	    print STDERR "$syns is not in WORD\#POS\#SENSE format!\n";
	    exit;
	}
	
	# get the pert synsets
	my @pert = $wn->queryWord($syns, "pert");
	
	# put the pert synsets in a hash. this way we will avoid
	# multiple copies of the same pert synset
	my $temp;
	foreach $temp (@pert)
	{
	    $pertHash{$temp} = 1;
	}
    }
    
    # return the causs in an hash ref 
    return(\%pertHash);
}

# function to take a set of synsets and to return the concatenation of
# their glosses
sub glos
{
    my $self = shift;
    my $wn = $self->{'wn'};
    my $stemmer = $self->{'stemmer'};
    my ($synsetsh, $outprep) = @_;
    my $returnString = "";
    
    # check if this is a request for the input-output types of this
    # function
    return (1, 2) if(defined($outprep));

    my @synshkeys = keys %{$synsetsh};
    my $i = 0;
    foreach my $syns (@synshkeys)
    {
	# check if in word-pos-sense format
        # TODO: Replace error message and exit with return error code.
	if($syns !~ /\#\w\#\d+/)
	{
	    print STDERR "$syns is not in WORD\#POS\#SENSE format!\n";
	    exit;
	}
	
	# get the glos
	my $glosString;
	($glosString) = $wn->querySense($syns, "glos");
	
	# regularize the glos
	$glosString =~ s/\".*//;

	# get rid of most punctuation
	$glosString =~ tr/.;:,?!(){}\x22\x60\x24\x25\x40<>/ /;
	# get rid of apostrophes not surrounded by word chars
	$glosString =~ s/(?<!\w)\x27/ /g;
	$glosString =~ s/\x27(?!\w)/ /g;
	# remove dashes, but not hyphens
	$glosString =~ s/--/ /g;

	# this causes "plane's" to become "plane s"
	# $glosString =~ s/[^\w]/ /g;

	$glosString =~ s/\s+/ /g;
	$glosString = lc $glosString;

	# stem the glos if asked for 
	$glosString = $stemmer->stemString($glosString, 1) if($self->{stem});
	
	$glosString =~ s/^\s*/ /;
	$glosString =~ s/\s*$/ /;
	
	# append to return string
	$returnString .= $glosString;
	
	# put in boundary if more glosses coming!
	if($i < $#synshkeys) 
	{ 
	    my $boundary = sprintf("GGG%05dGGG", $self->{'glosBoundaryIndex'});
	    $returnString .= $boundary;
	    ($self->{'glosBoundaryIndex'})++;
	}
        $i++;
    }
    
    # and we are done!
    return($returnString);
}

# function to take a set of synsets and to return the concatenation of
# their example strings
sub example
{
    my $self = shift;
    my $wn = $self->{'wn'};
    my $stemmer = $self->{'stemmer'};    
    my ($synsetsh, $outprep) = @_;
    my @exampleStrings = ();
    
    # check if this is a request for the input-output types of this
    # function
    return (1, 2) if(defined($outprep));

    # first get all the example strings into an array
    foreach my $syns (keys %{$synsetsh})
    {
	# check if in word-pos-sense format
        # TODO: Replace error message and exit with return error code.
	if($syns !~ /\#\w\#\d+/)
	{
	    print STDERR "$syns is not in WORD\#POS\#SENSE format!\n";
	    exit;
	}
	
	# get the glos
	my $exampleString;
	($exampleString) = $wn->querySense($syns, "glos");
	
	# check if this has any examples
	if($exampleString !~ /\"/) {next;}
	
	while($exampleString =~ /\"([^\"]*)\"/g)
	{
	    push @exampleStrings, $1;
	}
    }

    # now put the example strings together to form the return
    # string. separate examples with the example boundary
    
    my $returnString = "";
    my $i;
    for ($i = 0; $i <= $#exampleStrings; $i++)
    {
	# preprocess

	###
	# get rid of most punctuation
	$exampleStrings[$i] =~ tr/.;:,?!(){}\x22\x60\x24\x25\x40<>/ /;
	# get rid of apostrophes not surrounded by word chars
	$exampleStrings[$i] =~ s/(?<!\w)\x27/ /g;
	$exampleStrings[$i] =~ s/\x27(?!\w)/ /g;
	# remove dashes, but not hyphens
	$exampleStrings[$i] =~ s/--/ /g;
	###$exampleStrings[$i] =~ s/[^\w]/ /g;

	$exampleStrings[$i] =~ s/\s+/ /g;
	$exampleStrings[$i] =~ s/^\s*/ /;
	$exampleStrings[$i] =~ s/\s*$/ /;
	
	$exampleStrings[$i] = lc($exampleStrings[$i]);
	
	# stem if so required
	$exampleStrings[$i] = $stemmer->stemString($exampleStrings[$i], 1)
	    if($self->{'stem'});
	
	$exampleStrings[$i] =~ s/^\s*/ /;
	$exampleStrings[$i] =~ s/\s*$/ /;
	
	# append to $returnString
	$returnString .= $exampleStrings[$i];
		
	# put in boundary if more examples coming!
	if($i < $#exampleStrings)
	{ 
	    my $boundary = sprintf("EEE%05dEEE", $self->{'exampleBoundaryIndex'});
	    $returnString .= $boundary;
	    ($self->{'exampleBoundaryIndex'})++;
	}
    }
    
    # and we are done!
    return($returnString);
}

# function to take a set of synsets and to return the concatenation of
# all the words in them. repeated words are returned only once. 
sub syns
{
    my $self = shift;
    my $wn = $self->{'wn'};
    my ($synsetsh, $outprep) = @_;
    my $returnString = "";
    
    # check if this is a request for the input-output types of this
    # function
    return (1, 2) if(defined($outprep));

    my %synonymHash = ();
    foreach my $syns (keys %{$synsetsh})
    {
	# check if in word-pos-sense format
        # TODO: Replace error message and exit with return error code.
	if($syns !~ /\#\w\#\d+/)
	{
	    print STDERR "$syns is not in WORD\#POS\#SENSE format!\n";
	    exit;
	}
	
	# get the words
	my @synsetWords = $wn->querySense($syns, "syns");
	
	# for each word, remove the POS and SENSE, and put only the
	# word in a hash
	my $temp;
	foreach $temp (@synsetWords)
	{
	    $temp =~ s/\#.*//;
	    $synonymHash{$temp} = 1;
	}
    }
    
    # now get hold of all the words in sorted order
    my @synonymArray = sort keys %synonymHash;
    
    # concatenate them, using the synonym boundary
    for(my $i = 0; $i <= $#synonymArray; $i++)
    {
	$synonymArray[$i] =~ s/ /_/g;
	$returnString .= " $synonymArray[$i] ";
	
	# put in boundary if more examples coming!
	if($i < $#synonymArray) 
	{ 
	    my $boundary = sprintf("SSS%05dSSS", $self->{synonymBoundaryIndex});
	    $returnString .= $boundary;
	    ($self->{synonymBoundaryIndex})++;
	}
    }
    
    # and we are done!
    return($returnString);
}

# function to take a set of synsets and to return the concatenation of
# their glosses (including the examples)
sub glosexample
{
    my $self = shift;
    my $wn = $self->{wn};
    my $stemmer = $self->{stemmer};
    my ($synsetsh, $outprep) = @_;
    my $returnString = "";
    
    # check if this is a request for the input-output types of this
    # function
    return (1, 2) if(defined($outprep));

    my @synshkeys = keys %{$synsetsh};
    for(my $i = 0; $i < scalar(@synshkeys); $i++)
    {
	# check if in word-pos-sense format
        # TODO: Replace error message and exit with return error code.
	if($synshkeys[$i] !~ /\#\w\#\d+/)
	{
	    print STDERR "$synshkeys[$i] is not in WORD\#POS\#SENSE format!\n";
	    exit;
	}
	
	# get the glos
	my $glosString;
	($glosString) = $wn->querySense($synshkeys[$i], "glos");
	
	# regularize the glos
	###$glosString =~ s/\'//g;
	###$glosString =~ s/[^\w]/ /g;

	# get rid of most punctuation
	$glosString =~ tr/.;:,?!(){}\x22\x60\x24\x25\x40<>/ /;
	# get rid of apostrophes not surrounded by word chars
	$glosString =~ s/(?<!\w)\x27/ /g;
	$glosString =~ s/\x27(?!\w)/ /g;
	# remove dashes, but not hyphens
	$glosString =~ s/--/ /g;
	###

	$glosString =~ s/\s+/ /g;
	$glosString = lc $glosString;

	# stem the glos if asked for 
	$glosString = $stemmer->stemString($glosString, 1) if($self->{stem});
	
	$glosString =~ s/^\s*/ /;
	$glosString =~ s/\s*$/ /;
	
	# append to return string
	$returnString .= $glosString;
	
	# put in boundary if more glosses coming!
	if($i < $#synshkeys) 
	{ 
	    my $boundary = sprintf("XXX%05dXXX", $self->{glosBoundaryIndex});
	    $returnString .= $boundary;
	    ($self->{glosBoundaryIndex})++;
	}
    }
    
    # and we are done!
    return($returnString);
}

1;
