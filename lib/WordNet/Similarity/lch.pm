# WordNet::Similarity::lch.pm version 0.03
# (Updated 03/10/2003 -- Sid)
#
# Semantic Similarity Measure package implementing the semantic 
# relatedness measure described by Leacock and Chodorow (1998).
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


package WordNet::Similarity::lch;

use strict;

use Exporter;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

@ISA = qw(Exporter);

%EXPORT_TAGS = ();

@EXPORT_OK = ();

@EXPORT = ();

$VERSION = '0.03';


# 'new' method for the lch class... creates and returns a WordNet::Similarity::lch object.
# INPUT PARAMS  : $className  .. (WordNet::Similarity::lch) (required)
#                 $wn         .. The WordNet::QueryData object (required).
#                 $configFile .. Name of the config file for getting the parameters (optional).
# RETURN VALUE  : $lch        .. The newly created lch object.
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
	$self->{'errorString'} .= "\nError (WordNet::Similarity::lch->new()) - ";
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
	$self->{'traceString'} .= "WordNet::Similarity::lch object created:\n";
	$self->{'traceString'} .= "trace :: ".($self->{'trace'})."\n";
	$self->{'traceString'} .= "cache :: ".($self->{'doCache'})."\n";
    }
    # [/trace]

    return $self;
}


# Initialization of the WordNet::Similarity::lch object... parses the config file and sets up 
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
	    if($modname =~ /^WordNet::Similarity::lch/)
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
			$self->{'errorString'} .= "\nWarning (WordNet::Similarity::lch->_initialize()) - ";
			$self->{'errorString'} .= "Unrecognized parameter '$_'. Ignoring.";
			$self->{'error'} = 1;
		    }
		}
	    }
	    else
	    {
		$self->{'errorString'} .= "\nError (WordNet::Similarity::lch->_initialize()) - ";
		$self->{'errorString'} .= "$paramFile does not appear to be a config file.";
		$self->{'error'} = 2;
		return;
	    }
	    close(PARAM);
	}
	else
	{
	    $self->{'errorString'} .= "\nError (WordNet::Similarity::lch->_initialize()) - ";
	    $self->{'errorString'} .= "Unable to open config file $paramFile.";
	    $self->{'error'} = 2;
	    return;
	}
    }
}

