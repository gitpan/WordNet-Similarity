# WordNet::Similarity::random.pm version 0.05
# (Updated 06/03/2003 -- Sid)
#
# Random semantic distance generator module.
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


package WordNet::Similarity::random;

use strict;

use Exporter;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

@ISA = qw(Exporter);

%EXPORT_TAGS = ();

@EXPORT_OK = ();

@EXPORT = ();

$VERSION = '0.05';


# 'new' method for the random class... creates and returns a WordNet::Similarity::random object.
# INPUT PARAMS  : $className  .. (WordNet::Similarity::random) (required)
#                 $wn         .. The WordNet::QueryData object (required).
#                 $configFile .. Name of the config file for getting the parameters (optional).
# RETURN VALUE  : $random        .. The newly created random object.
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
	$self->{'errorString'} .= "\nError (WordNet::Similarity::random->new()) - ";
	$self->{'errorString'} .= "A WordNet::QueryData object is required.";
	$self->{'error'} = 2;
    }

    # Bless object, initialize it and return it.
    bless($self, $className);
    $self->_initialize(shift) if($self->{'error'} < 2);

    return $self;
}


# Initialization of the WordNet::Similarity::random object... parses the config file and sets up 
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
	    if($modname =~ /^WordNet::Similarity::random/)
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
		    elsif(/^maxrand::(.*)/)
		    {
			$self->{'maxrand'} = $1;
		    }
		    elsif($_ ne "")
		    {
			s/::.*//;
			$self->{'errorString'} .= "\nWarning (WordNet::Similarity::random->_initialize()) - ";
			$self->{'errorString'} .= "Unrecognized parameter '$_'. Ignoring.";
			$self->{'error'} = 1;
		    }
		}
	    }
	    else
	    {
		$self->{'errorString'} .= "\nError (WordNet::Similarity::random->_initialize()) - ";
		$self->{'errorString'} .= "$paramFile does not appear to be a config file.";
		$self->{'error'} = 2;
		return;
	    }
	    close(PARAM);
	}
	else
	{
	    $self->{'errorString'} .= "\nError (WordNet::Similarity::random->_initialize()) - ";
	    $self->{'errorString'} .= "Unable to open config file $paramFile.";
	    $self->{'error'} = 2;
	    return;
	}
    }

    # [trace]
    $self->{'traceString'} = "";
    $self->{'traceString'} .= "WordNet::Similarity::lch object created:\n";
    $self->{'traceString'} .= "trace   :: ".($self->{'trace'})."\n" if(defined $self->{'trace'});
    $self->{'traceString'} .= "cache   :: ".($self->{'doCache'})."\n" if(defined $self->{'doCache'});
    $self->{'traceString'} .= "maxRand :: ".($self->{'maxrand'})."\n" if(defined $self->{'maxrand'});
    # [/trace]
}

# The Random relatedness measure subroutine ...
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
    my $pos1;
    my $pos2;
    my $offset1;
    my $offset2;
    my $score;

    # Check the existence of the WordNet::QueryData object.
    if(!$wn)
    {
	$self->{'errorString'} .= "\nError (WordNet::Similarity::random->getRelatedness()) - ";
	$self->{'errorString'} .= "A WordNet::QueryData object is required.";
	$self->{'error'} = 2;
	return undef;
    }

    # Initialize traces.
    $self->{'traceString'} = "" if($self->{'trace'});

    # Undefined input cannot go unpunished.
    if(!$wps1 || !$wps2)
    {
	$self->{'errorString'} .= "\nWarning (WordNet::Similarity::random->getRelatedness()) - Undefined input values.";
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
	$self->{'errorString'} .= "\nWarning (WordNet::Similarity::random->getRelatedness()) - ";
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
	$self->{'errorString'} .= "\nWarning (WordNet::Similarity::random->getRelatedness()) - ";
	$self->{'errorString'} .= "Input not in word\#pos\#sense format.";
	$self->{'error'} = ($self->{'error'} < 1) ? 1 : $self->{'error'};
	return undef;
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
	$self->{'errorString'} .= "\nWarning (WordNet::Similarity::hso->getRelatedness()) - ";
	$self->{'errorString'} .= "Input senses not found in WordNet.";
	$self->{'error'} = ($self->{'error'} < 1) ? 1 : $self->{'error'};
	return undef;
    }

    $score = sprintf("%.3f", ((defined $self->{'maxrand'})?(rand($self->{'maxrand'})):(rand)));
    $self->{'simCache'}->{"${wps1}::$wps2"} = $score if($self->{'doCache'});
    $self->{'traceCache'}->{"${wps1}::$wps2"} = $self->{'traceString'} if($self->{'doCache'} &&  $self->{'trace'});

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


