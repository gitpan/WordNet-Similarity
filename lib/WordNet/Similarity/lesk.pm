# WordNet::Similarity::lesk.pm version 0.12
# (Last updated $Id: lesk.pm,v 1.17 2004/10/27 15:24:56 jmichelizzi Exp $)
#
# Module to accept two WordNet synsets and to return a floating point
# number that indicates how similar those two synsets are, using an
# adaptation of the Lesk method as outlined in <ACL/IJCAI/EMNLP paper,
# Satanjeev Banerjee, Ted Pedersen>

package WordNet::Similarity::lesk;

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

=head2 Methods

=over

=cut

use strict;
use warnings;

use get_wn_info;

use Text::OverlapFinder;

use stem;

use WordNet::Similarity;

use File::Spec;

our @ISA = qw(WordNet::Similarity);

our $VERSION = '0.12';

WordNet::Similarity::addConfigOption ("relation", 0, "p", undef);
WordNet::Similarity::addConfigOption ("stop", 0, "p", undef);
WordNet::Similarity::addConfigOption ("stem", 0, "i", 0);
WordNet::Similarity::addConfigOption ("normalize", 0, "i", 0);

sub setPosList
{
  my $self = shift;
  $self->{n} = 1;
  $self->{v} = 1;
  $self->{a} = 1;
  $self->{r} = 1;
  return 1;
}


# Initialization of the WordNet::Similarity::lesk object... parses the config file and sets up
# global variables, or sets them to default values.
# INPUT PARAMS  : $paramFile .. File containing the module specific params.
# RETURN VALUES : (none)
sub initialize
{
    my $self = shift;
    my $paramFile;
    my $stopFile;
    my $wn = $self->{wn};
    my %stopHash = ();
    my $class = ref $self || $self;

    # Stemming? Normalizing?
    $self->{stem} = 0;
    $self->{normalize} = 0;


    $self->SUPER::initialize (@_);

    # Look for the default relation file if not specified by the user.
    # Search the @INC path in WordNet/Similarity.
    #my $relationFile = $self->{relation};
    unless (defined $self->{relation}) {
      my $path;
      my $header;
      my @possiblePaths = ();

      # Look for all possible default data files installed.
      foreach $path (@INC) {
	# JM 1-16-04  -- modified to use File::Spec
	my $file = File::Spec->catfile ($path, 'WordNet', 'lesk-relation.dat');
	if(-e $file) {
	  push @possiblePaths, $file;
	}
      }

      # If there are multiple possibilities, get the one in the correct format.
      foreach $path (@possiblePaths) {
	next unless open (RELATIONS, $path);
	$header = <RELATIONS>;
	$header =~ s/\s+//g;
	if($header =~ /LeskRelationFile/) {
	  $self->{relation} = $path;
	  close(RELATIONS);
	  last;
	}
	close(RELATIONS);
      }
    }

    # Load the stop list.
    if(defined $self->{stop}) {
      my $line;
	
      if(open(STOP, $self->{stop})) {
	while($line = <STOP>) {
	  $line =~ s/[\r\f\n]//g;
	  $line =~ s/\s//g;
	  $stopHash{$line} = 1;		
	}
	close(STOP);
      }
      else {
	$self->{errorString} .= "\nWarning (${class}::initialize()) - ";
	$self->{errorString} .= "Unable to open stop file $stopFile.";
	$self->{error} = ($self->{'error'} < 1) ? 1 : $self->{'error'};
      }
    }

    # so now we are ready to initialize the get_wn_info package with
    # the wordnet object, 0/1 depending on if stemming is required and
    # the stop hash
    my $dostem = $self->{stem} ? 1 : 0;
    my $gwi = $self->{gwi} = get_wn_info->new ($wn, $dostem, %stopHash);

    # Load the relations data.
    $self->_loadRelationFile ($gwi);

    # initialize string compare module. No stemming in string
    # comparison, so put 0.
    #&string_compare_initialize(0, %stopHash);
    my @finder_args = ();

    if (defined $self->{stop}) {
	push @finder_args, stoplist => $self->{stop};
    }
    # lesk doesn't use a comp file, so we can ignore that
   
    $self->{finder} = Text::OverlapFinder->new (@finder_args);

# JM 12/5/03 (#1)
# moved this behavior to traceOptions()
#    # [trace]
#    if ($self->{trace}) {
#      $self->{traceString} .= "normalize      :: ".($self->{normalize})."\n" if(defined $self->{doNormalize});
#      $self->{traceString} .= "relation File  :: $relationFile\n" if($relationFile);
#      $self->{traceString} .= "stop File      :: $stopFile\n" if($stopFile);
#    }
#    # [/trace]
}

