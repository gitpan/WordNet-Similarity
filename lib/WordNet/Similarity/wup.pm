# WordNet::Similarity::wup.pm version 0.06
# (updated 10/06/2003 -- Jason)
#
# Semantic Similarity Measure package implementing the semantic
# relatedness measure described by Wu & Palmer (1994) as revised
# by Resnik (1999).
#
# Copyright (C) 2003
#
# Jason Michelizzi, University of Minnesota Duluth
# mich0212@d.umn.edu
#
# Ted Pedersen, University of Minnesota Duluth
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

package WordNet::Similarity::wup;

use strict;
use warnings;

use Exporter;
use vars qw/$VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS/;
@ISA = qw/Exporter/;

%EXPORT_TAGS = ();
@EXPORT = ();
@EXPORT_OK = ();
$VERSION = '0.06';

# constructor for the wup class
sub new {
  my ($class, $wn, $config) = @_;
  my $self = {};
  $self->{errorString} = '';
  $self->{error} = 0;

  $self->{wn} = $wn;
  unless ($wn) {
    $self->{errorString} .= "\nError (WordNet::Similarity::wup->new()) - ";
    $self->{errorString} .= "A WordNet::QueryData object is required.";
    $self->{error} = 2;
  }

  bless ($self, $class);
  $self->_initialize($config) if $self->{error} < 2;

  #tracing...
  $self->{traceString} = "";
  $self->{traceString} .= "WordNet::Similarity::wup object created:\n";
  $self->{traceString} .= "trace :: ".($self->{trace})."\n" if $self->{trace};
  $self->{traceString} .= "cache :: ".($self->{doCache})."\n" if $self->{doCache};

  return $self;
}