1;
__END__

=head1 NAME

WordNet::Similarity::random - Perl module for computing semantic relatedness
of word senses using a random measure.

=head1 SYNOPSIS

  use WordNet::Similarity::random;

  use WordNet::QueryData;

  my $wn = WordNet::QueryData->new();

  my $random = WordNet::Similarity::random->new($wn);

  my $value = $random->getRelatedness("car#n#1", "bus#n#2");

  ($error, $errorString) = $random->getError();

  die "$errorString\n" if($error);

  print "car (sense 1) <-> bus (sense 2) = $value\n";

=head1 DESCRIPTION

This module generates random numbers as a measure of semantic relatedness
of word senses. It is possible to assign a random value for a word sense
pair and return the same value if the same word sense pair is passed as 
input. It is also possible to generate a new random value for the same
word sense pair every time.

=head1 USAGE

The semantic relatedness modules in this distribution are built as classes
that expose the following methods:
  new()
  getRelatedness()
  getError()
  getTraceString()

See the WordNet::Similarity(3) documentation for details of these methods.

=head1 TYPICAL USAGE EXAMPLES

To create an object of the random measure, we would have the following
lines of code in the perl program. 

   use WordNet::Similarity::random;
   $measure = WordNet::Similarity::random->new($wn, '/home/sid/random.conf');

The reference of the initialized object is stored in the scalar variable
'$measure'. '$wn' contains a WordNet::QueryData object that should have been
created earlier in the program. The second parameter to the 'new' method is
the path of the configuration file for the random measure. If the 'new'
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
the file. For example, a configuration file for the random module will have
on the first line 'WordNet::Similarity::random'. This is followed by the various
parameters, each on a new line and having the form 'name::value'. The
'value' of a parameter is optional (in case of boolean parameters). In case
'value' is omitted, we would have just 'name::' on that line. Comments are
supported in the configuration file. Anything following a '#' is ignored till
the end of the line.

The module parses the configuration file and recognizes the following 
parameters:
  
(a) 'trace::' -- can take values 0, 1 or 2 or the value can be omitted,
in which case it sets the trace level to 1. Trace level 0 implies
no traces. Trace level 1 and 2 imply tracing is 'on' the only 
difference being in the way in which the synsets are displayed in the 
output. For trace level 1, the synsets are represented as word#pos#sense
strings, while for level 2, the synsets are represented as 
word#pos#offset strings.
  
(b) 'cache::' -- can take values 0 or 1 or the value can be omitted, in 
which case it takes the value 1, i.e. switches 'on' caching. A value of 
0 switches caching 'off'. By default caching is enabled. For module 
enabling caching implies that a previously generated random value will
be reused if the same word sense pair occurs again. If caching is disabled
for every word sense pair a new random number will be generated.
  
(c) 'maxrand::' -- specifies the maximum random number that can be generated.

=head1 SEE ALSO

perl(1), WordNet::Similarity(3), WordNet::QueryData(3)

http://www.d.umn.edu/~patw0006

http://www.cogsci.princeton.edu/~wn

http://www.ai.mit.edu/people/jrennie/WordNet

http://groups.yahoo.com/group/wn-similarity

=head1 AUTHORS

  Siddharth Patwardhan, <patw0006@d.umn.edu>
  Ted Pedersen, <tpederse@d.umn.edu>

=head1 COPYRIGHT AND LICENSE

Copyright 2003 by Siddharth Patwardhan and Ted Pedersen

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
