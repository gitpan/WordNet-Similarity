# WordNet::Similarity::jcn.pm version 0.06
# (Updated 10/10/2003 -- Sid)
#
# Semantic Similarity Measure package implementing the measure 
# described by Jiang and Conrath (1997).
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


package WordNet::Similarity::jcn;

use strict;

use Exporter;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

@ISA = qw(Exporter);

%EXPORT_TAGS = ();

@EXPORT_OK = ();

@EXPORT = ();

$VERSION = '0.06';


# 'new' method for the jcn class... creates and returns a WordNet::Similarity::jcn object.
# INPUT PARAMS  : $className  .. (WordNet::Similarity::jcn) (required)
#                 $wn         .. The WordNet::QueryData object (required).
#                 $configFile .. Name of the config file for getting the parameters (optional).
# RETURN VALUE  : $jcn        .. The newly created jcn object.
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
	$self->{'errorString'} .= "\nError (WordNet::Similarity::jcn->new()) - ";
	$self->{'errorString'} .= "A WordNet::QueryData object is required.";
	$self->{'error'} = 2;
    }

    # Bless object, initialize it and return it.
    bless($self, $className);
    $self->_initialize(shift) if($self->{'error'} < 2);

    return $self;
}


# Initialization of the WordNet::Similarity::jcn object... parses the config file and sets up 
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
    $self->{'cacheQ'} = ();
    $self->{'maxCacheSize'} = 1000;
    
    # Initialize tracing.
    $self->{'trace'} = 0;

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
	    if($modname =~ /^WordNet::Similarity::jcn/)
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
		    elsif(/^infocontent::(.*)/)
		    {
			$infoContentFile = $1;
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
			$self->{'errorString'} .= "\nWarning (WordNet::Similarity::jcn->_initialize()) - ";
			$self->{'errorString'} .= "Unrecognized parameter '$_'. Ignoring.";
			$self->{'error'} = 1;
		    }
		}
	    }
	    else
	    {
		$self->{'errorString'} .= "\nError (WordNet::Similarity::jcn->_initialize()) - ";
		$self->{'errorString'} .= "$paramFile does not appear to be a config file.";
		$self->{'error'} = 2;
		return;
	    }
	    close(PARAM);
	}
	else
	{
	    $self->{'errorString'} .= "\nError (WordNet::Similarity::jcn->_initialize()) - ";
	    $self->{'errorString'} .= "Unable to open config file $paramFile.";
	    $self->{'error'} = 2;
	    return;
	}
    }

    # Look for the default infocontent file if not specified by the user.
    # Search the @INC path in WordNet/Similarity.
    if(!(defined $infoContentFile))
    {
	my $path;
	my $wnver;
	my @possiblePaths = ();

	# Look for all possible default data files installed.
	foreach $path (@INC)
	{
	    if(-e $path."/WordNet/infocontent.dat")
	    {
		push @possiblePaths, $path."/WordNet/infocontent.dat";
	    }
	    elsif(-e $path."\\WordNet\\infocontent.dat")
	    {
		push @possiblePaths, $path."\\WordNet\\infocontent.dat";
	    }
	}
	
	# If there are multiple possibilities, get the one that matches the
	# the installed version of WordNet.
	foreach $path (@possiblePaths)
	{
	    if(open(INFOCONTENT, $path))
	    {
		$wnver = <INFOCONTENT>;
		$wnver =~ s/[\r\f\n]//g;
		$wnver =~ s/\s+//g;
		if($wnver =~ /wnver::(.*)/)
		{
		    $wnver = $1;
		    if(defined $wnver && $wnver eq $wn->version())
		    {
			$infoContentFile = $path;
			close(INFOCONTENT);
			last;
		    }
		}
		close(INFOCONTENT);
	    }
	}
    }

    # Load the information content data.
    if($infoContentFile)
    {
	my $wnver;
	my $offsetPOS;
	my $frequency;
	my $topmost;

	if(open(INFOCONTENT, $infoContentFile))
	{
	    $wnver = <INFOCONTENT>;
	    $wnver =~ s/[\r\f\n]//g;
	    $wnver =~ s/\s+//g;
	    if($wnver =~ /wnver::(.*)/)
	    {
		$wnver = $1;
		if(defined $wnver && $wnver eq $wn->version())
		{
		    $self->{'offsetFreq'}->{"n"}->{0} = 0;
		    $self->{'offsetFreq'}->{"v"}->{0} = 0;
		    while(<INFOCONTENT>)
		    {
			s/[\r\f\n]//g;
			s/^\s+//;
			s/\s+$//;
			($offsetPOS, $frequency, $topmost) = split /\s+/, $_, 3;
			if($offsetPOS =~ /([0-9]+)([nvar])/)
			{
			    my $curOffset;
			    my $curPOS;
			    
			    $curOffset = $1;
			    $curPOS = $2;
			    $self->{'offsetFreq'}->{$curPOS}->{$curOffset} = $frequency;
			    if(defined $topmost && $topmost =~ /ROOT/)
			    {
				$self->{'offsetFreq'}->{$curPOS}->{0} += $self->{'offsetFreq'}->{$curPOS}->{$curOffset};
			    }
			}
			else
			{
			    $self->{'errorString'} .= "\nError (WordNet::Similarity::jcn->_initialize()) - ";
			    $self->{'errorString'} .= "Bad file format ($infoContentFile).";
			    $self->{'error'} = 2;
			    return;
			}
		    }
		}
		else
		{
		    $self->{'errorString'} .= "\nError (WordNet::Similarity::jcn->_initialize()) - ";
		    $self->{'errorString'} .= "WordNet version does not match data file.";
		    $self->{'error'} = 2;
		    return;
		}
	    }
	    else
	    {
		$self->{'errorString'} .= "\nError (WordNet::Similarity::jcn->_initialize()) - ";
		$self->{'errorString'} .= "Bad file format ($infoContentFile).";
		$self->{'error'} = 2;
		return;		
	    }
	    close(INFOCONTENT);   
	}
	else
	{
	    $self->{'errorString'} .= "\nError (WordNet::Similarity::jcn->_initialize()) - ";
	    $self->{'errorString'} .= "Unable to open $infoContentFile.";
	    $self->{'error'} = 2;
	    return;
	}
    }
    else
    {
	$self->{'errorString'} .= "\nError (WordNet::Similarity::jcn->_initialize()) - ";
	$self->{'errorString'} .= "No default information content file found.";
	$self->{'error'} = 2;
	return;
    }

    # [trace]
    $self->{'traceString'} = "";
    $self->{'traceString'} .= "WordNet::Similarity::jcn object created:\n";
    $self->{'traceString'} .= "trace :: ".($self->{'trace'})."\n" if(defined $self->{'trace'});
    $self->{'traceString'} .= "cache :: ".($self->{'doCache'})."\n" if(defined $self->{'doCache'});
    $self->{'traceString'} .= "information content file :: $infoContentFile\n" if(defined $infoContentFile);
    $self->{'traceString'} .= "Cache Size :: ".($self->{'maxCacheSize'})."\n" if(defined $self->{'maxCacheSize'});
    # [/trace]

    # Check for a strange Root_Node_Frequency=0 condition. Normally, not possible.
    if(!($self->{'offsetFreq'}->{"n"}->{0}))
    {
	$self->{'offsetFreq'}->{"n"}->{0} = 1;	
	$self->{'errorString'} .= "\nError (WordNet::Similarity::jcn->_initialize()) - ";
	$self->{'errorString'} .= "Noun root node freqeuncy 0. Something's amiss. (no 'ROOT' tags in infocontent file?)";
	$self->{'error'} = 2;
    }
    if(!($self->{'offsetFreq'}->{"v"}->{0}))
    {
	$self->{'offsetFreq'}->{"v"}->{0} = 1;
	$self->{'errorString'} .= "\nError (WordNet::Similarity::jcn->_initialize()) - ";
	$self->{'errorString'} .= "Verb root node freqeuncy 0. Something's amiss. (no 'ROOT' tags in infocontent file?)";
	$self->{'error'} = 2;
    }
}

