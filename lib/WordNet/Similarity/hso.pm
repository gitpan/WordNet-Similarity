# WordNet::Similarity::hso.pm version 2.04
# (Last updated $Id: hso.pm,v 1.16 2008/03/27 06:21:17 sidz1979 Exp $)
#
# Semantic Similarity Measure package implementing the measure
# described by Hirst and St-Onge (1998).
#
# Copyright (c) 2005,
#
# Ted Pedersen, University of Minnesota Duluth
# tpederse at d.umn.edu
#
# Siddharth Patwardhan, University of Utah, Salt Lake City
# sidd at cs.utah.edu
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

package WordNet::Similarity::hso;

=head1 NAME

WordNet::Similarity::hso - Perl module for computing semantic relatedness
of word senses using the method described by Hirst and St-Onge (1998).

=head1 SYNOPSIS

  use WordNet::Similarity::hso;

  use WordNet::QueryData;

  my $wn = WordNet::QueryData->new();

  my $object = WordNet::Similarity::hso->new($wn);

  my $value = $object->getRelatedness("car#n#1", "bus#n#2");

  ($error, $errorString) = $object->getError();

  die "$errorString\n" if($error);

  print "car (sense 1) <-> bus (sense 2) = $value\n";

=head1 DESCRIPTION

This module computes the semantic relatedness of word senses according to
the method described by Hirst and St-Onge (1998). In their paper they
describe a method to identify 'lexical chains' in text. They measure the
semantic relatedness of words in text to identify the links of the lexical
chains. This measure of relatedness has been implemented in this module.

=head2 Methods

=over

=cut

use strict;

use Exporter;
use WordNet::Similarity;

use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

@ISA = qw/WordNet::Similarity/;

%EXPORT_TAGS = ();

@EXPORT_OK = ();

@EXPORT = ();

our $VERSION = '2.04';

=item $hso->setPosList()

This method is internally called to determine the parts of speech
this measure is capable of dealing with.

Parameters: none.

Returns: none.

=cut

sub setPosList
{
  my $self = shift;
  $self->{n} = 1;
  $self->{v} = 1;
  $self->{a} = 1;
  $self->{r} = 1;
}

# How medium strong relations work (from an e-mail by Sid):
# Basically, for the
# medium strong relations, I had to start from the given node and explore
# all "legal" paths starting from that node and ending on $offset2.

# To do this I created a recursive function _medStrong, that is called like
# so in line 247:

#  my $score = $self->_medStrong(0, 0, 0, $offset1, $offset1, $offset2);

# The first parameter is the "state" (=0 initially). This parameter keeps
# track of what part of the path we are on. For example, one of the legal
# paths goes upwards, then horizontally, and then downwards. So along the
# upwards section of the path, "state" would be 0. Along the horizontal
# section of the path, the "state" becomes 1. Along the downwards section
# the "state" is 2. Similarly, the state recognizes different legal paths.

# The second parameter is "distance" (=0 initially). This parameter keeps
# track of the length of the path that we are at. Since the maximum length
# possible is 5, we stop the recursive function when the path length reaches
# 5.

# The third parameter is "chdir" (=0 initally) counts the number of changes
# in direction. This value is required in the formula for the medium-strong
# relation, so is updated everytime there is a change in path direction.

# The fourth parameter is "from node" (=offset1 initally). The recursive
# function uses the from node to decide which are the next possible nodes in
# a given path. Each of these are then explored creating n recursive copies.

# The fifth parameter is "path". It is  a string of the form

#  "$offset [DUH] $offset [DUH] $offset..."

# that stores a string representation of the path. This string is used in
# the traces (if the path turns out to be a legal path). A path would turn
# out to be a legal path if it is generated by our recursive function and
# the first and last nodes in the path are $offset1 and $offset2 of the
# relatedness measure.

# The sixth parameter to the function is "endOffset". This is basically
# "$offset2" throughout and is used by the recursive function to determine
# if the current node in the path is the last node of that path.

