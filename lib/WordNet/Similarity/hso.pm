# WordNet::Similarity::hso.pm version 0.03
# (Updated 03/10/2003 -- Sid)
#
# Semantic Similarity Measure package implementing the semantic 
# distance measure described by Hirst and St.Onge (1998).
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


package WordNet::Similarity::hso;

use strict;

use Exporter;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

@ISA = qw(Exporter);

%EXPORT_TAGS = ();

@EXPORT_OK = ();

@EXPORT = ();

$VERSION = '0.03';


# 'new' method for the hso class... creates and returns a WordNet::Similarity::hso object.
# INPUT PARAMS  : $className  .. (WordNet::Similarity::hso) (required)
#                 $wn         .. The WordNet::QueryData object (required).
#                 $configFile .. Name of the config file for getting the parameters (optional).
# RETURN VALUE  : $hso        .. The newly created hso object.
sub new
{
    my $className;
    my $self = {};
    my $wn;

    # The name of my class.
    $className = shift;
    
    # Initialize the error string and the error level.
    $self->{'errorString'} = "";
    $self->{'error'} = 0;
    
    # The WordNet::QueryData object.
    $wn = shift;
    $self->{'wn'} = $wn;
    if(!$wn)
    {
	$self->{'errorString'} .= "\nError (WordNet::Similarity::hso->new()) - ";
	$self->{'errorString'} .= "A WordNet::QueryData object is required.";
	$self->{'error'} = 2;
    }

    # Bless object, initialize it and return it.
    bless($self, $className);
    $self->_initialize(shift) if($self->{'error'} < 2);

    # [trace]
    $self->{'traceString'} = "";
    if($self->{'trace'})
    {
	$self->{'traceString'} .= "WordNet::Similarity::hso object created:\n";
	$self->{'traceString'} .= "trace :: ".($self->{'trace'})."\n";
	$self->{'traceString'} .= "cache :: ".($self->{'doCache'})."\n";
    }
    # [/trace]

    return $self;
}


# Initialization of the WordNet::Similarity::hso object... parses the config file and sets up 
# global variables, or sets them to default values.
# INPUT PARAMS  : $paramFile .. File containing the module specific params.
# RETURN VALUES : (none)
sub _initialize
{
    my $self;
    my $paramFile;
    my $infoContentFile;
    my $wn;

    # Reference to the object.
    $self = shift;
    
    # Get reference to WordNet.
    $wn = $self->{'wn'};

    # Name of the parameter file.
    $paramFile = shift;
    
    # Initialize the $posList... Parts of Speech that this module can handle.
    $self->{"n"} = 1;
    $self->{"v"} = 1;
    $self->{"a"} = 1;
    $self->{"r"} = 1;
    
    # Initialize the cache stuff.
    $self->{'doCache'} = 1;
    $self->{'simCache'} = ();
    $self->{'traceCache'} = ();
    
    # Initialize tracing.
    $self->{'trace'} = 0;
    $self->{'traceString'} = "";

    # Parse the config file and
    # read parameters from the file.
    # Looking for params --> 
    # trace, infocontent file, cache
    if(defined $paramFile)
    {
	my $modname;
	
	if(open(PARAM, $paramFile))
	{
	    $modname = <PARAM>;
	    $modname =~ s/[\r\f\n]//g;
	    $modname =~ s/\s+//g;
	    if($modname =~ /^WordNet::Similarity::hso/)
	    {
		while(<PARAM>)
		{
		    s/[\r\f\n]//g;
		    s/\#.*//;
		    s/\s+//g;
		    if(/^trace::(.*)/)
		    {
			my $tmp = $1;
			$self->{'trace'} = 1;
			$self->{'trace'} = $tmp if($tmp =~ /^[012]$/);
		    }
		    elsif(/^cache::(.*)/)
		    {
			my $tmp = $1;
			$self->{'doCache'} = 1;
			$self->{'doCache'} = $tmp if($tmp =~ /^[01]$/);
		    }
		    elsif($_ ne "")
		    {
			s/::.*//;
			$self->{'errorString'} .= "\nWarning (WordNet::Similarity::hso->_initialize()) - ";
			$self->{'errorString'} .= "Unrecognized parameter '$_'. Ignoring.";
			$self->{'error'} = 1;
		    }
		}
	    }
	    else
	    {
		$self->{'errorString'} .= "\nError (WordNet::Similarity::hso->_initialize()) - ";
		$self->{'errorString'} .= "$paramFile does not appear to be a config file.";
		$self->{'error'} = 2;
		return;
	    }
	    close(PARAM);
	}
	else
	{
	    $self->{'errorString'} .= "\nError (WordNet::Similarity::hso->_initialize()) - ";
	    $self->{'errorString'} .= "Unable to open config file $paramFile.";
	    $self->{'error'} = 2;
	    return;
	}
    }
}


