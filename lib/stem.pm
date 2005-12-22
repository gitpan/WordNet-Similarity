# stem.pm version 1.01
# (Last updated $Id: stem.pm,v 1.6 2005/12/11 22:37:02 sidz1979 Exp $)
#
# Package used by WordNet::Similarity::lesk module that
# computes semantic relatedness of word senses in WordNet
# using gloss overlaps.
#
# Copyright (c) 2005,
#
# Ted Pedersen, University of Minnesota Duluth
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

package stem;

use strict;

use Exporter;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

@ISA = qw(Exporter);

%EXPORT_TAGS = ();

@EXPORT_OK = ();

@EXPORT = ();

$VERSION = '1.01';

# function to set up the wordnet object.
sub new
{
    my $className = shift;
    my $wn = shift;
    my $self = {};

    $self->{wn} = $wn;
    $self->{wordStemHash} = ();
    $self->{stringStemHash} = ();
    bless($self, $className);

    return $self;
}

# Function to take a string, and process it in such a way that all the
# words in it get stemmed. Note that if a single word has two or more
# possible stems, we return the original surface form since there is
# no way to select from the competing stems. The stem of the string
# can be cached if requested. Useful if the calling function knows
# which strings it will have to stem over and over again. Strings that
# will be only stemmed ones need not be cached - thereby saving space.

sub stemString
{
    my $self = shift;
    my $inputString = shift;
    my $cache = shift;
    
    # whether or not this string has been requested for cacheing,
    # check in the cache
    return $self->{'stringStemHash'}->{$inputString} if (defined $self->{'stringStemHash'}->{$inputString});
    
    # Not in cache. Stem.
    
    # for each word in the input get the stem and put in the output string
    my $outputString = "";
    while ($inputString =~ /(\w+)/g)
    {
	my $word = $1;
	my @stems = $self->stemWord($word);
	
	# if multiple or no stems, use surface form.
	$outputString .= ($#stems != 0) ? "$word " : "$stems[0] ";
    }
    
    # if cache required, do so
    $self->{'stringStemHash'}->{$inputString} = $outputString if (defined($cache));
    
    # return the string
    return($outputString);
}

# stem the word passed to this function and return an array of words
# that contain all the possible stems of this word. All possible stems
# of the word may include the surface form too if its a valid WordNet
# lemma.

sub stemWord
{
    my $self = shift;
    my $word = shift;
    my $wn = $self->{wn};
    my @stems = ();
    
    # if not in the cache, create and put in cache
    if (!defined $self->{wordStemHash}->{$word})
    {
	# So not in the hash. gotta check for all possible parts of speech.
	my %stems = ();
	my $possiblePartsOfSpeech = "nvar";
	
	my $pos;
	while ("nvar" =~ /(.)/g)
	{
	    foreach ($wn->validForms("$word\#$1"))
	    {
		# put underscore for space
		$_ =~ s/ /_/g;
		
		# remove part of speech if any
		$_ =~ s/\#\w$//;
		
		# put in stems hash (the hash allows us to not worry about
		# multiple copies of the same stem!)
		$stems{$_} = 1;
	    }
	}
	
	# put in the cache
	$self->{wordStemHash}->{$word} = join(" ", (keys %stems));
    }
    
    # return the stems
    return (split / /, $self->{wordStemHash}->{$word});
}

1;

