# WordNet::Similarity::vector.pm version 0.06
# (Updated 10/10/2003 -- Sid)
#
# Module to accept two WordNet synsets and to return a floating point
# number that indicates how similar those two synsets are, using a
# gloss vector overlap measure based on "context vectors" described by 
# Schütze (1998).
#
# Copyright (c) 2003,
#
# Siddharth Patwardhan, University of Utah, Salt Lake City
# sidd@cs.utah.edu
#
# Ted Pedersen, University of Minnesota, Duluth
# tpederse@d.umn.edu
#
# Satanjeev Banerjee, Carnegie Mellon University, Pittsburgh
# banerjee+@cs.cmu.edu
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


package WordNet::Similarity::vector;

use strict;
# use PDL;
use Exporter;
use get_wn_info;
use stem;
use dbInterface;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

@ISA = qw(Exporter);

%EXPORT_TAGS = ();

@EXPORT_OK = ();

@EXPORT = ();

$VERSION = '0.06';


# 'new' method for the vector class... creates and returns a WordNet::Similarity::vector object.
# INPUT PARAMS  : $className  .. (WordNet::Similarity::vector) (required)
#                 $wn         .. The WordNet::QueryData object (required).
#                 $configFile .. Name of the config file for getting the parameters (optional).
# RETURN VALUE  : $vector     .. The newly created vector object.
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
	$self->{'errorString'} .= "\nError (WordNet::Similarity::vector->new()) - ";
	$self->{'errorString'} .= "A WordNet::QueryData object is required.";
	$self->{'error'} = 2;
    }

    # Bless object, initialize it and return it.
    bless($self, $className);
    $self->_initialize(shift) if($self->{'error'} < 2);

    return $self;
}