# The Jiang-Conrath relatedness measure subroutine ...
# INPUT PARAMS  : $wps1     .. one of the two wordsenses.
#                 $wps2     .. the second wordsense of the two whose 
#                              semantic relatedness needs to be measured.
# RETURN VALUES : $distance .. the semantic relatedness between the two wordsenses.
#              or undef     .. in case of an error.
sub getRelatedness
{
    my $self = shift;
    my $wps1 = shift;
    my $wps2 = shift;
    my $wn = $self->{'wn'};
    my $ic1;
    my $ic2;
    my $ic3;
    my $pos;
    my $pos1;
    my $pos2;
    my $offset;
    my $offset1;
    my $offset2;
    my $root;
    my $dist;
    my $minDist;
    my $score;
    my $onceFlag;
    my @retArray;

    # Check the existence of the WordNet::QueryData object.
    if(!$wn)
    {
	$self->{'errorString'} .= "\nError (WordNet::Similarity::jcn->getRelatedness()) - ";
	$self->{'errorString'} .= "A WordNet::QueryData object is required.";
	$self->{'error'} = 2;
	return undef;
    }

    # Initialize traces.
    $self->{'traceString'} = "" if($self->{'trace'});

    # Undefined input cannot go unpunished.
    if(!$wps1 || !$wps2)
    {
	$self->{'errorString'} .= "\nWarning (WordNet::Similarity::jcn->getRelatedness()) - Undefined input values.";
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
	$self->{'errorString'} .= "\nWarning (WordNet::Similarity::jcn->getRelatedness()) - ";
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
	$self->{'errorString'} .= "\nWarning (WordNet::Similarity::jcn->getRelatedness()) - ";
	$self->{'errorString'} .= "Input not in word\#pos\#sense format.";
	$self->{'error'} = ($self->{'error'} < 1) ? 1 : $self->{'error'};
	return undef;
    }

    # Relatedness is 0 across parts of speech.
    if($pos1 ne $pos2)
    {
	$self->{'traceString'} = "Relatedness 0 across parts of speech ($wps1, $wps2).\n" if($self->{'trace'});
	return 0;
    }
    $pos = $pos1;

    # Relatedness is defined only for nouns and verbs.
    if($pos !~ /[nv]/)
    {
	$self->{'traceString'} = "Only verbs and nouns have hypernym trees ($wps1, $wps2).\n" if($self->{'trace'});
	return 0;
    }

    # Now check if the similarity value for these two synsets is in
    # fact in the cache... if so return the cached value.
    if($self->{'doCache'} && defined $self->{'simCache'}->{"${wps1}::$wps2"})
    {
	if(defined $self->{'traceCache'}->{"${wps1}::$wps2"})
	{
	    $self->{'traceString'} = $self->{'traceCache'}->{"${wps1}::$wps2"} if($self->{'trace'});
	}
	return $self->{'simCache'}->{"${wps1}::$wps2"};
    }

    # Now get down to really finding the relatedness of these two.
    $offset1 = $wn->offset($wps1);
    $offset2 = $wn->offset($wps2);
    $self->{'traceString'} = "" if($self->{'trace'});

    if(!$offset1 || !$offset2)
    {
	$self->{'errorString'} .= "\nWarning (WordNet::Similarity::jcn->getRelatedness()) - ";
	$self->{'errorString'} .= "Input senses not found in WordNet.";
	$self->{'error'} = ($self->{'error'} < 1) ? 1 : $self->{'error'};
	return undef;
    }
    @retArray = $self->_getLeastCommonSubsumers($offset1, $offset2, $pos);

    # [trace]
    if($self->{'trace'})
    {
	$self->{'traceString'} .= "Lowest Common Subsumer(s): ";
	foreach $offset (@retArray)
	{
	    if(defined $offset && $offset =~ /^[0-9]+$/ && $offset != 0)
	    {
		$self->{'traceString'} .= $wn->getSense($offset, $pos);
		$self->{'traceString'} .= " (Freq=";
		if($self->{'offsetFreq'}->{$pos}->{$offset})
		{
		    $self->{'traceString'} .= $self->{'offsetFreq'}->{$pos}->{$offset};
		}
		else
		{
		    $self->{'traceString'} .= "0";
		}
		$self->{'traceString'} .= ")  ";
	    }
	    else
	    {
		$self->{'traceString'} .= "*Root* (Freq=";
		if($self->{'offsetFreq'}->{$pos}->{0})
		{
		    $self->{'traceString'} .= $self->{'offsetFreq'}->{$pos}->{0};
		}
		else
		{
		    $self->{'traceString'} .= "0";
		}
		$self->{'traceString'} .= ")  ";
	    }
	}
	$self->{'traceString'} .= "\nConcept1: $wps1 (Freq=";
	if($self->{'offsetFreq'}->{$pos}->{$offset1})
	{
	    $self->{'traceString'} .= $self->{'offsetFreq'}->{$pos}->{$offset1};
	}
	else
	{
	    $self->{'traceString'} .= "0";
	}
	$self->{'traceString'} .= ")\n";
	$self->{'traceString'} .= "Concept2: $wps2 (Freq=";
	if($self->{'offsetFreq'}->{$pos}->{$offset2})
	{
	    $self->{'traceString'} .= $self->{'offsetFreq'}->{$pos}->{$offset2};
	}
	else
	{
	    $self->{'traceString'} .= "0";
	}
	$self->{'traceString'} .= ")\n\n";
    }
    # [/trace]

    # Check for the rare possibility of the root node having 0
    # frequency count... 
    # If normal (i.e. freqCount(root) > 0)... Set the minimum distance to the
    # greatest distance possible + 1... (my replacement for infinity)...
    # If zero root frequency count... return 0 relatedness, with a warning...
    if($self->{'offsetFreq'}->{$pos}->{0})
    {
	$minDist = (2*(-log(0.001/($self->{'offsetFreq'}->{$pos}->{0})))) + 1;
    }
    else
    {
	$self->{'errorString'} .= "\nWarning (WordNet::Similarity::jcn->getRelatedness()) - ";
	$self->{'errorString'} .= "Root node has a zero frequency count.";
	$self->{'error'} = ($self->{'error'} < 1) ? 1 : $self->{'error'};
	return 0;
    }

    # Foreach lowest common subsumer...
    # Find the minimum jcn distance between the two subsuming concepts...
    # Making sure that neither of the 2 concepts have 0 infocontent
    $ic1 = $self->IC($offset1, $pos); 
    $ic2 = $self->IC($offset2, $pos);

    # If either of the two concepts have a zero information content... 
    # return 0, for lack of data...
    if($ic1 && $ic2)
    {
	foreach $root (@retArray)
	{
	    $ic3 = $self->IC($root, $pos);

	    $dist = $ic1 + $ic2 - (2 * $ic3);
	    $minDist = $dist if($dist < $minDist);
	}
    }
    else
    {
	return 0;
    }
    
    # Now if minDist turns out to be 0...
    # implies ic1 == ic2 == ic3 (most probably all three represent
    # the same concept)... i.e. maximum relatedness... i.e. infinity...
    # We'll return the maximum possible value ("Our infinity").
    # Here's how we got our infinity...
    # distance = ic1 + ic2 - (2 x ic3)
    # Largest possible value for (1/distance) is infinity, when distance = 0.
    # That won't work for us... Whats the next value on the list... 
    # the smallest value of distance greater than 0... 
    # Consider the formula again... distance = ic1 + ic2 - (2 x ic3)
    # We want the value of distance when ic1 or ic2 have information content 
    # slightly more than that of the root (ic3)... (let ic2 == ic3 == 0)
    # Assume frequency counts of 0.01 less than the frequency count of the 
    # root for computing ic1...
    # sim = 1/ic1
    # sim = 1/(-log((freq(root) - 0.01)/freq(root)))
    if($minDist == 0)
    {
	if($self->{'offsetFreq'}->{$pos}->{0} && $self->{'offsetFreq'}->{$pos}->{0} > 0.01)
	{
	    $score = 1/(-log(($self->{'offsetFreq'}->{$pos}->{0} - 0.01)/($self->{'offsetFreq'}->{$pos}->{0})));

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
	else
	{
	    return 0;
	}
    }

    $score = ($minDist != 0) ? (1/$minDist) : 0;

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
    my $returnString = $self->{'traceString'};
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


# Subroutine that returns the probability of occurrence of a concept
# in a large corpus (using frequency values from information content file)...
# INPUT PARAMS  : $con   .. the concept -- synset offet.
#               : $pos   .. the part of speech.
# RETURN VALUES : $prob  .. floating point value (freq/rootFreq ... from corpus)
sub _probability
{
    my $self = shift;
    my $con = shift;
    my $pos = shift;
    
    if($self->{'offsetFreq'}->{$pos}->{0} && defined $self->{'offsetFreq'}->{$pos}->{$con})
    {
	if($self->{'offsetFreq'}->{$pos}->{$con} <= $self->{'offsetFreq'}->{$pos}->{0})
	{
	    return ($self->{'offsetFreq'}->{$pos}->{$con})/($self->{'offsetFreq'}->{$pos}->{0});
	}
	else
	{
	    $self->{'errorString'} .= "\nError (WordNet::Similarity::jcn->_probability()) - ";
	    $self->{'errorString'} .= "Probability greater than 1? (Check information content file)";
	    $self->{'error'} = 2;
	    return 0;
	}
    }
    else
    {
	return 0;
    }
}


# Subroutine that returns the Information Content of a concept (synset offset)
# INPUT PARAMS  : $offset  .. the synset offset.
#               : $pos     .. part of speech.
# RETURN VALUES : $ic      .. information content.
sub IC
{
    my $self = shift;
    my $offset = shift;
    my $pos = shift;
    if($pos =~ /[nv]/)
    {
	my $prob = $self->_probability($offset, $pos);
	return ($prob > 0)?-log($prob):0;
    }
    return 0;
}


# Subroutine to get the Least Common Subsumers (one for each pair of 
# hypernym trees) of two synset offsets in the Noun/Verb Taxonomies.
# INPUT PARAMS  : $lOffset .. first offset
#                 $rOffset .. second offset
#                 $pos     .. part of speech
# RETRUN VALUES : @lCSOffsets .. array of Offsets of the Least Common 
#                                Subsumers.
sub _getLeastCommonSubsumers
{
    my $self;
    my $lOffset;
    my $rOffset;
    my $pos;
    my $lTree;
    my $rTree;
    my $offset;
    my @retArray;
    my @lTrees;
    my @rTrees;
    my %retHash;

    $self = shift;
    $lOffset = shift;
    $rOffset = shift;
    $pos = shift;
    @lTrees = &getHypernymTrees($self->{'wn'}, $lOffset, $pos);
    foreach $lTree (@lTrees)
    {
	push @{$lTree}, $lOffset;
    }
    @rTrees = &getHypernymTrees($self->{'wn'}, $rOffset, $pos);
    foreach $rTree (@rTrees)
    {
	push @{$rTree}, $rOffset;
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

    %retHash = ();
    foreach $lTree (@lTrees)
    {
	foreach $rTree (@rTrees)
	{
	    $offset = &getLCSfromTrees($lTree, $rTree);
	    $retHash{$offset} = 1;
	}
    }
    @retArray = keys %retHash;

    return @retArray;
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
# or offsets(POS) and for each prints to traceString the 
# WORD#POS#(<SENSE>/<OFFSET>)
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
    $self->{'traceString'} .= $opstr if($self->{'trace'});
}

1;
__END__

=head1 NAME

WordNet::Similarity::jcn - Perl module for computing semantic relatedness
of word senses according to the method described by Jiang and Conrath
(1997).

=head1 SYNOPSIS

  use WordNet::Similarity::jcn;

  use WordNet::QueryData;

  my $wn = WordNet::QueryData->new();

  my $rel = WordNet::Similarity::jcn->new($wn);

  my $value = $rel->getRelatedness("car#n#1", "bus#n#2");

  ($error, $errorString) = $rel->getError();

  die "$errorString\n" if($error);

  print "car (sense 1) <-> bus (sense 2) = $value\n";

=head1 DESCRIPTION

This module computes the semantic relatedness of word senses according to
the method described by Jiang and Conrath (1997). This measure is based on 
a combination of using edge counts in the WordNet 'is-a' hierarchy and 
using the information content values of the WordNet concepts, as described 
in the paper by Jiang and Conrath. Their measure, however, computes values
that indicate the semantic distance between words (as opposed to their 
semantic relatedness). In this implementation of the measure we invert the
value so as to obtain a measure of semantic relatedness. Other issues that
arise due to this inversion (such as handling of zero values in the 
denominator) have been taken care of as special cases.

=head1 USAGE

The semantic relatedness modules in this distribution are built as classes
that expose the following methods:
  new()
  getRelatedness()
  getError()
  getTraceString()

See the WordNet::Similarity(3) documentation for details of these methods.

=head1 TYPICAL USAGE EXAMPLES

To create an object of the jcn measure, we would have the following
lines of code in the Perl program. 

   use WordNet::Similarity::jcn;
   $measure = WordNet::Similarity::jcn->new($wn, '/home/sid/jcn.conf');

The reference of the initialized object is stored in the scalar variable
'$measure'. '$wn' contains a WordNet::QueryData object that should have been
created earlier in the program. The second parameter to the 'new' method is
the path of the configuration file for the jcn measure. If the 'new'
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
the file. For example, a configuration file for the jcn module will have
on the first line 'WordNet::Similarity::jcn'. This is followed by the various
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
  
(c) 'infocontent::' -- The value for this parameter should be a string that
specifies the path of an information content file containing the 
frequency of occurrence of every WordNet concept in a large corpus. The
format of this file is specified in a later section.

(d) 'maxCacheSize::' -- takes a non-negative integer value. The value indicates
the size of the cache, used for storing the computed relatedness value.

=head1 INFORMATION CONTENT

Three of the measures provided within the package require information
content values of concepts (WordNet synsets) for computing the semantic
relatedness of concepts. Resnik (1995) describes a method for computing the
information content of concepts from large corpora of text. In order to
compute information content of concepts, according to the method described
in the paper, we require the frequency of occurrence of every concept in a
large corpus of text. We provide these frequency counts to the three
measures (Resnik, Jiang-Conrath and Lin measures) in files that we call
information content files. These files contain a list of WordNet synset
offsets along with their part of speech and frequency count. This may be 
followed by a 'ROOT' tag if the synset is the root of the taxonomy in WordNet. 
The information content file to be used is specified in the configuration file
for the measure. If no information content file is specified, then the
default information content file, generated at the time of the installation
of the WordNet::Similarity modules, is used. A description of the format of
these files follows. The FIRST LINE of this file MUST contain the version
of WordNet that the file was created with. This should be present as a string 
of the form 

  wnver::<version>

For example, if WordNet version 1.7.1 was used for creation of the
information content file, the following line would be present at the start
of the information content file.

  wnver::1.7.1

The rest of the file contains on each line, a WordNet synset offset, 
part-of-speech and a frequency count, of the form

  <offset><part-of-speech> <frequency> [ROOT]

without any leading or trailing spaces. For example, one of the lines of an
information content file may be as follows.

  63723n 667

where '63723' is a noun synset offset and 667 is its frequency
count. If a synset with offset 1740 is the root of a noun 'is-a' taxonomy in
WordNet and its frequency count is 17265, it will appear in the information 
content file as follows:

  1740n 17265 ROOT

The ROOT tags are extremely significant in determining the top of the 
hierarchies and must not be omitted. Typically, frequency counts for the noun
and verb hierarchies are present in each information content file.

=head1 SEE ALSO

perl(1), WordNet::Similarity(3), WordNet::QueryData(3)

http://www.cs.utah.edu/~sidd

http://www.cogsci.princeton.edu/~wn

http://www.ai.mit.edu/~jrennie/WordNet

http://groups.yahoo.com/group/wn-similarity

=head1 AUTHORS

  Siddharth Patwardhan, <sidd@cs.utah.edu>
  Ted Pedersen, <tpederse@d.umn.edu>

=head1 COPYRIGHT AND LICENSE

Copyright 2003 by Siddharth Patwardhan and Ted Pedersen

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
