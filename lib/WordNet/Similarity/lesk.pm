# WordNet::Similarity::lesk.pm version 0.06
# (Updated 10/10/2003 -- Sid)
#
# Module to accept two WordNet synsets and to return a floating point
# number that indicates how similar those two synsets are, using an
# adaptation of the Lesk method as outlined in <ACL/IJCAI/EMNLP paper,
# Satanjeev Banerjee, Ted Pedersen>
#
# Copyright (c) 2003,
#
# Satanjeev Banerjee, Carnegie Mellon University, Pittsburgh
# banerjee+@cs.cmu.edu
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


package WordNet::Similarity::lesk;

use strict;

use Exporter;

use get_wn_info;

use string_compare;

use stem;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

@ISA = qw(Exporter);

%EXPORT_TAGS = ();

@EXPORT_OK = ();

@EXPORT = ();

$VERSION = '0.06';


# 'new' method for the lesk class... creates and returns a WordNet::Similarity::lesk object.
# INPUT PARAMS  : $className  .. (WordNet::Similarity::lesk) (required)
#                 $wn         .. The WordNet::QueryData object (required).
#                 $configFile .. Name of the config file for getting the parameters (optional).
# RETURN VALUE  : $lesk        .. The newly created lesk object.
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
	$self->{'errorString'} .= "\nError (WordNet::Similarity::lesk->new()) - ";
	$self->{'errorString'} .= "A WordNet::QueryData object is required.";
	$self->{'error'} = 2;
    }
    else { 
        $wn->VERSION(1.30);  # check WordNet::QueryData version
    }

    # Bless object, initialize it and return it.
    bless($self, $className);
    $self->_initialize(shift) if($self->{'error'} < 2);

    return $self;
}