# Initialization of the WordNet::Similarity::vector object... parses the config file and sets up 
# global variables, or sets them to default values.
# INPUT PARAMS  : $paramFile .. File containing the module specific params.
# RETURN VALUES : (none)
sub _initialize
{
    my $self;
    my $paramFile;
    my $relationFile;
    my $stopFile;
    my $compFile;
    my $vectorDB;
    my $documentCount;
    my $wn;
    my $gwi;
    my $db;
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
    $self->{'vCache'} = ();
    $self->{'vCacheQ'} = ();
    $self->{'vCacheSize'} = 80;
    
    # Initialize tracing.
    $self->{'trace'} = 0;
    $self->{'traceString'} = "";

    # Stemming? Cutoff? Compounds?
    $self->{'doStem'} = 0;
#   $self->{'cutoff'} = -1;
    $self->{'compounds'} = {};
    $self->{'stopHash'} = {};

    # Parse the config file and
    # read parameters from the file.
    # Looking for params --> 
    # trace, infocontent file, cache
    if(defined $paramFile)
    {
	my $modname;
	
	if(!open(PARAM, $paramFile))
	{
	    $self->{'errorString'} .= "\nError (WordNet::Similarity::vector->_initialize()) - ";
	    $self->{'errorString'} .= "Unable to open config file $paramFile.";
	    $self->{'error'} = 2;
	    return;
	}
	$modname = <PARAM>;
	$modname =~ s/[\r\f\n]//g;
	$modname =~ s/\s+//g;
	if($modname !~ /^WordNet::Similarity::vector/)
	{
	    close PARAM;
	    $self->{'errorString'} .= "\nError (WordNet::Similarity::vector->_initialize()) - ";
	    $self->{'errorString'} .= "$paramFile does not appear to be a config file.";
	    $self->{'error'} = 2;
	    return;
	}
	while(<PARAM>)
	{
	    s/[\r\f\n]//g;
	    s/\#.*//;
	    s/\s+//g;
	    if(/^trace::(.*)/)
	    {
		my $tmp = $1;
		$self->{'trace'} = 1;
		$self->{'trace'} = $tmp if($tmp =~ /^[01]$/);
	    }
	    elsif(/^relation::(.*)/)
	    {
		$relationFile = $1;
	    }
	    elsif(/^vectordb::(.*)/)
	    {
		$vectorDB = $1;
	    }
	    elsif(/^stop::(.*)/)
	    {
		$stopFile = $1;
	    }
	    elsif(/^compounds::(.*)/)
	    {
		$compFile = $1;
	    }
	    elsif(/^stem::(.*)/)
	    {
		my $tmp = $1;
		$self->{'doStem'} = 1;
		$self->{'doStem'} = $tmp if($tmp =~ /^[01]$/);
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
#	    elsif(/^cutoff::(.*)/)
#	    {
#		my $tmp = $1;
#		$self->{'cutoff'} = $tmp if($tmp =~ /^(([0-9]+(\.[0-9]+)?)|(\.[0-9]+))$/);
#	    }
	    elsif($_ ne "")
	    {
		s/::.*//;
		$self->{'errorString'} .= "\nWarning (WordNet::Similarity::vector->_initialize()) - ";
		$self->{'errorString'} .= "Unrecognized parameter '$_'. Ignoring.";
		$self->{'error'} = 1;
	    }
	}
	close(PARAM);
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
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/_/g;
		$stopHash{$line} = 1;
		$self->{'stopHash'}->{$line} = 1;
	    }
	    close(STOP);   
	}
	else
	{
	    $self->{'errorString'} .= "\nWarning (WordNet::Similarity::vector->_initialize()) - ";
	    $self->{'errorString'} .= "Unable to open $stopFile.";
	    $self->{'error'} = ($self->{'error'} < 1) ? 1 : $self->{'error'};
	}
    }

    # Load the compounds.
    if($compFile)
    {
	my $line;

	if(open(COMP, $compFile))
	{
	    while($line = <COMP>)
	    {
		$line =~ s/[\r\f\n]//g;
		$line =~ s/^\s+//;
		$line =~ s/\s+$//;
		$line =~ s/\s+/_/g;
		$self->{'compounds'}->{$line} = 1;		
	    }
	    close(COMP);   
	}
	else
	{
	    $self->{'errorString'} .= "\nWarning (WordNet::Similarity::vector->_initialize()) - ";
	    $self->{'errorString'} .= "Unable to open $compFile.";
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

    # Initialize the word vector database interface...
    if(!defined $vectorDB)
    {	
	$self->{'errorString'} .= "\nError (WordNet::Similarity::vector->_initialize()) - ";
	$self->{'errorString'} .= "Word Vector database file not specified. Use configuration file.";
	$self->{'error'} = 2;
	return;
    }

    # Get the documentCount...
    $db = dbInterface->new($vectorDB, "DocumentCount");
    if(!$db)
    {
	$self->{'errorString'} .= "\nError (WordNet::Similarity::vector->_initialize()) - ";
	$self->{'errorString'} .= "Unable to open word vector database.";
	$self->{'error'} = 2;
	return;
    }
    ($documentCount) = $db->getKeys();
    $db->finalize();

    # Load the word vector dimensions...
    $db = dbInterface->new($vectorDB, "Dimensions");
    if(!$db)
    {
      $self->{'errorString'} .= "\nError (WordNet::Similarity::vector->_initialize()) - ";
	    $self->{'errorString'} .= "Unable to open word vector database.";
	    $self->{'error'} = 2;
	    return;
    }
    my @keys = $db->getKeys();
    my $key;
    $self->{'numberOfDimensions'} = scalar(@keys);
    foreach $key (@keys)
    {
	my $ans = $db->getValue($key);
	my @prts = split(/\s+/, $ans);
	$self->{'wordIndex'}->{$key} = $prts[0];
	$self->{'indexWord'}->[$prts[0]] = $key;
    }
    $db->finalize();
    
    # Set up the interface to the word vectors...
    $db = dbInterface->new($vectorDB, "Vectors");
    if(!$db)
    {
	$self->{'errorString'} .= "\nError (WordNet::Similarity::vector->_initialize()) - ";
	$self->{'errorString'} .= "Unable to open word vector database.";
	$self->{'error'} = 2;
	return;
    }
    @keys = $db->getKeys();
    foreach $key (@keys)
    {
	my $vec = $db->getValue($key);
	if(defined $vec)
	{
	    $self->{'table'}->{$key} = $vec;
	}
    }
    $db->finalize();

    # If relation file not specified... manually add the relations to
    # be used...
    if(!(defined $relationFile))
    {
	$self->{'weights'}->[0] = 1;
	$self->{'functions'}->[0]->[0] = "glosexample";
    }
    else
    {
	# Load the relations data
	my $header;
	my $relation;
	
	if(open(RELATIONS, $relationFile))
	{
	    $header = <RELATIONS>;
	    $header =~ s/[\r\f\n]//g;
	    $header =~ s/\s+//g;
	    if($header =~ /VectorRelationFile/)
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
		    $relation =~ s/^\s+//;
		    $relation =~ s/\s+$//;
		    
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
		    
# 		    # check if we have a "proper" relation, that is a relation in
# 		    # there are two blocks of functions!
# # 		    if($relation !~ /(.*)-(.*)/)
# # 		    {
# # 			$self->{'errorString'} .= "\nError (WordNet::Similarity::vector->_initialize()) - ";
# # 			$self->{'errorString'} .= "Bad file format ($relationFile).";
# # 			$self->{'error'} = 2;
# # 			close(RELATIONS);
# # 			return;		
# # 		    }
		    
# 		    # get the two parts of the relation pair
# 		    my @twoParts;
# 		    my $l;
# 		    $twoParts[0] = $1;
# 		    $twoParts[1] = $2;
		    
		    # process the relation and put into functions array
#		    for($l = 0; $l < 2; $l++)
		    {
			no strict;

			$relation =~ s/[\s\)]//g;
			my @functionArray = split(/\(/, $relation);
			
			my $j = 0;
			my $fn = $functionArray[$#functionArray];
			if(!($gwi->can($fn)))
			{
			    $self->{'errorString'} .= "\nError (WordNet::Similarity::vector->_initialize()) - ";
			    $self->{'errorString'} .= "Undefined function ($functionArray[$#functionArray]) in relations file.";
			    $self->{'error'} = 2;
			    close(RELATIONS);
			    return;
			}
			
			$self->{'functions'}->[$index]->[$j++] = $functionArray[$#functionArray];
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
				$self->{'errorString'} .= "\nError (WordNet::Similarity::vector->_initialize()) - ";
				$self->{'errorString'} .= "Undefined function ($functionArray[$k]) in relations file.";
				$self->{'error'} = 2;
				close(RELATIONS);
				return;
			    }
			    
			    ($input, $dummy) = $gwi->$fn2(0);
			    ($dummy, $output) = $gwi->$fn3(0);
			    
			    if($input != $output)
			    {
				$self->{'errorString'} .= "\nError (WordNet::Similarity::vector->_initialize()) - ";
				$self->{'errorString'} .= "Invalid function combination - $functionArray[$k]($functionArray[$k+1]).";
				$self->{'error'} = 2;
				close(RELATIONS);
				return;
			    }
			    
			    $self->{'functions'}->[$index]->[$j++] = $functionArray[$k];
			}
			
			# if the output of the outermost function is synset array (1)
			# wrap a glos around it
			my $xfn = $functionArray[0];
			($dummy, $output) = $gwi->$xfn(0);
			if($output == 1) 
			{ 
			    $self->{'functions'}->[$index]->[$j++] = "glos"; 
			}
		    }
		    
		    $index++;
		}
	    }
	    else
	    {
		$self->{'errorString'} .= "\nError (WordNet::Similarity::vector->_initialize()) - ";
		$self->{'errorString'} .= "Bad file format ($relationFile).";
		$self->{'error'} = 2;
		close(RELATIONS);
		return;		
	    }
	    close(RELATIONS);   
	}
	else
	{
	    $self->{'errorString'} .= "\nError (WordNet::Similarity::vector->_initialize()) - ";
	    $self->{'errorString'} .= "Unable to open $relationFile.";
	    $self->{'error'} = 2;
	    return;
	}
    }
    
    # [trace]
    $self->{'traceString'} = "WordNet::Similarity::vector object created:\n";
    $self->{'traceString'} .= "trace          :: ".($self->{'trace'})."\n" if(defined $self->{'trace'});
    $self->{'traceString'} .= "cache          :: ".($self->{'doCache'})."\n" if(defined $self->{'doCache'});
    $self->{'traceString'} .= "stem           :: ".($self->{'doStem'})."\n" if(defined $self->{'doStem'});