sub _loadRelationFile
{
    my $self = shift;
    my $gwi = shift;
    my $class = ref $self || $self;

    if ($self->{relation}){
	my $header;
	my $relation;

	if(open (RELATIONS, $self->{relation})) {
	    $header = <RELATIONS>;
	    $header =~ s/[\r\f\n]//g;
	    $header =~ s/\s+//g;
	    if($header =~ /LeskRelationFile/) {
		my $index = 0;
		$self->{functions} = ();
		$self->{weights} = ();
		while($relation = <RELATIONS>) {
		    $relation =~ s/[\r\f\n]//g;
		    
		    # now for each line in the file, extract the
		    # nested functions if any, check if they are defined,
		    # if it makes sense to nest them, and then finally put
		    # them into the @functions triple dimensioned array!
		    
		    # remove leading/trailing spaces from the relation
		    $relation =~ s/^\s*(\S*?)\s*$/$1/;
		    
		    # now extract the weight if any. if no weight, assume 1
		    if($relation =~ /(\S+)\s+(\S+)/)
		    {
			$relation = $1;
			$self->{weights}->[$index] = $2;
		    }
		    else
		    {
			$self->{weights}->[$index] = 1;
		    }

		    # check if we have a "proper" relation, that is a relation in
		    # there are two blocks of functions!
		    if($relation !~ /(.*)-(.*)/) {
			$self->{errorString} .= "\nError (${class}::_loadRelationFile()) - ";
			$self->{errorString} .= "Bad file format ($self->{relation}).";
			$self->{error} = 2;
			close RELATIONS;
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
			#no strict 'subs';
			
			$twoParts[$l] =~ s/[\s\)]//g;
			my @functionArray = split(/\(/, $twoParts[$l]);
			
			my $j = 0;
			my $fn = $functionArray[$#functionArray];
			unless ($gwi->can($fn)) {
			    $self->{errorString} .= "\nError (${class}::_loadRelationFile()) - ";
			    $self->{errorString} .= "Undefined function ($functionArray[$#functionArray]) in relations file.";
			    $self->{error} = 2;
			    close RELATIONS;
			    return;
			}
			
			$self->{functions}->[$index]->[$l]->[$j++] = $functionArray[$#functionArray];
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
				$self->{errorString} .= "\nError (${class}::_loadRelationFile()) - ";
				$self->{errorString} .= "Undefined function ($functionArray[$k]) in relations file.";
				$self->{error} = 2;
				close(RELATIONS);
				return;
			    }
			    
			    ($input, $dummy) = $gwi->$fn2(0);
			    ($dummy, $output) = $gwi->$fn3(0);
			    
		    if($input != $output)
		    {
			$self->{errorString} .= "\nError (${class}::_loadRelationFile()) - ";
			$self->{errorString} .= "Invalid function combination - $functionArray[$k]($functionArray[$k+1]).";
			$self->{error} = 2;
			close(RELATIONS);
			return;
		      }
			    
			    $self->{functions}->[$index]->[$l]->[$j++] = $functionArray[$k];
			}
			
			# if the output of the outermost function is synset array (1)
			# wrap a glos around it
			my $xfn = $functionArray[0];
			($dummy, $output) = $gwi->$xfn(0);
			if($output == 1)
			{
			    $self->{functions}->[$index]->[$l]->[$j++] = "glos";
			}
		    }
		    
		    $index++;
		}
	    }
	    else
	    {
		$self->{errorString} .= "\nError (${class}::_loadRelationFile()) - ";
		$self->{errorString} .= "Bad file format ($self->{relation}).";
		$self->{error} = 2;
		close(RELATIONS);
		return;		
	    }
	    close(RELATIONS);
	}
	else
	{
	    $self->{errorString} .= "\nError (${class}::_loadRelationFile()) - ";
	    $self->{errorString} .= "Unable to open $self->{relation}.";
	    $self->{error} = 2;
	    return;
	}
    }
    else
    {
	$self->{errorString} .= "\nError (${class}::_loadRelationFile()) - ";
	$self->{errorString} .= "No default relations file found.";
	$self->{error} = 2;
	return;
    }
}


# 12/5/03 JM (#1)
# show all config options specific to this module
sub traceOptions {
  my $self = shift;
  $self->{traceString} .= "normalize :: $self->{normalize}\n";
  $self->{traceString} .= "relation File :: $self->{relation}\n";
  $self->{traceString} .=
    "stop :: ".((defined $self->{stop}) ? $self->{stop} : "")."\n";
  $self->{traceString} .= "stem :: $self->{stem}\n";
}