# The basic idea of the recursive function is at each stage, to determine
# the next possible nodes in the path, from the current node and state. Then
# _medStrong is called on each of these. The recursive function does a
# search through a tree of "partially" legal paths, until a completely legal
# path is found. Multiple such paths may be found. The highest of the scores
# of these is returned.

# _medStrong returns the maximum length of a legal path that was found in a
# given subtree of the recursive search. These return values are used by
# _medStrong and the highest of these is returned.


=item $hso->getRelatedness ($synset1, $synset2)

Computes the relatedness of two word senses using the method of Hirst &
St-Onge.

Parameters: two word senses in "word#pos#sense" format.

Returns: Unless a problem occurs, the return value is the relatedness
score, which is greater-than or equal-to 0 and less-than or equal-to 16.
If an error occurs, then the error level is set to non-zero and an error
string is created (see the description of getError()).

=cut

sub getRelatedness
{
  my $self = shift;
  my $class = ref $self || $self;
  my $wps1 = shift;
  my $wps2 = shift;
  my $wn = $self->{wn};

  # Check the existence of the WordNet::QueryData object.
  if(!$wn) {
    $self->{errorString} .= "\nError (${class}::getRelatedness()) - ";
    $self->{errorString} .= "A WordNet::QueryData object is required.";
    $self->{error} = 2;
    return undef;
  }

  # Initialize traces.
  $self->{traceString} = "";

  # Undefined input cannot go unpunished.
  if(!$wps1 || !$wps2) {
    $self->{errorString} .= "\nWarning (${class}::getRelatedness()) - ";
    $self->{errorString} .= "Undefined input values.";
    $self->{error} = ($self->{error} < 1) ? 1 : $self->{error};
    return undef;
  }

  # Security check -- are the input strings in the correct format (word#pos#sense).
  my ($pos1, $pos2);
  my ($word1, $word2);
  if($wps1 =~ /^(\S+)\#([nvar])\#\d+$/) {
    $word1 = $1;
    $pos1 = $2;
  }
  else {
    $self->{errorString} .= "\nWarning (${class}::getRelatedness()) - ";
    $self->{errorString} .= "Input not in word\#pos\#sense format.";
    $self->{error} = ($self->{error} < 1) ? 1 : $self->{error};
    return undef;
  }
  if($wps2 =~ /^(\S+)\#([nvar])\#\d+$/) {
    $word2 = $1;
    $pos2 = $2;
  }
  else {
    $self->{errorString} .= "\nWarning (${class}::getRelatedness()) - ";
    $self->{errorString} .= "Input not in word\#pos\#sense format.";
    $self->{error} = ($self->{error} < 1) ? 1 : $self->{error};
    return undef;
  }

  # Which parts of speech do we have.
  if($pos1 !~ /[nvar]/ || $pos2 !~ /[nvar]/) {
    $self->{errorString} .= "\nWarning (${class}::getRelatedness()) - ";
    $self->{errorString} .= "Unknown part(s) of speech.";
    $self->{error} = ($self->{error} < 1) ? 1 : $self->{error};
    return 0;
  }

  # Now check if the similarity value for these two synsets is in
  # fact in the cache... if so return the cached value.
  my $relatedness =
    $self->{doCache} ? $self->fetchFromCache ($wps1, $wps2) : undef;
  defined $relatedness and return $relatedness;

  # Now get down to really finding the relatedness of these two.
  my $offset1 = $wn->offset($wps1);
  my $offset2 = $wn->offset($wps2);

  if(!$offset1 || !$offset2) {
    $self->{errorString} .= "\nWarning (${class}::getRelatedness()) - ";
    $self->{errorString} .= "Input senses not found in WordNet.";
    $self->{error} = ($self->{error} < 1) ? 1 : $self->{error};
    return undef;
  }

  $offset1 = $offset1.$pos1;
  $offset2 = $offset2.$pos2;

  if($offset1 eq $offset2) {
    # [trace]
    if($self->{trace}) {
      $self->{'traceString'} .= "Strong Rel (Synset Match) : ";
      $self->printSet($pos1, 'offset', $offset1);
      $self->{'traceString'} .= "\n\n";
    }
    # [/trace]

    $self->{doCache} and $self->storeToCache ($wps1, $wps2, 16);
    return 16;
  }

  my @horiz1 = &_getHorizontalOffsetsPOS($self->{wn}, $offset1);
  my @upward1 = &_getUpwardOffsetsPOS($self->{wn}, $offset1);
  my @downward1 = &_getDownwardOffsetsPOS($self->{wn}, $offset1);
  my @horiz2 = &_getHorizontalOffsetsPOS($self->{wn}, $offset2);
  my @upward2 = &_getUpwardOffsetsPOS($self->{wn}, $offset2);
  my @downward2 = &_getDownwardOffsetsPOS($self->{wn}, $offset2);

  # [trace]
  if($self->{trace}) {
    $self->{traceString} .= "Horizontal Links of ";
    $self->printSet($pos1, 'offset', $offset1);
    $self->{traceString} .= ": ";
    $self->printSet($pos1, 'offset', @horiz1);
    $self->{traceString} .= "\nUpward Links of ";
    $self->printSet($pos1, 'offset', $offset1);
    $self->{traceString} .= ": ";
    $self->printSet($pos1, 'offset', @upward1);
    $self->{traceString} .= "\nDownward Links of ";
    $self->printSet($pos1, 'offset', $offset1);
    $self->{traceString} .= ": ";
    $self->printSet($pos1, 'offset', @downward1);
    $self->{traceString} .= "\nHorizontal Links of ";
    $self->printSet($pos2, 'offset', $offset2);
    $self->{traceString} .= ": ";
    $self->printSet($pos2, 'offset', @horiz2);
    $self->{traceString} .= "\nUpward Links of ";
    $self->printSet($pos2, 'offset', $offset2);
    $self->{traceString} .= ": ";
    $self->printSet($pos2, 'offset', @upward2);
    $self->{traceString} .= "\nDownward Links of ";
    $self->printSet($pos2, 'offset', $offset2);
    $self->{traceString} .= ": ";
    $self->printSet($pos2, 'offset', @downward2);
    $self->{traceString} .= "\n\n";
  }
  # [/trace]

  if(&_isIn($offset1, @horiz2) || &_isIn($offset2, @horiz1)) {
    # [trace]
    if($self->{trace}) {
      $self->{traceString} .= "Strong Rel (Horizontal Match) : \n";
      $self->{traceString} .= "Horizontal Links of ";
      $self->printSet($pos1, 'offset', $offset1);
      $self->{traceString} .= ": ";
      $self->printSet($pos1, 'offset', @horiz1);
      $self->{traceString} .= "\nHorizontal Links of ";
      $self->printSet($pos2, 'offset', $offset2);
      $self->{traceString} .= ": ";
      $self->printSet($pos2, 'offset', @horiz2);
      $self->{traceString} .= "\n\n";
    }
    # [/trace]

    $self->{doCache} and $self->storeToCache ($wps1, $wps2, 16);
    return 16;
  }

  if($word1 =~ /$word2/ || $word2 =~ /$word1/) {
    if(&_isIn($offset1, @upward2) || &_isIn($offset1, @downward2)) {
      # [trace]
      if($self->{trace}) {
	$self->{traceString} .= "Strong Rel (Compound Word Match) : \n";
	$self->{traceString} .= "All Links of $word1: ";
	$self->printSet($pos1, 'offset', @horiz1, @upward1, @downward1);
	$self->{traceString} .= "\nAll Links of $word2: ";
	$self->printSet($pos2, 'offset', @horiz2, @upward2, @downward2);
	$self->{traceString} .= "\n\n";
      }
      # [/trace]		

      $self->{doCache} and $self->storeToCache ($wps1, $wps2, 16);
      return 16;
    }

    if(&_isIn($offset2, @upward1) || &_isIn($offset2, @downward1)) {
      # [trace]
      if($self->{trace}) {
	$self->{traceString} .= "Strong Rel (Compound Word Match) : \n";
	$self->{traceString} .= "All Links of $word1: ";
	$self->printSet($pos1, 'offset', @horiz1, @upward1, @downward1);
	$self->{traceString} .= "\nAll Links of $word2: ";
	$self->printSet($pos2, 'offset', @horiz2, @upward2, @downward2);
	$self->{traceString} .= "\n\n";
      }
      # [/trace]		

      $self->{doCache} and $self->storeToCache ($wps1, $wps2, 16);
    }
  }

  # Conditions for Medium-Strong relations ...
  my $score = $self->_medStrong(0, 0, 0, $offset1, $offset1, $offset2);

  $self->{doCache} and $self->storeToCache ($wps1, $wps2, $score);
  return $score;
}