# The Hirst-St.Onge relatedness measure subroutine ...
# INPUT PARAMS  : $wps1     .. one of the two wordsenses.
#                 $wps2     .. the second wordsense of the two whose 
#                              semantic relatedness needs to be measured.
# RETURN VALUES : $distance .. the semantic relatedness of the two word senses.
#              or undef     .. in case of an error.
sub getRelatedness
{
    my $self = shift;
    my $wps1 = shift;
    my $wps2 = shift;
    my $wn = $self->{'wn'};
    my $word1;
    my $word2;
    my $pos1;
    my $pos2;
    my $pos;
    my $offset1;
    my $offset2;
    my $score;
    my @horiz1;
    my @horiz2;
    my @upward1;
    my @upward2;
    my @downward1;
    my @downward2;
    
    # Check the existence of the WordNet::QueryData object.
    if(!$wn)
    {
	$self->{'errorString'} .= "\nError (WordNet::Similarity::hso->getRelatedness()) - ";
	$self->{'errorString'} .= "A WordNet::QueryData object is required.";
	$self->{'error'} = 2;
	return undef;
    }

    # Initialize traces.
    $self->{'traceString'} = "" if($self->{'trace'});

    # Undefined input cannot go unpunished.
    if(!$wps1 || !$wps2)
    {
	$self->{'errorString'} .= "\nWarning (WordNet::Similarity::hso->getRelatedness()) - ";
	$self->{'errorString'} .= "Undefined input values.";
	$self->{'error'} = ($self->{'error'} < 1) ? 1 : $self->{'error'};
	return undef;
    }

    # Security check -- are the input strings in the correct format (word#pos#sense).
    if($wps1 =~ /^(\S+)\#([nvar])\#\d+$/)
    {
	$word1 = $1;
	$pos1 = $2;
    }
    else
    {
	$self->{'errorString'} .= "\nWarning (WordNet::Similarity::hso->getRelatedness()) - ";
	$self->{'errorString'} .= "Input not in word\#pos\#sense format.";
	$self->{'error'} = ($self->{'error'} < 1) ? 1 : $self->{'error'};
	return undef;
    }
    if($wps2 =~ /^(\S+)\#([nvar])\#\d+$/)
    {
	$word2 = $1;
	$pos2 = $2;
    }
    else
    {
	$self->{'errorString'} .= "\nWarning (WordNet::Similarity::hso->getRelatedness()) - ";
	$self->{'errorString'} .= "Input not in word\#pos\#sense format.";
	$self->{'error'} = ($self->{'error'} < 1) ? 1 : $self->{'error'};
	return undef;
    }

    # Which parts of speech do we have.
    if($pos1 !~ /[nvar]/ || $pos2 !~ /[nvar]/)
    {
	$self->{'errorString'} .= "\nWarning (WordNet::Similarity::hso->getRelatedness()) - ";
	$self->{'errorString'} .= "Unknown part(s) of speech.";
	$self->{'error'} = ($self->{'error'} < 1) ? 1 : $self->{'error'};
	return 0;
    }

    # Now check if the similarity value for these two synsets is in
    # fact in the cache... if so return the cached value.
    if($self->{'doCache'} && defined $self->{'simCache'}->{"${wps1}::$wps2"})
    {
	if(defined $self->{'traceCache'}->{"${wps1}::$wps2"})
	{
	    $self->{'traceString'} = $self->{'traceCache'}->{"${wps1}::$wps2"};
	}
	return $self->{'simCache'}->{"${wps1}::$wps2"};
    }

    # Now get down to really finding the relatedness of these two.
    $offset1 = $wn->offset($wps1).$pos1;
    $offset2 = $wn->offset($wps2).$pos2;
    $self->{'traceString'} = "";

    if(!$offset1 || !$offset2)
    {
	$self->{'errorString'} .= "\nWarning (WordNet::Similarity::hso->getRelatedness()) - ";
	$self->{'errorString'} .= "Input senses not found in WordNet.";
	$self->{'error'} = ($self->{'error'} < 1) ? 1 : $self->{'error'};
	return undef;
    }

    if($offset1 eq $offset2)
    {
	# [trace]
	if($self->{'trace'})
	{
	    $self->{'traceString'} .= "Strong Rel (Synset Match) : ";
	    $self->_printSet($pos1, $offset1);
	    $self->{'traceString'} .= "\n\n";
	}
	# [/trace]
	
	if($self->{'doCache'})
	{
	    $self->{'simCache'}->{"${wps1}::$wps2"} = 16;
	    $self->{'traceCache'}->{"${wps1}::$wps2"} = $self->{'traceString'};
	}
	return 16;
    }

    @horiz1 = &getHorizontalOffsetsPOS($self->{'wn'}, $offset1);
    @upward1 = &getUpwardOffsetsPOS($self->{'wn'}, $offset1);
    @downward1 = &getDownwardOffsetsPOS($self->{'wn'}, $offset1);
    @horiz2 = &getHorizontalOffsetsPOS($self->{'wn'}, $offset2);
    @upward2 = &getUpwardOffsetsPOS($self->{'wn'}, $offset2);
    @downward2 = &getDownwardOffsetsPOS($self->{'wn'}, $offset2);

    # [trace]
    if($self->{'trace'})
    {
	$self->{'traceString'} .= "Horizontal Links of ";
	$self->_printSet($pos1, $offset1);
	$self->{'traceString'} .= ": ";
	$self->_printSet($pos1, @horiz1);
	$self->{'traceString'} .= "\nUpward Links of ";
	$self->_printSet($pos1, $offset1);
	$self->{'traceString'} .= ": ";
	$self->_printSet($pos1, @upward1);
	$self->{'traceString'} .= "\nDownward Links of ";
	$self->_printSet($pos1, $offset1);
	$self->{'traceString'} .= ": ";
	$self->_printSet($pos1, @downward1);
	$self->{'traceString'} .= "\nHorizontal Links of ";
	$self->_printSet($pos2, $offset2);
	$self->{'traceString'} .= ": ";
	$self->_printSet($pos2, @horiz2);
	$self->{'traceString'} .= "\nUpward Links of ";
	$self->_printSet($pos2, $offset2);
	$self->{'traceString'} .= ": ";
	$self->_printSet($pos2, @upward2);
	$self->{'traceString'} .= "\nDownward Links of ";
	$self->_printSet($pos2, $offset2);
	$self->{'traceString'} .= ": ";
	$self->_printSet($pos2, @downward2);
	$self->{'traceString'} .= "\n\n";
    }
    # [/trace]
    
    if(&isIn($offset1, @horiz2) || &isIn($offset2, @horiz1))
    {
	# [trace]
	if($self->{'trace'})
	{
	    $self->{'traceString'} .= "Strong Rel (Horizontal Match) : \n";
	    $self->{'traceString'} .= "Horizontal Links of ";
	    $self->_printSet($pos1, $offset1);
	    $self->{'traceString'} .= ": ";
	    $self->_printSet($pos1, @horiz1);
	    $self->{'traceString'} .= "\nHorizontal Links of ";
	    $self->_printSet($pos2, $offset2);
	    $self->{'traceString'} .= ": ";
	    $self->_printSet($pos2, @horiz2);
	    $self->{'traceString'} .= "\n\n";
	}
	# [/trace]
	
	$self->{'simCache'}->{"${wps1}::$wps2"} = 16 if($self->{'doCache'});
	$self->{'traceCache'}->{"${wps1}::$wps2"} = $self->{'traceString'} if($self->{'doCache'});
	return 16;
    }

    if($word1 =~ /$word2/ || $word2 =~ /$word1/)
    {
	if(&isIn($offset1, @upward2) || &isIn($offset1, @downward2))
	{
	    # [trace]
	    if($self->{'trace'})
	    {
		$self->{'traceString'} .= "Strong Rel (Compound Word Match) : \n";
		$self->{'traceString'} .= "All Links of $word1: ";
		$self->_printSet($pos1, @horiz1, @upward1, @downward1);
		$self->{'traceString'} .= "\nAll Links of $word2: ";
		$self->_printSet($pos2, @horiz2, @upward2, @downward2);
		$self->{'traceString'} .= "\n\n";
	    }
	    # [/trace]		

	    $self->{'simCache'}->{"${wps1}::$wps2"} = 16 if($self->{'doCache'});
	    $self->{'traceCache'}->{"${wps1}::$wps2"} = $self->{'traceString'} if($self->{'doCache'});
	    return 16;
	}
	if(&isIn($offset2, @upward1) || &isIn($offset2, @downward1))
	{
	    # [trace]
	    if($self->{'trace'})
	    {
		$self->{'traceString'} .= "Strong Rel (Compound Word Match) : \n";
		$self->{'traceString'} .= "All Links of $word1: ";
		$self->_printSet($pos1, @horiz1, @upward1, @downward1);
		$self->{'traceString'} .= "\nAll Links of $word2: ";
		$self->_printSet($pos2, @horiz2, @upward2, @downward2);
		$self->{'traceString'} .= "\n\n";
	    }
	    # [/trace]		

	    $self->{'simCache'}->{"${wps1}::$wps2"} = 16 if($self->{'doCache'});
	    $self->{'traceCache'}->{"${wps1}::$wps2"} = $self->{'traceString'} if($self->{'doCache'});
	    return 16;
	}
    }
    
    # Conditions for Medium-Strong relations ...
    $score = $self->_medStrong(0, 0, 0, $offset1, $offset1, $offset2);
    
    $self->{'simCache'}->{"${wps1}::$wps2"} = $score if($self->{'doCache'});
    $self->{'traceCache'}->{"${wps1}::$wps2"} = $self->{'traceString'} if($self->{'doCache'});
    return $score;
}


# Function to return the current trace string
sub getTraceString
{
    my $self = shift;
    my $returnString = $self->{'traceString'};
    $self->{'traceString'} = "";
    return $returnString;
}


# Method to return recent error/warning condition
sub getError
{
    my $self = shift;
    my $error = $self->{'error'};
    my $errorString = $self->{'errorString'};
    $self->{'error'} = 0;
    $self->{'errorString'} = "";
    $errorString =~ s/^\n//;
    return ($error, $errorString);
}


# Subroutine to get offsets(POS) of all horizontal links from a given 
# word (offset(POS)). All horizontal links specified  are --
# Also See, Antonymy, Attribute, Pertinence, Similarity.
# INPUT PARAMS  : $wn      .. WordNet::QueryData object.
#                 $offset  .. An offset-pos (e.g. 637554v)
# RETURN VALUES : @offsets .. Array of offset-pos (e.g. 736438n)
sub getHorizontalOffsetsPOS
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
    @synsets = $wn->query($wordForm, "also");
    push @synsets, $wn->query($wordForm, "ants");
    push @synsets, $wn->querySense($wordForm, "attr");
    push @synsets, $wn->query($wordForm, "pert");
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
sub getUpwardOffsetsPOS
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
    @synsets = $wn->querySense($wordForm, "hype");
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
sub getDownwardOffsetsPOS
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
    push @synsets, $wn->querySense($wordForm, "hypo");
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
sub isIn
{
    my $op1;
    my @op2;
    my $line;


    $op1 = shift;
    @op2 = @_;
    $line = " ".join(" ", @op2)." ";
    if($line =~ / $op1 /)
    {
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
		$self->_printSet($2, $1);
		$self->{'traceString'} .= " $3 " if($3);
	    }
	    $self->{'traceString'} .= "\n";
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
	@horiz = &getHorizontalOffsetsPOS($self->{'wn'}, $from);
	@upward = &getUpwardOffsetsPOS($self->{'wn'}, $from);
	@downward = &getDownwardOffsetsPOS($self->{'wn'}, $from);
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
	@horiz = &getHorizontalOffsetsPOS($self->{'wn'}, $from);
	@upward = &getUpwardOffsetsPOS($self->{'wn'}, $from);
	@downward = &getDownwardOffsetsPOS($self->{'wn'}, $from);
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
	@horiz = &getHorizontalOffsetsPOS($self->{'wn'}, $from);
	@downward = &getDownwardOffsetsPOS($self->{'wn'}, $from);
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
	@horiz = &getHorizontalOffsetsPOS($self->{'wn'}, $from);
	@downward = &getDownwardOffsetsPOS($self->{'wn'}, $from);
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
	@downward = &getDownwardOffsetsPOS($self->{'wn'}, $from);
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
	@horiz = &getHorizontalOffsetsPOS($self->{'wn'}, $from);
	@downward = &getDownwardOffsetsPOS($self->{'wn'}, $from);
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
	@horiz = &getHorizontalOffsetsPOS($self->{'wn'}, $from);
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
	@downward = &getDownwardOffsetsPOS($self->{'wn'}, $from);
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


# Subroutine that takes as input an array of offsets
# or offsets(POS) and for each prints to traceString the WORD#POS#(SENSE/OFFSET)
# INPUT PARAMS  : $pos                             .. Part of speech
#               : ($offestpos1, $offsetpos2, ...)  .. Array of offsetPOS's
#                                                     or offests
# RETURN VALUES : none.
sub _printSet
{
    my $self;
    my $wn;
    my $offset;
    my $pos;
    my $p;
    my $wps;
    my $opstr;
    my @offsets;
    
    $self = shift;
    $p = shift;
    @offsets = @_;
    $wn = $self->{'wn'};
    $opstr = "";
    foreach $offset (@offsets)
    {
	if($offset =~ /^([0-9]+)([nvar])$/)
	{
	    $offset = $1;
	    $pos = $2;
	}
	elsif($offset =~ /^[0-9]+$/)
	{
	    $pos = $p;
	}
	else
	{
	    return;
	}
	if(defined $offset && $offset != 0)
	{
	    $wps = $wn->getSense($offset, $pos);
	}
	else
	{
	    $wps = "*Root*\#$pos\#1";
	}
	$wps =~ s/ +/_/g;
	if($self->{'trace'} == 2 && defined $offset && $offset != 0)
	{
	    $wps =~ s/\#[0-9]*$/\#$offset/;
	}
	$opstr .= "$wps ";
    }
    $opstr =~ s/\s+$//;
    $self->{'traceString'} .= $opstr;
}

1;
__END__

=head1 NAME

WordNet::Similarity::hso - Perl module for computing semantic relatedness
of word senses using the method described by Hirst and St.Onge (1998).

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
the method described by Hirst and St.Onge (1998). In their paper they
describe a method to identify 'lexical chains' in text. They measure the
semantic relatedness of words in text to identify the links of the lexical
chains. This measure of relatedness has been implemented in this module.

=head1 USAGE

  The semantic relatedness modules in this distribution are built as classes
that expose the following methods:

  new()
  getRelatedness()
  getError()
  getTraceString()

See the WordNet::Similarity(3) documentation for details of these methods.

=head1 TYPICAL USAGE EXAMPLES

  To create an object of the hso measure, we would have the following
lines of code in the perl program. 

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

To find the sematic relatedness of the first sense of the noun 'car' and
the second sense of the noun 'bus' using the measure, we would write
the following piece of code:

   $relatedness = $measure->getRelatedness('car#n#1', 'bus#n#2');
  
To get traces for the above computation:

   print $measure->getTraceString();

However, traces must be enabled using configuration files. By default
traces are turned off.

=head1 CONFIGURATION FILE

  The behaviour of the measures of semantic relatedness can be controlled by
using configuration files. These configuration files specify how certain
parameters are initialized within the object. A configuration file may be
specififed as a parameter during the creation of an object using the new
method. The configuration files must follow a fixed format.

  Every configuration file starts the name of the module ON THE FIRST LINE of
the file. For example, a configuration file for the hso module will have
on the first line 'WordNet::Similarity::hso'. This is followed by the various
parameters, each on a new line and having the form 'name::value'. The
'value' of a parameter is optional (in case of boolean parameters). In case
'value' is omitted, we would have just 'name::' on that line. Comments are
supported in the configuration file. Anything following a '#' is ignored till
the end of the line.

  The module parses the configuration file and recognizes the following 
parameters:
  (a) 'trace::' -- can take values 0, 1 or 2 or the value can be omitted,
      in which case it sets the trace level to 1. Trace level 0 implies
      no traces. Trace level 1 and 2 imply tracing is 'on', the only 
      difference being the way in which the synsets are displayed in the 
      traces. For trace level 1, the synsets are represented as word#pos#sense
      strings, while for level 2, the synsets are represented as 
      word#pos#offset strings.
  (b) 'cache::' -- can take values 0 or 1 or the value can be omitted, in 
      which case it takes the value 1, i.e. switches 'on' caching. A value of 
      0 switches caching 'off'. By default caching is enabled.

=head1 SEE ALSO

perl(1), WordNet::Similarity(3), WordNet::QueryData(3)

http://www.d.umn.edu/~patw0006

http://www.cogsci.princeton.edu/~wn/

http://www.ai.mit.edu/people/jrennie/WordNet/

=head1 AUTHORS

  Siddharth Patwardhan, <patw0006@d.umn.edu>
  Ted Pedersen, <tpederse@d.umn.edu>

=head1 COPYRIGHT AND LICENSE

Copyright 2003 by Siddharth Patwardhan and Ted Pedersen

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