=item $lesk->getRelatedness

Computes the relatedness of two word senses using the Adapted Lesk
Algorithm.

Parameters: two word senses in "word#pos#sense" format.

Returns: Unless a problem occurs, the return value is the relatedness
score, which is greater-than or equal-to 0. If an error occurs,
then the error level is set to non-zero and an error
string is created (see the description of getError()).

=cut

sub getRelatedness
{
    my $self = shift;
    my $wps1 = shift;
    my $wps2 = shift;
    my $class = ref $self || $self;
    my $gwi = $self->{gwi};

    # Initialize traces.
    $self->{traceString} = "" if $self->{trace};

    # Undefined input cannot go unpunished.
    if(!$wps1 || !$wps2)
    {
	$self->{errorString} .= "\nWarning (${class}::getRelatedness()) - Undefined input values.";
	$self->{error} = ($self->{'error'} < 1) ? 1 : $self->{'error'};
	return undef;
    }

    # Security check -- are the input strings in the correct format (word#pos#sense).
    if($wps1 !~ /^\S+\#([nvar])\#\d+$/)
    {
	$self->{errorString} .= "\nWarning (${class}::getRelatedness()) - ";
	$self->{errorString} .= "Input not in word\#pos\#sense format.";
	$self->{error} = ($self->{error} < 1) ? 1 : $self->{error};
	return undef;
    }
    if($wps2 !~ /^\S+\#([nvar])\#\d+$/)
    {
	$self->{errorString} .= "\nWarning (${class}::getRelatedness()) - ";
	$self->{errorString} .= "Input not in word#pos#sense format.";
	$self->{error} = ($self->{error} < 1) ? 1 : $self->{error};
	return undef;
    }

    # Now check if the similarity value for these two synsets is in
    # fact in the cache... if so return the cached value.
    my $relatedness =
      $self->{doCache} ? $self->fetchFromCache ($wps1, $wps2) : undef;
    defined $relatedness and return $relatedness;

    # see if any traces reqd. if so, put in the synset arrays.
    if($self->{trace})
    {
	# ah so we do need SOME traces! put in the synset names.
	$self->{traceString}  = "Synset 1: $wps1\n";
	$self->{traceString} .= "Synset 2: $wps2\n";
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
    while(defined $self->{functions}->[$i])
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
	    while(defined $self->{functions}->[$i]->[0]->[$j])
	    {
		$functionsString .= ($self->{functions}->[$i]->[0]->[$j])." ";
		$j++;
	    }

	    $functionsString .= "- ";
	    $j = 0;
	    while(defined $self->{functions}->[$i]->[1]->[$j])
	    {
		$functionsString .= ($self->{functions}->[$i]->[1]->[$j])." ";
		$j++;
	    }
	}
	
	# now get the string for the first set of synsets
	my @arguments = @firstSet;
	
	# apply the functions to the arguments, passing the output of
	# the inner functions to the inputs of the outer ones
	my $j = 0;
	#no strict;

	while(defined $self->{functions}->[$i]->[0]->[$j])
	{
	    my $fn = $self->{functions}->[$i]->[0]->[$j];
	    @arguments = $gwi->$fn(@arguments);
	    $j++;
	}
	
	# finally we should have one cute little string!
	my $firstString = $arguments[0];
	
	# next do all this for the string for the second set
	@arguments = @secondSet;
	
	$j = 0;
	while(defined $self->{functions}->[$i]->[1]->[$j])
	{
	    my $fn = $self->{functions}->[$i]->[1]->[$j];
	    @arguments = $gwi->$fn(@arguments);
	    $j++;
	}
	
	my $secondString = $arguments[0];
	
	# so those are the two strings for this relation pair. get the
	# string overlaps
	undef %overlaps;
	#%overlaps = &string_compare_getStringOverlaps($firstString, $secondString);
	
	my ($overlaps, $wc1, $wc2) = $self->{finder}->getOverlaps ($firstString, $secondString);

	my $overlapsTraceString = "";
	my $key;
	foreach $key (keys %$overlaps)
	{
	    # find the length of the key, square it, multiply with its
	    # value and finally with the weight associated with this
	    # relation pair to get the score for this particular
	    # overlap.

	    my @tempArray = split(/\s+/, $key);
	    my $value = ($#tempArray + 1) * ($#tempArray + 1) * $overlaps->{$key};
	    $functionsScore += $value;

	    # put this overlap into the trace string, if necessary
	    if($self->{trace} == 1)
	    {
		$overlapsTraceString .= "$overlaps->{$key} x \"$key\"  ";
	    }
	}
	
	# normalize the function score computed above if required
#	if($self->{normalize} && ($numWords1 * $numWords2))
	if ($self->{normalize} && ($wc1 * $wc2))
	{
	    #$functionsScore /= ($numWords1 * $numWords2);
	    $functionsScore /= $wc1 * $wc2;
	}
	
	# weight functionsScore with weight of this function
	$functionsScore *= $self->{weights}->[$i];
	
	# add to main score for this sense
	$score += $functionsScore;
	
	# if we have an overlap, send functionsString, functionsScore
	# and overlapsTraceString to trace string, if trace string requested
	if($self->{trace} == 1 && $overlapsTraceString ne "")
	{
	    $self->{traceString} .= "$functionsString: $functionsScore\n";
	    $funcStringPrinted = 1;

	    $self->{traceString} .= "Overlaps: $overlapsTraceString\n";
	}
	
	# check if the two strings need to be reported in the trace.
	if ($self->{trace} == 2)
	{
	    if(!$funcStringPrinted)
	    {
		$self->{traceString} .= "$functionsString\n";
		$funcStringPrinted = 1;
	    }

	    $self->{traceString} .= "String 1: \"$firstString\"\n";
	    $self->{traceString} .= "String 2: \"$secondString\"\n";
	}
	
	$i++;
    }

    # that does all the scoring. Put in cache if doing caching. Then
    # return the score.
    $self->{doCache} and $self->storeToCache ($wps1, $wps2, $score);
    return $score;
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

Every configuration file starts with the name of the module ON THE FIRST LINE
of the file. For example, a configuration file for the lesk module will have
on the first line 'WordNet::Similarity::lesk'. This is followed by the various
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
of 1 or 2 switches tracing on.  A value of 1 displays as
traces only the gloss overlaps found. A value of 2 displays as traces all
the text being compared.

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

=item relation

The value of this parameter is the path to a file that contains a list of
WordNet relations.  The path may be either an absolute path or a relative
path.

The lesk measure combines glosses of synsets related to the target
synsets by these relations and then searches for overlaps in these
"super-glosses."

WARNING: the format of the relation file is different for the vector and lesk
measures.

=item stop

The value of this parameter the path of a file containing a list of stop
words that should be ignored in the glosses.  The path may be either an
absolute path or a relative path.

=item stem

The value of this parameter indicates whether or not stemming should be
performed.  The value must be an integer equal to 0 or 1.  If the
value is omitted, then the default value, 0, is used.
A value of 1 switches 'on' stemming, and a value of 0 switches stemming
'off'. When stemming is enabled, all the words of the
glosses are stemmed before their vectors are created for the vector
measure or their overlaps are compared for the lesk measure.

=item normalize

The value of this parameter indicates whether or not normalization of
scores is performed.  The value must be an integer equal to 0 or 1.  If
the value is omitted, then the default value, 0, is assumed. A value of
1 switches 'on' normalizing of the score, and a value of 0 switches
normalizing 'off'. When normalizing is enabled, the score obtained by
counting the gloss overlaps is normalized by the size of the glosses.
The details are described in Banerjee and Pedersen (2002).

=back

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
nesting can only be one of glos, example, glosexample or syns. The set of
functions to the left of the "-" are applied to the first word sense. The
functions to the right of the "-" are applied to the second word sense. An
optional weight can be specified to weigh the contribution of that relation
in the overall score.

For example,

 glos(hype(hypo))-example(hype) 0.5

means that the gloss of the hypernym of the hyponym of the first synset is
overlapped with the example of the hypernym of the second synset to get the
lesk score. This score is weighted 0.5. If "glos", "example", "glosexample"
or "syns" is not provided as the outermost function of the nesting, the
measure assumes "glos" as the default.

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

 Satanjeev Banerjee, Carnegie Mellon University, Pittsburgh
 banerjee+ at cs.cmu.edu

 Ted Pedersen, University of Minnesota Duluth
 tpederse at d.umn.edu

 Siddharth Patwardhan, University of Utah, Salt Lake City
 sidd at cs.utah.edu

=head1 BUGS

None.

To report bugs, go to http://groups.yahoo.com/group/wn-similarity/ or
e-mail "S<tpederse at d.umn.edu>".

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2003-2004, Satanjeev Banerjee, Ted Pedersen and Siddharth
Patwardhan

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