# Subroutine to get offsets(POS) of all horizontal links from a given
# word (offset(POS)). All horizontal links specified  are --
# Also See, Antonymy, Attribute, Pertinence, Similarity.
# INPUT PARAMS  : $wn      .. WordNet::QueryData object.
#                 $offset  .. An offset-pos (e.g. 637554v)
# RETURN VALUES : @offsets .. Array of offset-pos (e.g. 736438n)
sub _getHorizontalOffsetsPOS
{
    my $wn;
    my $offset;
    my $synset;
    my $pos;
    my $wordForm;
    my @partsOfSpeech;
    my @synsets;
    my @offsets;

    $wn = shift;
    $offset = shift;
    @offsets = ();
    if($offset =~ /^([0-9]+)([a-z])$/)
    {
	$offset = $1;
	$pos = $2;
    }
    else
    {
	return @offsets;
    }
    $wordForm = $wn->getSense($offset,$pos);
    @synsets = $wn->queryWord($wordForm, "also");
    push @synsets, $wn->queryWord($wordForm, "ants");
    push @synsets, $wn->querySense($wordForm, "attr");
    push @synsets, $wn->queryWord($wordForm, "pert");
    push @synsets, $wn->querySense($wordForm, "sim");
    foreach $synset (@synsets)
    {
 	$pos = $synset;
	if($pos =~ /.*\#([a-z])\#.*/)
	{
	    $pos = $1;
	    push @offsets, $wn->offset($synset).$pos;
	}
    }
    return @offsets;
}


# Subroutine that returns all offsetPOSs that are linked
# to a given synset by upward links. Upward link types --
# Hypernymy, Meronymy
# INPUT PARAMS  : $wn       .. WordNet::QueryData object.
#                 $offset   .. OffsetPOS of the synset.
# RETURN VALUES : @offsets  .. Array of offsetPOSs.
sub _getUpwardOffsetsPOS
{
    my $wn;
    my $offset;
    my $synset;
    my $pos;
    my $wordForm;
    my @partsOfSpeech;
    my @synsets;
    my @offsets;

    $wn = shift;
    $offset = shift;
    @offsets = ();
    if($offset =~ /^([0-9]+)([a-z])$/)
    {
	$offset = $1;
	$pos = $2;
    }
    else
    {
	return @offsets;
    }
    $wordForm = $wn->getSense($offset,$pos);
    @synsets = $wn->querySense($wordForm, "hypes");
    push @synsets, $wn->querySense($wordForm, "mero");
    foreach $synset (@synsets)
    {
	$pos = $synset;
	if($pos =~ /.*\#([a-z])\#.*/)
	{
	    $pos = $1;
	    push @offsets, $wn->offset($synset).$pos;
	}
    }
    return @offsets;
}


# Subroutine that returns all offsetPOSs that are linked
# to a given synset by downward links. Downward link types --
# Cause, Entailment, Holonymy, Hyponymy.
# INPUT PARAMS  : $wn       .. WordNet::QueryData object.
#                 $offset   .. OffsetPOS of the synset.
# RETURN VALUES : @offsets  .. Array of offsetPOSs.
sub _getDownwardOffsetsPOS
{
    my $wn;
    my $offset;
    my $synset;
    my $pos;
    my $wordForm;
    my @partsOfSpeech;
    my @synsets;
    my @offsets;

    $wn = shift;
    $offset = shift;
    @offsets = ();
    if($offset =~ /^([0-9]+)([a-z])$/)
    {
	$offset = $1;
	$pos = $2;
    }
    else
    {
	return @offsets;
    }
    $wordForm = $wn->getSense($offset,$pos);
    @synsets = $wn->querySense($wordForm, "holo");
    push @synsets, $wn->querySense($wordForm, "hypos");
    push @synsets, $wn->querySense($wordForm, "enta");
    push @synsets, $wn->querySense($wordForm, "caus");
    foreach $synset (@synsets)
    {
	$pos = $synset;
	if($pos =~ /.*\#([a-z])\#.*/)
	{
	    $pos = $1;
	    push @offsets, $wn->offset($synset).$pos;
	}
    }
    return @offsets;
}


# Subroutine that checks if an offset is in a given
# set of offsets.
# INPUT PARAMS  : $offset, @offsets .. The offset and the set of
#                                      offsets.
# RETURN VALUES : 0 or 1.
sub _isIn
{
  my $op1;
  my @op2;
  my $line;


  $op1 = shift;
  @op2 = @_;
  $line = " ".join(" ", @op2)." ";
  if($line =~ / $op1 /) {
    return 1;
  }
  return 0;
}


# Recursive subroutine to check the existence of a Medium-Strong
# relation between two synsets.
# INPUT PARAMS  : $state, $distance, $chdir, $offset, $path, $endOffset
#                 .. The state of the state machine.
#                    Similarity (links) covered thus far.
#                    Number of changes in direction thus far.
#                    Current node.
#                    Path so far.
#                    Last offset.
# RETURN VALUES : $weight .. weight of the path found.
sub _medStrong
{
    my $self;
    my $state;
    my $distance;
    my $chdir;
    my $from;
    my $path;
    my $endOffset;
    my $retT;
    my $retH;
    my $retU;
    my $retD;
    my $synset;
    my $maxVal;
    my @horiz;
    my @upward;
    my @downward;

    $self = shift;
    $state = shift;
    $distance = shift;
    $chdir = shift;
    $from = shift;
    $path = shift;
    $endOffset = shift;
    if($from eq $endOffset && $distance > 1)
    {
	# [trace]
	if($self->{'trace'})
	{
	    $self->{'traceString'} .= "MedStrong relation path... \n";
	    while($path =~ /([0-9]+)([nvar]?)\s*(\[[DUH]\])?\s*/g)
	    {
		$self->printSet($2, 'offset', $1);
		$self->{traceString} .= " $3 " if($3);
	    }
	    $self->{traceString} .= "\n";
	}
	# [/trace]
	return 8 - $distance - $chdir;
    }
    if($distance >= 5)
    {
	return 0;
    }
    if($state == 0)
    {
	@horiz = &_getHorizontalOffsetsPOS($self->{'wn'}, $from);
	@upward = &_getUpwardOffsetsPOS($self->{'wn'}, $from);
	@downward = &_getDownwardOffsetsPOS($self->{'wn'}, $from);
	$retU = 0;
	foreach $synset (@upward)
	{
	    $retT = $self->_medStrong(1, $distance+1, 0, $synset, $path." [U] ".$synset, $endOffset);
	    $retU = $retT if($retT > $retU);
	}
	$retD = 0;
	foreach $synset (@downward)
	{
	    $retT = $self->_medStrong(2, $distance+1, 0, $synset, $path." [D] ".$synset, $endOffset);
	    $retD = $retT if($retT > $retD);
	}
	$retH = 0;
	foreach $synset (@horiz)
	{
	    $retT = $self->_medStrong(3, $distance+1, 0, $synset, $path." [H] ".$synset, $endOffset);
	    $retH = $retT if($retT > $retH);
	}
	return $retU if($retU > $retD && $retU > $retH);
	return $retD if($retD > $retH);
	return $retH;
    }
    if($state == 1)
    {
	@horiz = &_getHorizontalOffsetsPOS($self->{'wn'}, $from);
	@upward = &_getUpwardOffsetsPOS($self->{'wn'}, $from);
	@downward = &_getDownwardOffsetsPOS($self->{'wn'}, $from);
	$retU = 0;
	foreach $synset (@upward)
	{
	    $retT = $self->_medStrong(1, $distance+1, 0, $synset, $path." [U] ".$synset, $endOffset);
	    $retU = $retT if($retT > $retU);
	}
	$retD = 0;
	foreach $synset (@downward)
	{
	    $retT = $self->_medStrong(4, $distance+1, 1, $synset, $path." [D] ".$synset, $endOffset);
	    $retD = $retT if($retT > $retD);
	}
	$retH = 0;
	foreach $synset (@horiz)
	{
	    $retT = $self->_medStrong(5, $distance+1, 1, $synset, $path." [H] ".$synset, $endOffset);
	    $retH = $retT if($retT > $retH);
	}
	return $retU if($retU > $retD && $retU > $retH);
	return $retD if($retD > $retH);
	return $retH;
    }
    if($state == 2)
    {
	@horiz = &_getHorizontalOffsetsPOS($self->{'wn'}, $from);
	@downward = &_getDownwardOffsetsPOS($self->{'wn'}, $from);
	$retD = 0;
	foreach $synset (@downward)
	{
	    $retT = $self->_medStrong(2, $distance+1, 0, $synset, $path." [D] ".$synset, $endOffset);
	    $retD = $retT if($retT > $retD);
	}
	$retH = 0;
	foreach $synset (@horiz)
	{
	    $retT = $self->_medStrong(6, $distance+1, 0, $synset, $path." [H] ".$synset, $endOffset);
	    $retH = $retT if($retT > $retH);
	}
	return ($retD > $retH) ? $retD : $retH;
    }
    if($state == 3)
    {
	@horiz = &_getHorizontalOffsetsPOS($self->{'wn'}, $from);
	@downward = &_getDownwardOffsetsPOS($self->{'wn'}, $from);
	$retD = 0;
	foreach $synset (@downward)
	{
	    $retT = $self->_medStrong(7, $distance+1, 0, $synset, $path." [D] ".$synset, $endOffset);
	    $retD = $retT if($retT > $retD);
	}
	$retH = 0;
	foreach $synset (@horiz)
	{
	    $retT = $self->_medStrong(3, $distance+1, 0, $synset, $path." [H] ".$synset, $endOffset);
	    $retH = $retT if($retT > $retH);
	}
	return ($retD > $retH) ? $retD : $retH;
    }
    if($state == 4)
    {
	@downward = &_getDownwardOffsetsPOS($self->{'wn'}, $from);
	$retD = 0;
	foreach $synset (@downward)
	{
	    $retT = $self->_medStrong(4, $distance+1, 1, $synset, $path." [D] ".$synset, $endOffset);
	    $retD = $retT if($retT > $retD);
	}
	return $retD;
    }
    if($state == 5)
    {
	@horiz = &_getHorizontalOffsetsPOS($self->{'wn'}, $from);
	@downward = &_getDownwardOffsetsPOS($self->{'wn'}, $from);
	$retD = 0;
	foreach $synset (@downward)
	{
	    $retT = $self->_medStrong(4, $distance+1, 2, $synset, $path." [D] ".$synset, $endOffset);
	    $retD = $retT if($retT > $retD);
	}
	$retH = 0;
	foreach $synset (@horiz)
	{
	    $retT = $self->_medStrong(5, $distance+1, 1, $synset, $path." [H] ".$synset, $endOffset);
	    $retH = $retT if($retT > $retH);
	}
	return ($retD > $retH) ? $retD : $retH;
    }
    if($state == 6)
    {
	@horiz = &_getHorizontalOffsetsPOS($self->{'wn'}, $from);
	$retH = 0;
	foreach $synset (@horiz)
	{
	    $retT = $self->_medStrong(6, $distance+1, 1, $synset, $path." [H] ".$synset, $endOffset);
	    $retH = $retT if($retT > $retH);
	}
	return $retH;
    }
    if($state == 7)
    {
	@downward = &_getDownwardOffsetsPOS($self->{'wn'}, $from);
	$retD = 0;
	foreach $synset (@downward)
	{
	    $retT = $self->_medStrong(7, $distance+1, 1, $synset, $path." [D] ".$synset, $endOffset);
	    $retD = $retT if($retT > $retD);
	}
	return $retD;
    }
    return 0;
}

1;

__END__

=back

=head2 Usage

The semantic relatedness modules in this distribution are built as classes
that define the following methods:

  new()
  getRelatedness()
  getError()
  getTraceString()

See the WordNet::Similarity(3) documentation for details of these methods.

=head3 Typical Usage Examples

To create an object of the hso measure, we would have the following
lines of code in the Perl program.

   use WordNet::Similarity::hso;
   $measure = WordNet::Similarity::hso->new($wn, '/home/sid/hso.conf');

The reference of the initialized object is stored in the scalar variable
'$measure'. '$wn' contains a WordNet::QueryData object that should have been
created earlier in the program. The second parameter to the 'new' method is
the path of the configuration file for the hso measure. If the 'new'
method is unable to create the object, '$measure' would be undefined. This,
as well as any other error/warning may be tested.

   die "Unable to create object.\n" if(!defined $measure);
   ($err, $errString) = $measure->getError();
   die $errString."\n" if($err);

To find the semantic relatedness of the first sense of the noun 'car' and
the second sense of the noun 'bus' using the measure, we would write
the following piece of code:

   $relatedness = $measure->getRelatedness('car#n#1', 'bus#n#2');

To get traces for the above computation:

   print $measure->getTraceString();

However, traces must be enabled using configuration files. By default
traces are turned off.

=head1 CONFIGURATION FILE

The behavior of the measures of semantic relatedness can be controlled by
using configuration files. These configuration files specify how certain
parameters are initialized within the object. A configuration file may be
specififed as a parameter during the creation of an object using the new
method. The configuration files must follow a fixed format.

Every configuration file starts with the name of the module ON THE FIRST LINE
of the file. For example, a configuration file for the hso module will have
on the first line 'WordNet::Similarity::hso'. This is followed by the various
parameters, each on a new line and having the form 'name::value'. The
'value' of a parameter is optional (in case of boolean parameters). In case
'value' is omitted, we would have just 'name::' on that line. Comments are
supported in the configuration file. Anything following a '#' is ignored till
the end of the line.

The module parses the configuration file and recognizes the following
parameters:

=over

=item trace

The value of this parameter specifies the level of tracing that should
be employed for generating the traces. This value
is an integer equal to 0, 1, or 2. If the value is omitted, then the
default value, 0, is used. A value of 0 switches tracing off. A value
of 1 or 2 switches tracing on. A trace of level 1 means the synsets are
represented as word#pos#sense strings, while for level 2, the synsets
are represented as word#pos#offset strings.

=item cache

The value of this parameter specifies whether or not caching of the
relatedness values should be performed.  This value is an
integer equal to  0 or 1.  If the value is omitted, then the default
value, 1, is used. A value of 0 switches caching 'off', and
a value of 1 switches caching 'on'.

=item maxCacheSize

The value of this parameter indicates the size of the cache, used for
storing the computed relatedness value. The specified value must be
a non-negative integer.  If the value is omitted, then the default
value, 5,000, is used. Setting maxCacheSize to zero has
the same effect as setting cache to zero, but setting cache to zero is
likely to be more efficient.  Caching and tracing at the same time can result
in excessive memory usage because the trace strings are also cached.  If
you intend to perform a large number of relatedness queries, then you
might want to turn tracing off.

=back

=head1 SEE ALSO

perl(1), WordNet::Similarity(3), WordNet::QueryData(3)

http://www.cs.utah.edu/~sidd

http://wordnet.princeton.edu

http://www.ai.mit.edu/~jrennie/WordNet

http://groups.yahoo.com/group/wn-similarity

=head1 AUTHORS

 Ted Pedersen, University of Minnesota Duluth
 tpederse at d.umn.edu

 Siddharth Patwardhan, University of Utah, Salt Lake City
 sidd at cs.utah.edu

=head1 BUGS

None.

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2005, Ted Pedersen and Siddharth Patwardhan

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to

    The Free Software Foundation, Inc.,
    59 Temple Place - Suite 330,
    Boston, MA  02111-1307, USA.

Note: a copy of the GNU General Public License is available on the web
at L<http://www.gnu.org/licenses/gpl.txt> and is included in this
distribution as GPL.txt.

=cut