# Initialization of the WordNet::Similarity::lesk object... parses the config file and sets up 
# global variables, or sets them to default values.
# INPUT PARAMS  : $paramFile .. File containing the module specific params.
# RETURN VALUES : (none)
sub _initialize
{
    my $self;
    my $paramFile;
    my $relationFile;
    my $stopFile;
    my $wn;
    my $gwi;
    my %stopHash = ();

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
    $self->{'cacheQ'} = ();
    $self->{'maxCacheSize'} = 1000;
    
    # Initialize tracing.
    $self->{'trace'} = 0;

    # Stemming? Normalizing?
    $self->{'doStem'} = 0;
    $self->{'doNormalize'} = 0;

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
	    if($modname =~ /^WordNet::Similarity::lesk/)
	    {
		while(<PARAM>)
		{
		    s/[\r\f\n]//g;
		    s/\#.*//;
		    s/\s+//g;
		    if(/^trace::(.*)/)
		    {
			my $tmp = $1;
			$self->{'trace'} = 2;
			$self->{'trace'} = $tmp if($tmp =~ /^[012]$/);
		    }
		    elsif(/^relation::(.*)/)
		    {
			$relationFile = $1;
		    }
		    elsif(/^stop::(.*)/)
		    {
			$stopFile = $1;
		    }
		    elsif(/^stem::(.*)/)
		    {
			my $tmp = $1;
			$self->{'doStem'} = 1;
			$self->{'doStem'} = $tmp if($tmp =~ /^[01]$/);
		    }
		    elsif(/^normalize::(.*)/)
		    {
			my $tmp = $1;
			$self->{'doNormalize'} = 1;
			$self->{'doNormalize'} = $tmp if($tmp =~ /^[01]$/);
		    }
		    elsif(/^cache::(.*)/)
		    {
			my $tmp = $1;
			$self->{'doCache'} = 1;
			$self->{'doCache'} = $tmp if($tmp =~ /^[01]$/);
		    }
		    elsif(m/^(?:max)?CacheSize::(.*)/i) 
		    {
			my $mcs = $1;
			$self->{'maxCacheSize'} = 1000;
			$self->{'maxCacheSize'} = $mcs
			    if(defined ($mcs) && $mcs =~ m/^\d+$/);
			$self->{'maxCacheSize'} = 0 if($self->{'maxCacheSize'} < 0);
		    }
		    elsif($_ ne "")
		    {
			s/::.*//;
			$self->{'errorString'} .= "\nWarning (WordNet::Similarity::lesk->_initialize()) - ";
			$self->{'errorString'} .= "Unrecognized parameter '$_'. Ignoring.";
			$self->{'error'} = 1;
		    }
		}
	    }
	    else
	    {
		$self->{'errorString'} .= "\nError (WordNet::Similarity::lesk->_initialize()) - ";
		$self->{'errorString'} .= "$paramFile does not appear to be a config file.";
		$self->{'error'} = 2;
		return;
	    }
	    close(PARAM);
	}
	else
	{
	    $self->{'errorString'} .= "\nError (WordNet::Similarity::lesk->_initialize()) - ";
	    $self->{'errorString'} .= "Unable to open config file $paramFile.";
	    $self->{'error'} = 2;
	    return;
	}
    }

    # Look for the default relation file if not specified by the user.
    # Search the @INC path in WordNet/Similarity.
    if(!(defined $relationFile))
    {
	my $path;
	my $header;
	my @possiblePaths = ();

	# Look for all possible default data files installed.
	foreach $path (@INC)
	{
	    if(-e $path."/WordNet/relation.dat")
	    {
		push @possiblePaths, $path."/WordNet/relation.dat";
	    }
	    elsif(-e $path."\\WordNet\\relation.dat")
	    {
		push @possiblePaths, $path."\\WordNet\\relation.dat";
	    }
	}

	# If there are multiple possibilities, get the one in the correct format.
	foreach $path (@possiblePaths)
	{
	    if(open(RELATIONS, $path))
	    {
		$header = <RELATIONS>;
		$header =~ s/[\r\f\n]//g;
		$header =~ s/\s+//g;
		if($header =~ /LeskRelationFile/)
		{
		    $relationFile = $path;
		    close(RELATIONS);
		    last;
		}
		close(RELATIONS);
	    }
	}
    }

    # Load the stop list.
    if($stopFile)
    {
	my $line;

	if(open(STOP, $stopFile))
	{
	    while($line = <STOP>)
	    {
		$line =~ s/[\r\f\n]//g;
		$line =~ s/\s//g;
		$stopHash{$line} = 1;		
	    }
	    close(STOP);   
	}
	else
	{
	    $self->{'errorString'} .= "\nWarning (WordNet::Similarity::lesk->_initialize()) - ";
	    $self->{'errorString'} .= "Unable to open $stopFile.";
	    $self->{'error'} = ($self->{'error'} < 1) ? 1 : $self->{'error'};
	}
    }

    # so now we are ready to initialize the get_wn_info package with
    # the wordnet object, 0/1 depending on if stemming is required and
    # the stop hash
    if($self->{'doStem'}) 
    { 
	$gwi = get_wn_info->new($wn, 1, %stopHash); 
	$self->{'gwi'} = $gwi;
    }
    else 
    { 
	$gwi = get_wn_info->new($wn, 0, %stopHash); 
	$self->{'gwi'} = $gwi;
    }

    # Load the relations data.
    if($relationFile)
    {
	my $header;
	my $relation;

	if(open(RELATIONS, $relationFile))
	{
	    $header = <RELATIONS>;
	    $header =~ s/[\r\f\n]//g;
	    $header =~ s/\s+//g;
	    if($header =~ /LeskRelationFile/)
	    {
		my $index = 0;
		$self->{'functions'} = ();
		$self->{'weights'} = ();
		while($relation = <RELATIONS>)
		{
		    $relation =~ s/[\r\f\n]//g;
		    
		    # now for each line in the <REL> file, extract the
		    # nested functions if any, check if they are defined,
		    # if it makes sense to nest them, and then finally put
		    # them into the @functions triple dimensioned array!
		    
		    # remove leading/trailing spaces from the relation
		    $relation =~ s/^\s*(\S*?)\s*$/$1/;
		    
		    # now extract the weight if any. if no weight, assume 1
		    if($relation =~ /(\S+)\s+(\S+)/)
		    {
			$relation = $1;
			$self->{'weights'}->[$index] = $2;
		    }
		    else 
		    { 
			$self->{'weights'}->[$index] = 1; 
		    }
		    
		    # check if we have a "proper" relation, that is a relation in
		    # there are two blocks of functions!
		    if($relation !~ /(.*)-(.*)/)
		    {
			$self->{'errorString'} .= "\nError (WordNet::Similarity::lesk->_initialize()) - ";
			$self->{'errorString'} .= "Bad file format ($relationFile).";
			$self->{'error'} = 2;
			close(RELATIONS);
			return;		
		    }
		    
		    # get the two parts of the relation pair
		    my @twoParts;
		    my $l;
		    $twoParts[0] = $1;
		    $twoParts[1] = $2;
		    
		    # process the two parts and put into functions array
		    for($l = 0; $l < 2; $l++)
		    {
			no strict;

			$twoParts[$l] =~ s/[\s\)]//g;
			my @functionArray = split(/\(/, $twoParts[$l]);
			
			my $j = 0;
			my $fn = $functionArray[$#functionArray];
			if(!($gwi->can($fn)))
			{
			    $self->{'errorString'} .= "\nError (WordNet::Similarity::lesk->_initialize()) - ";
			    $self->{'errorString'} .= "Undefined function ($functionArray[$#functionArray]) in relations file.";
			    $self->{'error'} = 2;
			    close(RELATIONS);
			    return;
			}
			
			$self->{'functions'}->[$index]->[$l]->[$j++] = $functionArray[$#functionArray];
			my $input; 
			my $output; 
			my $dummy;
			my $k;
			
			for ($k = $#functionArray-1; $k >= 0; $k--)
			{
			    my $fn2 = $functionArray[$k];
			    my $fn3 = $functionArray[$k+1];
			    if(!($gwi->can($fn2)))
			    {
				$self->{'errorString'} .= "\nError (WordNet::Similarity::lesk->_initialize()) - ";
				$self->{'errorString'} .= "Undefined function ($functionArray[$k]) in relations file.";
				$self->{'error'} = 2;
				close(RELATIONS);
				return;
			    }
			    
			    ($input, $dummy) = $gwi->$fn2(0);
			    ($dummy, $output) = $gwi->$fn3(0);
			    
			    if($input != $output)
			    {
				$self->{'errorString'} .= "\nError (WordNet::Similarity::lesk->_initialize()) - ";
				$self->{'errorString'} .= "Invalid function combination - $functionArray[$k]($functionArray[$k+1]).";
				$self->{'error'} = 2;
				close(RELATIONS);
				return;
			    }
			    
			    $self->{'functions'}->[$index]->[$l]->[$j++] = $functionArray[$k];
			}
			
			# if the output of the outermost function is synset array (1)
			# wrap a glos around it
			my $xfn = $functionArray[0];
			($dummy, $output) = $gwi->$xfn(0);
			if($output == 1) 
			{ 
			    $self->{'functions'}->[$index]->[$l]->[$j++] = "glos"; 
			}
		    }
		    
		    $index++;
		}
	    }
	    else
	    {
		$self->{'errorString'} .= "\nError (WordNet::Similarity::lesk->_initialize()) - ";
		$self->{'errorString'} .= "Bad file format ($relationFile).";
		$self->{'error'} = 2;
		close(RELATIONS);
		return;		
	    }
	    close(RELATIONS);   
	}
	else
	{
	    $self->{'errorString'} .= "\nError (WordNet::Similarity::lesk->_initialize()) - ";
	    $self->{'errorString'} .= "Unable to open $relationFile.";
	    $self->{'error'} = 2;
	    return;
	}
    }
    else
    {
	$self->{'errorString'} .= "\nError (WordNet::Similarity::lesk->_initialize()) - ";
	$self->{'errorString'} .= "No default relations file found.";
	$self->{'error'} = 2;
	return;
    }
    
    # initialize string compare module. No stemming in string
    # comparison, so put 0.
    &string_compare_initialize(0, %stopHash);

    # [trace]
    $self->{'traceString'} = "";
    $self->{'traceString'} .= "WordNet::Similarity::lesk object created:\n";
    $self->{'traceString'} .= "trace          :: ".($self->{'trace'})."\n" if(defined $self->{'trace'});
    $self->{'traceString'} .= "cache          :: ".($self->{'doCache'})."\n" if(defined $self->{'doCache'});
    $self->{'traceString'} .= "maxCacheSize   :: ".($self->{'maxCacheSize'})."\n" if(defined $self->{'maxCacheSize'});
    $self->{'traceString'} .= "stem           :: ".($self->{'doStem'})."\n" if(defined $self->{'doStem'});
    $self->{'traceString'} .= "normalize      :: ".($self->{'doNormalize'})."\n" if(defined $self->{'doNormalize'});
    $self->{'traceString'} .= "relation File  :: $relationFile\n" if($relationFile);
    $self->{'traceString'} .= "stop File      :: $stopFile\n" if($stopFile);
    # [/trace]
}


# The adapted Lesk relatedness measure subroutine ...
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
    my $gwi = $self->{'gwi'};

    # Check the existence of the WordNet::QueryData object.
    if(!$wn)
    {
	$self->{'errorString'} .= "\nError (WordNet::Similarity::lesk->getRelatedness()) - ";
	$self->{'errorString'} .= "A WordNet::QueryData object is required.";
	$self->{'error'} = 2;
	return undef;
    }

    # Initialize traces.
    $self->{'traceString'} = "" if($self->{'trace'});

    # Undefined input cannot go unpunished.
    if(!$wps1 || !$wps2)
    {
	$self->{'errorString'} .= "\nWarning (WordNet::Similarity::lesk->getRelatedness()) - Undefined input values.";
	$self->{'error'} = ($self->{'error'} < 1) ? 1 : $self->{'error'};
	return undef;
    }

    # Security check -- are the input strings in the correct format (word#pos#sense).
    if($wps1 !~ /^\S+\#([nvar])\#\d+$/)
    {
	$self->{'errorString'} .= "\nWarning (WordNet::Similarity::lesk->getRelatedness()) - ";
	$self->{'errorString'} .= "Input not in word\#pos\#sense format.";
	$self->{'error'} = ($self->{'error'} < 1) ? 1 : $self->{'error'};
	return undef;
    }
    if($wps2 !~ /^\S+\#([nvar])\#\d+$/)
    {
	$self->{'errorString'} .= "\nWarning (WordNet::Similarity::lesk->getRelatedness()) - ";
	$self->{'errorString'} .= "Input not in word\#pos\#sense format.";
	$self->{'error'} = ($self->{'error'} < 1) ? 1 : $self->{'error'};
	return undef;
    }

    # Now check if the similarity value for these two synsets is in
    # fact in the cache... if so return the cached value.
    if($self->{'doCache'} && defined $self->{'simCache'}->{"${wps1}::$wps2"})
    {
	$self->{'traceString'} = $self->{'traceCache'}->{"${wps1}::$wps2"} if($self->{'trace'});
	return $self->{'simCache'}->{"${wps1}::$wps2"};
    }

    # see if any traces reqd. if so, put in the synset arrays. 
    if($self->{'trace'})
    {
	# ah so we do need SOME traces! put in the synset names. 
	$self->{'traceString'}  = "Synset 1: $wps1\n";
	$self->{'traceString'} .= "Synset 2: $wps2\n";
    }
    
    # we shall put the first synset in a "set" of itself, and the
    # second synset in another "set" of itself. These sets may
    # increase in size as the functions are applied (since some
    # relations have a one to many mapping).
    
    # initialize the first set with the first synset
    my @firstSet = (); 
    push @firstSet, $wps1;
    
    # initialize the second set with the second synset
    my @secondSet = ();
    push @secondSet, $wps2;
    
    # initialize the score
    my $score = 0;
    
    # and now go thru the functions array, get the strings and do the scoring
    my $i = 0;
    my %overlaps;
    while(defined $self->{'functions'}->[$i])
    {
	my $functionsString = "";
	my $funcStringPrinted = 0;
	my $functionsScore = 0;
	
	# see if any traces reqd. if so, create the functions string
	# however don't send it to the trace string immediately - will
	# print it only if there are any overlaps for this rel pair
	if($self->{'trace'})
	{
	    $functionsString = "Functions: ";
	    my $j = 0;
	    while(defined $self->{'functions'}->[$i]->[0]->[$j])
	    {
		$functionsString .= ($self->{'functions'}->[$i]->[0]->[$j])." ";
		$j++;
	    }
	    
	    $functionsString .= "- ";
	    $j = 0;
	    while(defined $self->{'functions'}->[$i]->[1]->[$j])
	    {
		$functionsString .= ($self->{'functions'}->[$i]->[1]->[$j])." ";
		$j++;
	    }
	}
	
	# now get the string for the first set of synsets
	my @arguments = @firstSet;
	
	# apply the functions to the arguments, passing the output of
	# the inner functions to the inputs of the outer ones
	my $j = 0;
	no strict;

	while(defined $self->{'functions'}->[$i]->[0]->[$j])
	{
	    my $fn = $self->{'functions'}->[$i]->[0]->[$j];
	    @arguments = $gwi->$fn(@arguments);
	    $j++;
	}
	
	# finally we should have one cute little string!
	my $firstString = $arguments[0];
	
	# next do all this for the string for the second set
	@arguments = @secondSet;
	
	$j = 0;
	while(defined $self->{'functions'}->[$i]->[1]->[$j])
	{
	    my $fn = $self->{'functions'}->[$i]->[1]->[$j];
	    @arguments = $gwi->$fn(@arguments);
	    $j++;
	}
	
	my $secondString = $arguments[0];
	
	# so those are the two strings for this relation pair. get the
	# string overlaps
	undef %overlaps;
	%overlaps = &string_compare_getStringOverlaps($firstString, $secondString);
	
	# now get the number of words (discouting the markers) in
	# these two strings, if normalizing requested
	my $numWords1 = 0;
	my $numWords2 = 0;
	
	if($self->{'doNormalize'})
	{
	    $numWords1 = 0;
	    my $tempString = $firstString;
	    $tempString =~ s/^\s+//;
	    $tempString =~ s/\s+$//;
	    $tempString =~ s/\s+/ /g;
	    
	    foreach (split /\s+/, $tempString)
	    {
		next if(/EEE\d{5}EEE/);
		next if(/GGG\d{5}GGG/);
		next if(/SSS\d{5}SSS/);
		$numWords1++;
	    }
	    
	    $numWords2 = 0;
	    $tempString = $secondString;
	    $tempString =~ s/^\s+//;
	    $tempString =~ s/\s+$//;
	    $tempString =~ s/\s+/ /g;
	    
	    foreach (split /\s+/, $tempString)
	    {
		next if(/EEE\d{5}EEE/);
		next if(/GGG\d{5}GGG/);
		next if(/SSS\d{5}SSS/);
		$numWords2++;
	    }
	}
	
	my $overlapsTraceString = "";
	my $key;
	foreach $key (keys %overlaps)
	{
	    # find the length of the key, square it, multiply with its
	    # value and finally with the weight associated with this
	    # relation pair to get the score for this particular
	    # overlap.
	    
	    my @tempArray = split(/\s+/, $key);
	    my $value = ($#tempArray + 1) * ($#tempArray + 1) * $overlaps{$key};
	    $functionsScore += $value;
	    
	    # put this overlap into the trace string, if necessary
	    if($self->{'trace'} == 1)
	    {
		$overlapsTraceString .= "$overlaps{$key} x \"$key\"  ";
	    }
	}
	
	# normalize the function score computed above if required
	if($self->{'doNormalize'} && ($numWords1 * $numWords2))
	{
	    $functionsScore /= ($numWords1 * $numWords2);
	}
	
	# weight functionsScore with weight of this function
	$functionsScore *= $self->{'weights'}->[$i];
	
	# add to main score for this sense
	$score += $functionsScore;
	
	# if we have an overlap, send functionsString, functionsScore
	# and overlapsTraceString to trace string, if trace string requested
	if($self->{'trace'} == 1 && $overlapsTraceString ne "")
	{
	    $self->{'traceString'} .= "$functionsString: $functionsScore\n";
	    $funcStringPrinted = 1;
	    
	    $self->{'traceString'} .= "Overlaps: $overlapsTraceString\n";
	}
	
	# check if the two strings need to be reported in the trace.
	if($self->{'trace'} == 2)
	{
	    if(!$funcStringPrinted)
	    {
		$self->{'traceString'} .= "$functionsString";
		$funcStringPrinted = 1;
	    }
	    
	    $self->{'traceString'} .= "String 1: \"$firstString\"\n";
	    $self->{'traceString'} .= "String 2: \"$secondString\"\n";
	}
	
	$i++;
    }
    
    # that does all the scoring. Put in cache if doing cacheing. Then
    # return the score.    
    if($self->{'doCache'})
    {
	$self->{'simCache'}->{"${wps1}::$wps2"} = $score;
	$self->{'traceCache'}->{"${wps1}::$wps2"} = $self->{'traceString'} if($self->{'trace'});
	push(@{$self->{'cacheQ'}}, "${wps1}::$wps2");
	if($self->{'maxCacheSize'} >= 0)
	{
	    while(scalar(@{$self->{'cacheQ'}}) > $self->{'maxCacheSize'})
	    {
		my $delItem = shift(@{$self->{'cacheQ'}});
		delete $self->{'simCache'}->{$delItem};
		delete $self->{'traceCache'}->{$delItem};
	    }
	}
    }
    
    return $score;
}


# Function to return the current trace string
sub getTraceString
{
    my $self = shift;
    my $returnString = $self->{'traceString'}."\n";
    $self->{'traceString'} = "" if($self->{'trace'});
    $returnString =~ s/\n+$/\n/;
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


1;
__END__

=head1 NAME

WordNet::Similarity::lesk - Perl module for computing semantic relatedness
of word senses using gloss overlaps as described by Banerjee and Pedersen 
(2002) -- a method that adapts the Lesk approach to WordNet.

=head1 SYNOPSIS

  use WordNet::Similarity::lesk;

  use WordNet::QueryData;

  my $wn = WordNet::QueryData->new();

  my $lesk = WordNet::Similarity::lesk->new($wn);

  my $value = $lesk->getRelatedness("car#n#1", "bus#n#2");

  ($error, $errorString) = $lesk->getError();

  die "$errorString\n" if($error);

  print "car (sense 1) <-> bus (sense 2) = $value\n";

=head1 DESCRIPTION

Lesk (1985) proposed that the relatedness of two words is proportional to
to the extent of overlaps of their dictionary definitions. Banerjee and 
Pedersen (2002) extended this notion to use WordNet as the dictionary
for the word definitions. This notion was further extended to use the rich
network of relationships between concepts present is WordNet. This adapted
lesk measure has been implemented in this module.

=head1 USAGE

The semantic relatedness modules in this distribution are built as classes
that expose the following methods:
  new()
  getRelatedness()
  getError()
  getTraceString()

See the WordNet::Similarity(3) documentation for details of these methods.

=head1 TYPICAL USAGE EXAMPLES

To create an object of the lesk measure, we would have the following
lines of code in the Perl program. 

   use WordNet::Similarity::lesk;
   $measure = WordNet::Similarity::lesk->new($wn, '/home/sid/lesk.conf');

The reference of the initialized object is stored in the scalar variable
'$measure'. '$wn' contains a WordNet::QueryData object that should have been
created earlier in the program. The second parameter to the 'new' method is
the path of the configuration file for the lesk measure. If the 'new'
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
specified as a parameter during the creation of an object using the new
method. The configuration files must follow a fixed format.

Every configuration file starts with the name of the module ON THE FIRST LINE of
the file. For example, a configuration file for the lesk module will have
on the first line 'WordNet::Similarity::lesk'. This is followed by the various
parameters, each on a new line and having the form 'name::value'. The
'value' of a parameter is optional (in case of boolean parameters). In case
'value' is omitted, we would have just 'name::' on that line. Comments are
supported in the configuration file. Anything following a '#' is ignored till
the end of the line.

The module parses the configuration file and recognizes the following 
parameters:
  
(a) 'trace::' -- The value of this parameter specifies the level of
tracing that should be employed for generating the traces. This value
is an integer 0, 1 or 2. A value of 0 switches tracing off. A value of
1 displays as traces only the gloss overlaps found. A value of 2 displays
as traces, all the text being compared.
  
(b) 'cache::' -- can take values 0 or 1 or the value can be omitted, in 
which case it takes the value 1, i.e. switches 'on' caching. A value of 
0 switches caching 'off'. By default caching is enabled.
  
(c) 'relation::' -- The value is a filename (with complete path) of a file
that contains a list of WordNet-relations. The vector module combines the
glosses of synsets related to the target synsets by these relations, and 
forms the gloss-vector from this combined gloss. The format of the relation
file is specified later in the documentation.

(d) 'stop::' -- The value is a string that specifies the path of a file 
containing a list of stop words that should be ignored for the gloss
overlaps.
  
(e) 'stem::' -- can take values 0 or 1 or the value can be omitted, in 
which case it takes the value 1, i.e. switches 'on' stemming. A value of 
0 switches stemming 'off'. When stemming is enabled, all the words of the
glosses are stemmed before their overlaps are determined.
  
(f) 'normalize::' -- can take values 0 or 1 or the value can be omitted, in 
which case it takes the value 1, i.e. switches 'on' normalizing of the score. 
A value of 0 switches normalizing 'off'. When normalizing is enabled, the 
score obtained by counting the gloss overlaps is normalized by the size
of the glosses. The details are described in Banerjee Pedersen (2002).

(g) 'maxCacheSize::' -- takes a non-negative integer value. The value indicates
the size of the cache, used for storing the computed relatedness value.

=head1 RELATION FILE FORMAT

The relation file starts with the string "LeskRelationFile" on the first line
of the file. Following this, on each consecutive line, a relation is specified
in the form -- 

func(func(func... (func)...))-func(func(func... (func)...)) [weight]

Where "func" can be any one of the following functions:

hype() = Hypernym of
hypo() = Hyponym of
holo() = Holonym of
mero() = Meronym of
attr() = Attribute of
also() = Also see
sim() = Similar
enta() = Entails
caus() = Causes
part() = Particle
pert() = Pertainym of
glos = gloss (without example)
example = example (from the gloss)
glosexample = gloss + example
syns = synset of the concept

Each of these specifies a WordNet relation. And the outermost function in the
nesting can only be one of glos, example, glosexample or syns. The set of functions 
to the left of the "-" are applied to the first word sense. The functions to the 
right of the "-" are applied to the second word sense. An optional weight can be 
specified to weigh the contribution of that relation in the overall score.

For example,

glos(hype(hypo))-example(hype) 0.5

means that the gloss of the hypernym of the hyponym of the first synset is overlapped
with the example of the hypernym of the second synset to get the lesk score. This 
score is weighted 0.5. If "glos", "example", "glosexample" or "syns" is not provided 
as the outermost function of the nesting, the measure assumes "glos" as the default.
So,

glos(hypo(also))-glos(holo(attr))

and

hypo(also)-holo(attr)

are treated the same by the measure.

=head1 SEE ALSO

perl(1), WordNet::Similarity(3), WordNet::QueryData(3)

http://www.cs.utah.edu/~sidd

http://www.cogsci.princeton.edu/~wn

http://www.ai.mit.edu/~jrennie/WordNet

http://groups.yahoo.com/group/wn-similarity

=head1 AUTHORS

  Satanjeev Banerjee,  <banerjee+@cs.cmu.edu>
  Ted Pedersen, <tpederse@d.umn.edu>
  Siddharth Patwardhan, <sidd@cs.utah.edu>

=head1 COPYRIGHT AND LICENSE

Copyright 2003 by Satanjeev Banerjee, Ted Pedersen and Siddharth Patwardhan 

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