#   $self->{'traceString'} .= "cutoff         :: ".($self->{'cutoff'})."\n" if(defined $self->{'cutoff'} && $self->{'cutoff'} >= 0);
    $self->{'traceString'} .= "max Cache Size :: ".($self->{'maxCacheSize'})."\n" if(defined $self->{'maxCacheSize'});
    $self->{'traceString'} .= "relation File  :: $relationFile\n" if(defined $relationFile);
    $self->{'traceString'} .= "stop List      :: $stopFile\n" if(defined $stopFile);
    $self->{'traceString'} .= "compounds file :: $compFile\n" if(defined $compFile);
    $self->{'traceString'} .= "word Vector DB :: $vectorDB\n" if(defined $vectorDB);
    # [/trace]
}


# The gloss vector relatedness measure subroutine ...
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
    my $db = $self->{'db'};

    # Check the existence of the WordNet::QueryData object.
    if(!$wn)
    {
	$self->{'errorString'} .= "\nError (WordNet::Similarity::vector->getRelatedness()) - ";
	$self->{'errorString'} .= "A WordNet::QueryData object is required.";
	$self->{'error'} = 2;
	return undef;
    }

    # Initialize traces.
    $self->{'traceString'} = "" if($self->{'trace'});

    # Undefined input cannot go unpunished.
    if(!$wps1 || !$wps2)
    {
	$self->{'errorString'} .= "\nWarning (WordNet::Similarity::vector->getRelatedness()) - Undefined input values.";
	$self->{'error'} = ($self->{'error'} < 1) ? 1 : $self->{'error'};
	return undef;
    }

    # Security check -- are the input strings in the correct format (word#pos#sense).
    if($wps1 !~ /^\S+\#([nvar])\#\d+$/)
    {
	$self->{'errorString'} .= "\nWarning (WordNet::Similarity::vector->getRelatedness()) - ";
	$self->{'errorString'} .= "Input not in word\#pos\#sense format.";
	$self->{'error'} = ($self->{'error'} < 1) ? 1 : $self->{'error'};
	return undef;
    }
    if($wps2 !~ /^\S+\#([nvar])\#\d+$/)
    {
	$self->{'errorString'} .= "\nWarning (WordNet::Similarity::vector->getRelatedness()) - ";
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

    # Are the gloss vectors present in the cache...
    if(defined $self->{'vCache'}->{$wps1} && defined $self->{'vCache'}->{$wps2})
    {
	if($self->{'trace'})
	{
	    # ah so we do need SOME traces! put in the synset names. 
	    $self->{'traceString'} .= "Synset 1: $wps1 (Gloss Vector found in Cache)\n";
	    $self->{'traceString'} .= "Synset 2: $wps2 (Gloss Vector found in Cache)\n";
	}	
	my $a = $self->{'vCache'}->{$wps1};
	my $b = $self->{'vCache'}->{$wps2};
	my $score = &_inner($a, $b);
#	my $score = $cos->sclr();

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
    my $firstString = "";
    my $secondString = "";
    while(defined $self->{'functions'}->[$i])
    {
	my $functionsString = "";
	my $funcStringPrinted = 0;
	my $functionsScore = 0;
	
	# see if any traces reqd. if so, create the functions string
	# however don't send it to the trace string immediately - will
	# print it only if there are any overlaps for this rel
	if($self->{'trace'})
	{
	    $functionsString = "Functions: ";
	    my $j = 0;
	    while(defined $self->{'functions'}->[$i]->[$j])
	    {
		$functionsString .= ($self->{'functions'}->[$i]->[$j])." ";
		$j++;
	    }
	}
	
	# now get the string for the first set of synsets
	my @arguments = @firstSet;
	
	# apply the functions to the arguments, passing the output of
	# the inner functions to the inputs of the outer ones
	my $j = 0;
	no strict;

	while(defined $self->{'functions'}->[$i]->[$j])
	{
	    my $fn = $self->{'functions'}->[$i]->[$j];
	    @arguments = $gwi->$fn(@arguments);
	    $j++;
	}
	
	# finally we should have one cute little string!
	$firstString .= $arguments[0];
	
	# next do all this for the string for the second set
	@arguments = @secondSet;
	
	$j = 0;
	while(defined $self->{'functions'}->[$i]->[$j])
	{
	    my $fn = $self->{'functions'}->[$i]->[$j];
	    @arguments = $gwi->$fn(@arguments);
	    $j++;
	}
	
	$secondString .= $arguments[0];
		
	# check if the two strings need to be reported in the trace.
	if($self->{'trace'})
	{
	    if(!$funcStringPrinted)
	    {
		$self->{'traceString'} .= "$functionsString\n";
		$funcStringPrinted = 1;
	    }
	}
	
	$i++;
    }

    # Preprocess...
    $firstString =~ s/\'//g;
    $firstString =~ s/[^a-z0-9]+/ /g;
    $firstString =~ s/^\s+//;
    $firstString =~ s/\s+$//;
    $firstString = $self->_compoundify($firstString);
    $secondString =~ s/\'//g;
    $secondString =~ s/[^a-z0-9]+/ /g;
    $secondString =~ s/^\s+//;
    $secondString =~ s/\s+$//;
    $secondString = $self->_compoundify($secondString);
    
    # Get vectors... score...
    my $a;
    my $maga;
    my $sizea;
    my $b;
    my $magb;
    my $sizeb;
    my $trr;

    # see if any traces reqd. if so, put in the synset arrays. 
    if($self->{'trace'})
    {
	# ah so we do need SOME traces! put in the synset names. 
	$self->{'traceString'} .= "Synset 1: $wps1";
    }
    if(defined $self->{'vCache'}->{$wps1})
    {
	$a = $self->{'vCache'}->{$wps1};
	$self->{'traceString'} .= " (Gloss vector found in cache)\n" if($self->{'trace'});
    }
    else
    {
	($a, $trr, $maga) = $self->_getVector($firstString);
	$self->{'traceString'} .= "\nString: \"$firstString\"\n$trr\n" if($self->{'trace'});
	&_norm($a, $maga);
	$self->{'vCache'}->{$wps1} = $a;
	push(@{$self->{'vCacheQ'}}, $wps1);
	while(scalar(@{$self->{'vCacheQ'}}) > $self->{'vCacheSize'})
	{
	    my $wps = shift(@{$self->{'vCacheQ'}});
	    delete $self->{'vCache'}->{$wps}
	}
    }

    if($self->{'trace'})
    {
	# ah so we do need SOME traces! put in the synset names. 
	$self->{'traceString'} .= "Synset 2: $wps2";
    }
    if(defined $self->{'vCache'}->{$wps2})
    {
	$b = $self->{'vCache'}->{$wps2};
	$self->{'traceString'} .= " (Gloss vector found in cache)\n" if($self->{'trace'});
    }
    else
    {
	($b, $trr, $magb) = $self->_getVector($secondString);
	$self->{'traceString'} .= "\nString: \"$secondString\"\n$trr\n" if($self->{'trace'});
	&_norm($b, $magb);
	$self->{'vCache'}->{$wps2} = $b;
	push(@{$self->{'vCacheQ'}}, $wps2);
	while(scalar(@{$self->{'vCacheQ'}}) > $self->{'vCacheSize'})
	{
	    my $wps = shift(@{$self->{'vCacheQ'}});
	    delete $self->{'vCache'}->{$wps}
	}
    }

    $score = &_inner($a, $b);
#    $score = $cos->sclr();
   
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

# Method to compute a context vector from a given body of text...
sub _getVector
{
    my $self = shift;
    my $text = shift;
#    my $ret = zeroes($self->{'numberOfDimensions'});
    my $ret = {};
    return $ret if(!defined $text);
    my @words = split(/\s+/, $text);
    my $word;
    my %types;
    my $fstFlag = 1;
    my $localTraces = "";
    my $kk;
    my $mag;

    # [trace]
    if($self->{'trace'})
    {
	$localTraces .= "Word Vectors for: ";
    }
    # [/trace]

    foreach $word (@words)
    {
	$types{$word} = 1 if($word !~ /[XGES]{3}\d{5}[XGES]{3}/);
    }
    foreach $word (keys %types)
    {
	if(defined $self->{'table'}->{$word} && !defined $self->{'stopHash'}->{$word})
	{
	    my %pieces = split(/\s+/, $self->{'table'}->{$word});

	    # [trace]
	    if($self->{'trace'})
	    {
		$localTraces .= ", " if(!$fstFlag);
		$localTraces .= "$word";
		$fstFlag = 0;
	    }
	    # [/trace]

	    foreach $kk (keys %pieces)
	    {
#		$ret->index($kk) += $pieces{$kk};
		$ret->{$kk} = ((defined $ret->{$kk})?($ret->{$kk}):0) + $pieces{$kk};
	    }
	}
    }

    $mag = 0;
    foreach $kk (keys %{$ret})
    {
	$mag += ($ret->{$kk} * $ret->{$kk});
    }
    
    return ($ret, $localTraces, sqrt($mag));
}

# Normalizes the sparse vector.
sub _norm
{
    my $vec = shift;
    my $mag = shift;

    if(defined $vec && defined $mag && $mag != 0)
    {
	my $key;
	foreach $key (keys %{$vec})
	{
	    $vec->{$key} /= $mag;
	}
    }
}

# Inner product of two sparse vectors.
sub _inner
{
    my $vec1 = shift;
    my $vec2 = shift;
    my ($size1, $size2);
    my $prod = 0;

    return 0 if(!defined $vec1 || !defined $vec2);

    $size1 = scalar(keys(%{$vec1}));
    $size2 = scalar(keys(%{$vec2}));

    if(defined $size1 && defined $size2 && $size1 < $size2)
    {
	my $key;
	foreach $key (keys %{$vec1})
	{
	    $prod += ($vec1->{$key} * $vec2->{$key}) if(defined $vec2->{$key});
	}
    }
    else
    {
	my $key;
	foreach $key (keys %{$vec2})
	{
	    $prod += ($vec1->{$key} * $vec2->{$key}) if(defined $vec1->{$key});
	}
    }

    return $prod;
}

# Method that determines all possible compounds in a line of text.
sub _compoundify
{
    my $self = shift;
    my $block = shift;
    my $string;
    my $done;
    my $temp;
    my $firstPointer;
    my $secondPointer;
    my @wordsArray;
    
    return undef if(!defined $block);
    
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
	    if(exists $self->{'compounds'}->{$temp})
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

1;

__END__

=head1 NAME

WordNet::Similarity::vector - Perl module for computing semantic relatedness
of word senses using second order co-occurrence vectors of glosses of the word
senses.

=head1 SYNOPSIS

  use WordNet::Similarity::vector;

  use WordNet::QueryData;

  my $wn = WordNet::QueryData->new();

  my $vector = WordNet::Similarity::vector->new($wn);

  my $value = $vector->getRelatedness("car#n#1", "bus#n#2");

  ($error, $errorString) = $vector->getError();

  die "$errorString\n" if($error);

  print "car (sense 1) <-> bus (sense 2) = $value\n";

=head1 DESCRIPTION

Schütze (1998) creates what he calls context vectors (second order 
co-occurrence vectors) of pieces of text for the purpose of Word Sense
Discrimination. This idea is adopted by Patwardhan and Pedersen to represent the 
word senses by second-order co-occurrence vectors of their dictionary (WordNet) 
definitions. The relatedness of two senses is then computed as the cosine of 
their representative gloss vectors.

=head1 USAGE

The semantic relatedness modules in this distribution are built as classes
that expose the following methods:
  new()
  getRelatedness()
  getError()
  getTraceString()

See the WordNet::Similarity(3) documentation for details of these methods.

=head1 TYPICAL USAGE EXAMPLES

To create an object of the vector measure, we would have the following
lines of code in the Perl program. 

  use WordNet::Similarity::vector;
  $measure = WordNet::Similarity::vector->new($wn, '/home/sid/vector.conf');

The reference of the initialized object is stored in the scalar variable
'$measure'. '$wn' contains a WordNet::QueryData object that should have been
created earlier in the program. The second parameter to the 'new' method is
the path of the configuration file for the vector measure. If the 'new'
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
the file. For example, a configuration file for the vector module will have
on the first line 'WordNet::Similarity::vector'. This is followed by the various
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

(b) 'relation::' -- The value is a filename (with complete path) of a file
that contains a list of WordNet-relations. The vector module combines the
glosses of synsets related to the target synsets by these relations, and 
forms the gloss-vector from this combined gloss. The format of the relation
file is specified later in the documentation.

(c) 'vectordb::' -- Value is a Berkeley DB database file containing word 
vectors, i.e. co-occurrence vectors for all the words in the WordNet 
glosses.

(d) 'stop::' -- The value is a string that specifies the path of a file 
containing a list of stop words that should be ignored in the gloss 
vectors.

(e) 'compounds::' -- The value is a string that specifies the path of a file 
containing a list of compound words in WordNet.

(f) 'stem::' -- can take values 0 or 1 or the value can be omitted, in 
which case it takes the value 1, i.e. switches 'on' stemming. A value of 
0 switches stemming 'off'. When stemming is enabled, all the words of the
glosses are stemmed before their vectors are created.

(g) 'cache::' -- can take values 0 or 1 or the value can be omitted, in 
which case it takes the value 1, i.e. switches 'on' caching. A value of 
0 switches caching 'off'. By default caching is enabled.

(h) 'maxCacheSize::' -- takes a non-negative integer value. The value indicates
the size of the cache, used for storing the computed relatedness value.

=head1 RELATION FILE FORMAT

The relation file starts with the string "VectorRelationFile" on the first line
of the file. Following this, on each consecutive line, a relation is specified
in the form -- 

func(func(func... (func)...)) [weight]

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
syns = the synset of the concept

Each of these specifies a WordNet relation. And the outermost function in the
nesting can only be one of glos, example, glosexample or syns. The functions specify which 
glosses to use for forming the gloss vector of the synset. An optional weight can be 
specified to weigh the contribution of that relation in the overall score.

For example,

glos(hype(hypo)) 0.5

means that the gloss of the hypernym of the hyponym of the synset is used to form the 
gloss vector of the synset, and the values in this vector are weighted by 0.5. If one of "glos", 
"example", "glosexample" or "syns" is not specified as the outermost function in the nesting, 
then "glosexample" is assumed by default. This implies that

glosexample(hypo(also))

and

hypo(also)

are equivalent as far as the measure is concerned.

=head1 SEE ALSO

perl(1), WordNet::Similarity(3), WordNet::QueryData(3)

http://www.cs.utah.edu/~sidd

http://www.cogsci.princeton.edu/~wn

http://www.ai.mit.edu/~jrennie/WordNet

http://groups.yahoo.com/group/wn-similarity

=head1 AUTHORS

  Siddharth Patwardhan, <sidd@cs.utah.edu>
  Ted Pedersen, <tpederse@d.umn.edu>
  Satanjeev Banerjee, <banerjee+@cs.cmu.edu>

=head1 COPYRIGHT AND LICENSE

Copyright 2003 by Siddharth Patwardhan, Ted Pedersen and Satanjeev Banerjee

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