# The Leacock-Chodorow relatedness measure subroutine ...
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
    my $pos;
    my $pos1;
    my $pos2;
    my $offset;
    my $lOffset;
    my $rOffset;
    my $lTree;
    my $rTree;
    my $lCount;
    my $rCount;
    my $leastCommonSubsumer;
    my $LCSOffset;
    my $minDist;
    my $score;
    my @lTrees;
    my @rTrees;

    # Check the existence of the WordNet::QueryData object.
    if(!$wn)
    {
	$self->{'errorString'} .= "\nError (WordNet::Similarity::lch->getRelatedness()) - ";
	$self->{'errorString'} .= "A WordNet::QueryData object is required.";
	$self->{'error'} = 2;
	return undef;
    }

    # Initialize traces.
    $self->{'traceString'} = "" if($self->{'trace'});

    # Undefined input cannot go unpunished.
    if(!$wps1 || !$wps2)
    {
	$self->{'errorString'} .= "\nWarning (WordNet::Similarity::lch->getRelatedness()) - Undefined input values.";
	$self->{'error'} = ($self->{'error'} < 1) ? 1 : $self->{'error'};
	return undef;
    }

    # Security check -- are the input strings in the correct format (word#pos#sense).
    if($wps1 =~ /^\S+\#([nvar])\#\d+$/)
    {
	$pos1 = $1;
    }
    else
    {
	$self->{'errorString'} .= "\nWarning (WordNet::Similarity::lch->getRelatedness()) - ";
	$self->{'errorString'} .= "Input not in word\#pos\#sense format.";
	$self->{'error'} = ($self->{'error'} < 1) ? 1 : $self->{'error'};
	return undef;
    }
    if($wps2 =~ /^\S+\#([nvar])\#\d+$/)
    {
	$pos2 = $1;
    }
    else
    {
	$self->{'errorString'} .= "\nWarning (WordNet::Similarity::lch->getRelatedness()) - ";
	$self->{'errorString'} .= "Input not in word\#pos\#sense format.";
	$self->{'error'} = ($self->{'error'} < 1) ? 1 : $self->{'error'};
	return undef;
    }

    # Relatedness is 0 across parts of speech.
    if($pos1 ne $pos2)
    {
	$self->{'traceString'} = "Relatedness 0 across parts of speech ($wps1, $wps2)." if($self->{'trace'});
	return 0;
    }
    $pos = $pos1;

    # Relatedness is defined only for nouns and verbs.
    if($pos !~ /[nv]/)
    {
	$self->{'traceString'} = "Only verbs and nouns have hypernym trees ($wps1, $wps2)." if($self->{'trace'});
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
    $lOffset = $wn->offset($wps1);
    $rOffset = $wn->offset($wps2);
    $self->{'traceString'} = "";

    if(!$lOffset || !$rOffset)
    {
	$self->{'errorString'} .= "\nWarning (WordNet::Similarity::lch->getRelatedness()) - ";
	$self->{'errorString'} .= "Input senses not found in WordNet.";
	$self->{'error'} = ($self->{'error'} < 1) ? 1 : $self->{'error'};
	return undef;
    }

    # Get the hypernym trees.
    @lTrees = &getHypernymTrees($self->{'wn'}, $lOffset, $pos);
    foreach $lTree (@lTrees)
    {
	push(@{$lTree}, $lOffset);
    }

    # Get the hypernym trees.
    @rTrees = &getHypernymTrees($self->{'wn'}, $rOffset, $pos);
    foreach $rTree (@rTrees)
    {
	push(@{$rTree}, $rOffset);
    }

    # [trace]
    if($self->{'trace'})
    {
	foreach $lTree (@lTrees)
	{
	    $self->{'traceString'} .= "HyperTree: ";
	    $self->_printSet($pos, @{$lTree});
	    $self->{'traceString'} .= "\n";
	}
	foreach $rTree (@rTrees)
	{
	    $self->{'traceString'} .= "HyperTree: ";
	    $self->_printSet($pos, @{$rTree});
	    $self->{'traceString'} .= "\n";
	}
    }
    # [/trace]

    # Find the smallest path in these trees.
    $minDist = 100;
    foreach $lTree (@lTrees)
    {
	foreach $rTree (@rTrees)
	{
	    $leastCommonSubsumer = &getLCSfromTrees($lTree, $rTree);
	    $lCount = 0;
	    foreach $offset (reverse @{$lTree})
	    {
		$lCount++;
		last if($offset == $leastCommonSubsumer);
	    }
	    $rCount = 0;
	    foreach $offset (reverse @{$rTree})
	    {
		$rCount++;
		last if($offset == $leastCommonSubsumer);
	    }
	    if($rCount + $lCount - 1 < $minDist)
	    {
		$minDist = $lCount + $rCount - 1;
		$LCSOffset = $leastCommonSubsumer;
	    }
	}
    }
    
    # [trace]
    if($self->{'trace'})
    {
	$self->{'traceString'} .= "LCS: ";
	$self->_printSet($pos, $LCSOffset);
	$self->{'traceString'} .= "  Path length: $minDist.\n\n";
    }
    # [/trace]

    if($minDist == 100)
    {
	$self->{'errorString'} .= "\nWarning (WordNet::Similarity::lch->getRelatedness()) - ";
	$self->{'errorString'} .= "A path length of 100... is that possible??";
	$self->{'error'} = ($self->{'error'} < 1) ? 1 : $self->{'error'};
	return undef;
    }
    elsif($minDist > 0)
    {
	$score = -log($minDist/32);
	$self->{'simCache'}->{"${wps1}::$wps2"} = $score if($self->{'doCache'});
	$self->{'traceCache'}->{"${wps1}::$wps2"} = $self->{'traceString'} if($self->{'doCache'});
	return $score;
    }
    else
    {
	$self->{'errorString'} .= "\nWarning (WordNet::Similarity::lch->getRelatedness()) - ";
	$self->{'errorString'} .= "Internal error while finding relatedness.";
	$self->{'error'} = ($self->{'error'} < 1) ? 1 : $self->{'error'};
	return undef;
    }
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


# Suroutine that returns an array of hypernym trees, given the offset of 
# the synset. Each hypernym tree is an array of offsets.
# INPUT PARAMS  : $wn     .. The WordNet::QueryData object.
#               : $offset .. Offset of the synset.
#               : $pos    .. Part of speech.
# RETURN VALUES : (@tree1, @tree2, ... ) .. an array of Hypernym trees (offsets).
sub getHypernymTrees
{
    my $wn;
    my $offset;
    my $pos;
    my $wordForm;
    my $element;
    my $hypernym;
    my @hypernyms;
    my @returnArray;
    my @tmpArray;

    $wn = shift;
    $offset = shift;
    $pos = shift;
    $wordForm = $wn->getSense($offset, $pos);
    @hypernyms = $wn->querySense($wordForm, "hype");
    @returnArray = ();
    if($#hypernyms < 0)
    {
	@tmpArray = (0);
	push @returnArray, [@tmpArray];
    }
    else
    {
	foreach $hypernym (@hypernyms)
	{
	    @tmpArray = &getHypernymTrees($wn, $wn->offset($hypernym), $pos);
	    foreach $element (@tmpArray)
	    {
		push @{$element}, $wn->offset($hypernym);
		push @returnArray, [@{$element}];
	    }
	}
    }
    return @returnArray;
}


# Subroutine to get the Least Common Subsumer of two
# hypernym trees (paths in the Noun/Verb Taxonomies). i.e. the lowest
# common point of intersection of two trees.
# INPUT PARAMS  : @lOffsets .. array of offsets in the first hypernym tree.
#                 @rOffsets .. array of offsets in the second hypernym tree.
# RETRUN VALUES : $lCSOffset .. Offset of the Least Common Subsumer.
sub getLCSfromTrees
{
    my $array1;
    my $array2;
    my $element;
    my $tmpString;
    my @tree1;
    my @tree2;
    
    $array1 = shift;
    $array2 = shift;
    @tree1 = reverse @{$array1};
    @tree2 = reverse @{$array2};
    $tmpString = " ".join(" ", @tree2)." ";
    foreach $element (@tree1)
    {
	if($tmpString =~ / $element /)
	{
	    return $element;
	}
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
    my $wps;
    my $opstr;
    my @offsets;
    
    $self = shift;
    $pos = shift;
    @offsets = @_;
    $wn = $self->{'wn'};
    $opstr = "";
    foreach $offset (@offsets)
    {
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

WordNet::Similarity::lch - Perl module for computing semantic relatedness
of word senses using the method described by Leacock and Chodorow (1998).

=head1 SYNOPSIS

use WordNet::Similarity::lch;

use WordNet::QueryData;

my $wn = WordNet::QueryData->new();

my $myobj = WordNet::Similarity::lch->new($wn);

my $value = $myobj->getRelatedness("car#n#1", "bus#n#2");

($error, $errorString) = $myobj->getError();

die "$errorString\n" if($error);

print "car (sense 1) <-> bus (sense 2) = $value\n";

=head1 DESCRIPTION

This module computes the semantic relatedness of word senses according
to a method described by Leacock and Chodorow (1998). This method counts up
the number of edges between the senses in the 'is-a' hierarchy of WordNet.
This value is then scaled by the maximum depth of the WordNet 'is-a'
hierarchy. A relatedness value is obtained by taking the negative log
of this scaled value.

=head1 USAGE

  The semantic relatedness modules in this distribution are built as classes
that expose the following methods:
  new()
  getRelatedness()
  getError()
  getTraceString()

See the WordNet::Similarity(3) documentation for details of these methods.

=head1 TYPICAL USAGE EXAMPLES

  To create an object of the lch measure, we would have the following
lines of code in the perl program. 

   use WordNet::Similarity::lch;
   $measure = WordNet::Similarity::lch->new($wn, '/home/sid/lch.conf');

The reference of the initialized object is stored in the scalar variable
'$measure'. '$wn' contains a WordNet::QueryData object that should have been
created earlier in the program. The second parameter to the 'new' method is
the path of the configuration file for the lch measure. If the 'new'
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
the file. For example, a configuration file for the lch module will have
on the first line 'WordNet::Similarity::lch'. This is followed by the various
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