# initializes the this object, parses config file
sub _initialize {
  my ($self, $configFile) = @_;

  # parts of speech that this module can handle
  $self->{n} = 1;
  $self->{v} = 1; # at least I hope so

  # setup cache
  $self->{doCache} = 1;
  $self->{simCache} = ();
  $self->{traceCache} = ();
  $self->{cacheQ} = ();
  $self->{maxCacheSize} = 1000;

  # initialize tracing
  $self->{trace} = 0;

  # enable the imaginary unique root node
  $self->{rootNode} = 1;

  if (defined $configFile) {
    unless (open CF, $configFile) {
      $self->{errorString} .= "\nError (WordNet::Similarity::wup->_initialize()) - ";
      $self->{errorString} .= "Unable to open config file $configFile.";
      $self->{error} = 2;
      return;
    }
    my $line = <CF>;
    unless ($line =~ m/^WordNet::Similarity::wup/) {
      close CF;
      $self->{errorString} .= "\nError (WordNet::Similarity::wup->_initialize()) - ";
      $self->{errorString} .= "$configFile does not appear to be a config file.";
      $self->{error} = 2;
      return;
    }
    while (<CF>) {
      s/\s+|(?:\#.*)//g; # ignore comments
      if (m/^trace::(.*)/) {
	my $trace = $1;
	$self->{trace} = 1;
	$self->{trace} = $trace if $trace =~ m/^[012]$/;
      }
      elsif (m/^cache::(.*)/) {
	my $cache = $1;
	$self->{doCache} = 1;
	$self->{doCache} = $cache if $cache =~ m/^[01]$/;
      }
      elsif (m/^(?:max)?CacheSize::(.*)/i) {
	my $mcs = $1;
	$self->{maxCacheSize} = 1000;
	$self->{maxCacheSize} = $mcs
	  if defined ($mcs) and $mcs =~ m/^\d+$/;
      }
      elsif (m/^rootNode::(.*)/i) {
	my $t = $1;
	$self->{rootNode} = 1;
	next unless defined $t;
	$t = 0 if $t =~ m/^no(?:ne)$/i;
	$self->{rootNode} = $t;
      }
      elsif ($_ ne "") {
	s/::.*//;
	$self->{errorString} .= "\nWarning (WordNet::Similarity::wup->_initialize()) - ";
	$self->{errorString} .= "Unrecognized parameter '$_'.  Ignoring.";
	$self->{error} = 1;
      }
    }
    close CF;
  }
}

# computes relatedness by the Wu & Palmer (1994) measure
#
# sim(c1, c2) = 2*d(c3)/(d(c1) + d(c2))
# c3 is lowest common subsumer (maximally specific
#  superclass) of c1 and c2
# d(c) is dist from root node to c
# parameters: wps1, wps2 in word#part_of_speech#sense format
# return: $score which belongs to the interval [0,1], or undef on error
sub getRelatedness {
  my $self = shift;
  my $wps1 = shift;
  my $wps2 = shift;
  my $score;

  unless ($wps1 and $wps2) {
    $self->{errorString} .= "\nWarning (WordNet::Similarity::wup->getRelatedness ()) - Undefined input values.";
    $self->{error} = ($self->{error} < 1) ? 1 : $self->{error};
    return undef;
  }

  if ($wps1 eq $wps2) {
    $score = 1;
    return $score;
  }

  #check parts of speech
  my ($pos1, $pos2);
  my $failed = 0;
  $failed = 1 unless ($wps1 =~ m/^\S+\#([nvar])\#\d+$/);
  $pos1 = $1;
  $failed = 1 unless ($wps2 =~ m/^\S+\#([nvar])\#\d+$/);
  $pos2 = $1;

  if ($failed) {
    $self->{errorString} .= "\nWarning (WordNet::Similarity::wup->getRelatedness()) - ";
    $self->{errorString} .= "Input not in word#pos#sense format.";
    $self->{error} = ($self->{error} < 1) ? 1 : $self->{error};
    return undef;
  }

  unless ($pos1 eq $pos2) {
    if ($self->{trace}) {
      $self->{traceString} .= "Relatedness 0 across parts of speech.";
    }
    return 0;
  }

  # check the cache
  if ($self->{doCache} && defined $self->{simCache}->{"${wps1}::$wps2"}) {
    if ($self->{traceCache}->{"${wps1}::$wps2"}) {
      $self->{traceString} .= $self->{traceCache}->{"${wps1}::$wps2"};
    }
    return $self->{simCache}->{"${wps1}::$wps2"};
  }

  my $lcs = $self->getLCS ($wps1, $wps2);
  unless ($lcs) {
    $self->{errorString} .= "\nWarning (WordNet::Similarity::wup->getRelatedness ()) - ";
    $self->{errorString} .= "Unable to find a lowest common subsumer of $wps1 and $wps2.";
    $self->{error} = ($self->{error} < 1) ? 1 : $self->{error};
    undef $score;
    return $score;
  }
  if ($self->{trace}) {
    $self->{traceString} .= "HyperTree: ".$self->getHypertree($wps1)."\n";
    $self->{traceString} .= "HyperTree: ".$self->getHypertree($wps2)."\n";
    $self->{traceString} .= "LCS: ";
    $self->{traceString} .= "$lcs\n";
  }

  my $d1 = $self->getDepth ($wps1);
  my $d2 = $self->getDepth ($wps2);
  my $d3 = $self->getDepth ($lcs);

  unless ($self->{rootNode}) {
    $d1--;
    $d2--;
    $d3-- if $d3 > 0;
  }

  if ($self->{trace}) {
    $self->{traceString} .= "depth($wps1) = $d1\n";
    $self->{traceString} .= "depth($wps2) = $d2\n";
    $self->{traceString} .= "depth($lcs) = $d3\n";
  }

  # avoid 0/0, assign 1
  if ($d1 == 0 and $d2 == 0) {
    $score = 1;
  }
  else {
    $score = (2 * $d3) / ($d1 + $d2);
  }

  if ($score >= 0) {
    if ($self->{doCache}) {
      $self->{simCache}->{"${wps1}::$wps2"} = $score;
      if ($self->{trace}) {
	$self->{traceCache}->{"${wps1}::$wps2"} = $self->{traceString}
      }
      push (@{$self->{cacheQ}}, "${wps1}::$wps2");
      if ($self->{maxCacheSize} >= 0) {
	while (scalar (@{$self->{cacheQ}}) > $self->{maxCacheSize}) {
	  my $delItem = shift(@{$self->{'cacheQ'}});
	  delete $self->{'simCache'}->{$delItem};
	  delete $self->{'traceCache'}->{$delItem};
	}
      }
    }
  }
  else {
    $self->{errorString} .= "Warning (WordNet::Similarity::wup->getRelatedness()) - ";
    $self->{errorString} .= "Similarity score is less than 0.";
    $self->{error} = ($self->{error} < 1) ? 1 : $self->{error};
    return undef;
  }
  return $score;
}

sub getTraceString () {
  my $self = shift;
  my $str = $self->{traceString};
  $self->{traceString} = "" if $self->{trace};
  $str =~ s/\n{2,}$/\n/;
  return $str;
}

sub getError () {
  my $self = shift;
  my $error = $self->{error};
  my $errorString = $self->{errorString};
  $self->{error} = 0;
  $self->{errorString} = "";
  $errorString =~ s/^\n*//;
  return ($error, $errorString);
}

#parameters: 2 concepts, $wps1 and $wps2, in word#pos#sense format
#returns: the lowest common subsumer of $wps1 and $wps2 or "*ROOT*" or undef
sub getLCS {
  my $self = shift;
  my ($wps1, $wps2) = @_;
  $wps1 =~ m/^\S+\#([nv])\#\d+$/;
  my $pos1 = $1;
  $wps2 =~ m/^\S+\#([nv])\#\d+$/;
  my $pos2 = $1;
  if ($pos1 ne $pos2) {
    $self->{errorString} .= "\nError (WordNet::Similarity::wup->getLCS()) - ";
    $self->{errorString} .= "Cannot find a common subsumer across parts of speech.";
    $self->{error} = 2;
    return undef;
  }

  # $wps1 could be a hypernym of $wps2 or vice-versa
  my @subsumers1 = $self->getAllSubsumers($wps1);
  my @subsumers2 = $self->getAllSubsumers($wps2);

  # first, check if $wps1 subsumes $wps2
  foreach my $level_ref (@subsumers2) {
    foreach my $concept (@$level_ref) {
      return $wps1 if $wps1 eq $concept;
    }
  }
  # now check if $wps2 subsumes $wps1
  foreach my $level_ref (@subsumers1) {
    foreach my $concept (@$level_ref) {
      return $wps2 if $wps2 eq $concept;
    }
  }

  # at least it runs in polynomial time!
  foreach my $level_ref1 (@subsumers1) {
    foreach my $concept1 (@$level_ref1) {
      foreach my $level_ref2 (@subsumers2) {
	foreach my $concept2 (@$level_ref2) {
	  return $concept1 if $concept1 eq $concept2;
	}
      }
    }
  }

  return ($pos1 eq 'n') ? "*Root*#n#1" : "*Root*#v#1";
}

sub getAllSubsumers {
  my $self = shift;
  my $wps = shift;
  my $wn = $self->{wn};
  my @rtn;

  # what if there's more than one path to the root?  what if the paths
  # are not of the same length?
  my @subsumers = $wn->querySense($wps, "hype");
  if (scalar @subsumers) {
    push @rtn, [@subsumers];

    do {
      my @new_subsumers;
      foreach my $subsumer (@subsumers) {
	push @new_subsumers, $wn->querySense($subsumer, "hype");
      }
      push @rtn, [@new_subsumers] if scalar @new_subsumers;
      @subsumers = @new_subsumers;
      @new_subsumers = ();
    } while (scalar @subsumers);
  }
  return @rtn;
}

sub getHypertree {
  my $self = shift;
  my $wps = shift;
  my $wn = $self->{wn};

  my @hypernyms = $wps;
  my @t = $wps;
  do {
    my @r = ();
    foreach my $t (@t) {
      push @r, $wn->querySense ($t, "hype");
    }
    unshift @hypernyms, @r if scalar @r;
    @t = @r;
  } while (scalar @t);


  $wps =~ m/^\S\#([nvar])\#\d+$/;
  unshift @hypernyms, "*Root*#$1#1";
  my $rtn = join ' ', @hypernyms;
  return $rtn;
}

#parameter: a concept, $wps, in word#pos#sense format
#returns: the length of the shortest path from $wps to the root
sub getDepth {
  my $self = shift;
  my $wps = shift;
  my $wn = $self->{wn};

  $wps =~ m/\S+\#(\w+)\#\d+/;
  my $pos = $1;
  if (($pos eq 'n') or ($pos eq 'v')) {
    return 0 if $wps =~ m/\*Root\*/i;

    my @hypernyms = $wn->querySense ($wps, "hype");
    if (!scalar @hypernyms) {
      return 1; # return 1 to simulate a unique root node
    }

    my $min_depth = -1;
    foreach my $hypernym (@hypernyms) {
      my $depth = $self->getDepth ($hypernym);
      if (($min_depth < 0) or ($depth < $min_depth)) {
	$min_depth = $depth;
      }
    }
    return $min_depth + 1;
  }
  else {
    $self->{errorString} .= "\nError (WordNet::Similarity::wup->getDepth()) - ";
    $self->{errorString} .= "Unsupported part of speech: $pos";
    $self->{error} = 2;
    return undef;
  }
}


1;

__END__

=head1 NAME

WordNet::Similarity::wup - Perl module for computing semantic
relatedness of word senses using the edge counting method of the
Resnik (1999) revision of Wu & Palmer (1994)

=head1 SYNOPSIS

use WordNet::Similarity::wup;

use WordNet::QueryData;

my $wn = WordNet::QueryData->new();

my $object = WordNet::Similarity::wup->new($wn);

my $value = $object->getRelatedness('dog#n#1', 'cat#n#1');

my ($error, $errorString) = $object->getError();

die "$errorString" if $error;

print "dog (sense 1) <-> cat (sense 1) = $value\n";

=head1 DESCRIPTION

Resnik (1999) revises the Wu & Palmer (1994) method of measuring semantic
relatedness.  Resnik uses use an edge distance method by taking into
account the most specific node subsuming the two concepts.

=head1 USAGE

The semantic relatedness modules in this distribution are built as classes that expose the following methods:

new()

getRelatedness()

getError()

getTraceString()

See the WordNet::Similarity(3) documentation for details of these methods.

=head1 TYPICAL USAGE EXAMPLES

  use WordNet::Similarity::wup;
  my $measure->new($wn, 'wup.conf');

'$wn' contains a WordNet::QueryData object that should have been
constructed already.  The second (and optional) parameter to the 'new'
method is the path of a configuration file for the Wu-Palmer measure.
If the 'new' method is unable to construct the object, then '$measure'
will be undefined.  This may be tested.

  my ($error, $errorString) = $measure->getError ();
  die $errorString."\n" if $err;

To find the sematic relatedness of the first sense of the noun 'car' and
the second sense of the noun 'bus' using the measure, we would write
the following piece of code:

  $relatedness = $measure->getRelatedness('car#n#1', 'bus#n#2');

To get traces for the above computation:

  print $measure->getTraceString();

However, traces must be enabled using configuration files. By default
traces are turned off.

=head1 CONFIGURATION FILE

The behavior of the measures of semantic relatedness can be controlled
by using configuration files.  These configuration files specify how
certain parameters are initialized with the object.  A configuration file
may be specified as a parameter during the creation of an object using
the new method.  The configuration files must follow a fixed format.

Every configuration file starts with the name of the module ON THE FIRST
LINE of the file.  For example, a configuration file for the wup module
will have on the first line 'WordNet::Similarity::wup'.  This is followed
by the various parameters, each on a new line and having the form
'name::value'.  The 'value' of a parameter is option (in the case of boolean
parameters).  In case 'value' is omitted, we would have just 'name::' on 
that line.  Comments are allowed in the configuration file.  Anything
following a '#' is ignored till the end of the line.

The module parses the configuration file and recognizes the following
parameters:

(a) 'trace::' -- can take values 0, 1, or 2 or the value can be omitted, in
which case it sets the trace level to 1.  Trace level 0 implies no traces.
Trace level 1 and 2 imply tracing is 'on', the only difference being the
way in which the synsets are displayed in the traces.  For trace level 1, the
sysnsets are represented in word#pos#sense strings, while for level 2, the
sysnets are represented as word#pos#offset strings.

(b) 'cache::' -- can take values 0 or 1 or the value can be omitted, in
which case it takes the value 1, i.e., switches 'on' caching.  A value of
0 switches caching 'off'.  By default caching is enabled.

(c) 'cachesize::' -- can take any non-negative integer value or the value
can be omitted, in which case it takes the value 1000.  A value, n, such that
n > 0 means that n relatedness queries will be cached.  If n = 0, then no
queries will be cached.  Setting cachesize to zero has the same effect as
setting cache to zero, but setting cache to zero is more efficient.  Caching
and tracing at the same time can result in excessive memory usage because
the trace strings are also cached.  If you intend to perform a large number of
relatedness queries, then you should probably turn tracing off.

=head1 SEE ALSO

perl(1), WordNet::Similarity(3), WordNet::QueryData(3)

http://www.d.umn.edu/~mich0212/

http://www.d.umn.edu/~tpederse/similarity.html

http://www.cogsci.princeton.edu/~wn/

http://www.ai.mit.edu/people/jrennie/WordNet/

=head1 AUTHORS

  Jason Michelizzi, <mich0212@d.umn.edu>
  Ted Pedersen, <tpederse@d.umn.edu>
  Siddharth Patwardhan <sidd@cs.utah.edu>

=head1 COPYRIGHT AND LICENSE

Copyright 2003 by Jason Michelizzi, Ted Pedersen, and Siddharth Patwardhan

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
