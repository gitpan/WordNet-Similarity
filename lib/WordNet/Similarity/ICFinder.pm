# WordNet::Similarity::ICFinder.pm version 0.07
# (Updated 1/30/2004 -- Jason)
#
# A generic (and abstract) information content measure--this is not a
# real measure.  The res, lin, and jcn measures inherit from this class.
#

package WordNet::Similarity::ICFinder;

=head1 NAME

WordNet::Similarity::ICFinder - a module for finding the information content
of concepts in WordNet

=head1 SYNOPSIS

use WordNet::Similarity::ICFinder;

my $module = new WordNet::Similarity::ICFinder;

my $ic = $module->IC ('dog#n#1', 'n', 'wps');

my $p = $module->probability (14429, 'v', 'offset');

my $freq = $module->getFrequency (2340529, 'v', 'offset');

=head1 DESCRIPTION

=head2 Introduction

Three of the measures provided within the package require information
content values of concepts (WordNet synsets) for computing the semantic
relatedness of concepts. Resnik (1995) describes a method for computing the
information content of concepts from large corpora of text. In order to
compute information content of concepts, according to the method described
in the paper, we require the frequency of occurrence of every concept in a
large corpus of text. We provide these frequency counts to the three
measures (Resnik, Jiang-Conrath and Lin measures) in files that we call
information content files. These files contain a list of WordNet synset
offsets along with their part of speech and frequency count. The files are 
also used to determine the topmost nodes of the noun and verb 'is-a' 
hierarchies in WordNet. The information content file to be used is specified 
in the configuration file for the measure. If no information content file is 
specified, then the default information content file, generated at the time 
of the installation of the WordNet::Similarity modules, is used. A description 
of the format of these files follows. The FIRST LINE of this file must contain 
the version of WordNet the the file was created with. This should be present 
as a string of the form

  wnver::<version>

For example, if WordNet version 2.0 was used for creation of the
information content file, the following line would be present at the start
of the information content file.

  wnver::2.0

The rest of the file contains on each line, a WordNet synset offset, 
part-of-speech and a frequency count, of the form

  <offset><part-of-speech> <frequency> [ROOT]

without any leading or trailing spaces. For example, one of the lines of an
information content file may be as follows.

  63723n 667

where '63723' is a noun synset offset and 667 is its frequency
count. Suppose the noun synset with offset 1740 is the root node of one of 
the noun taxonomies and has a frequency count of 17625. Then this synset would 
appear in an information content file as follows:

  1740n 17625 ROOT

The ROOT tags are extremely significant in determining the top of the 
hierarchies and must not be omitted. Typically, frequency counts for the noun
and verb hierarchies are present in each information content file.
A number of support programs to generate these files from various corpora 
are present in the '/utils' directory of the package. A sample information 
content file has been provided in the '/samples' directory of the package.

=head2 Methods

The following methodes are provided by this module.

=head3 Public Methods

=over

=cut

use strict;
use warnings;

use WordNet::Similarity::PathFinder;

our @ISA = qw/WordNet::Similarity::PathFinder/;

our $VERSION = '0.07';

WordNet::Similarity::addConfigOption ('infocontent', ':', 'p', undef);


=item $module->traceOptions (Z<>)

Prints status of configuration options specific to this module to
the trace string.  This module has only one such options: infocontent.

=cut

sub traceOptions {
  my $self = shift;
  $self->{traceString} .= "infocontent :: $self->{infocontent}\n";
  $self->SUPER::traceOptions;
}



=item $module->probability ($synset, $pos, $mode)

Returns the probability of $synset in a corpus (using frequency values
from whatever information content file is being used).  If $synset
is a wps string, then $mode must be 'wps'; if $synset is an offset,
then $mode must be 'offset'.

=cut

sub probability {
  my $self = shift;
  my $con = shift;
  my $pos = shift;
  my $class = ref $self || $self;

  my $rootFreq = $self->{offsetFreq}->{$pos}->{0};
  my $conFreq = $self->{offsetFreq}->{$pos}->{$con};
  if($rootFreq && defined $conFreq) {
    if($conFreq <= $rootFreq) {
      return $conFreq / $rootFreq;
    }
    else {
      $self->{errorString} .= "\nError (${class}::probability()) - ";
      $self->{errorString} .= "Probability greater than 1? (Check information content file)";
      $self->{error} = 2;
      return 0;
    }
  }
  else {
    return 0;
  }
}


=item $module->IC ($synset, $pos, $mode)

Returns the information content of $synset.  If $synset is a wps string,
then $mode must be 'wps'; if $synset is an offset, then $mode must be
'offset'.

=cut

sub IC
{
  my $self = shift;
  my $offset = shift;
  my $pos = shift;
  if($pos =~ /[nv]/) {
    my $prob = $self->probability($offset, $pos);
    return ($prob > 0) ? -log($prob) : 0;
  }
  return 0;
}

=item $module->getFrequency ($synset, $pos, $mode)

Returns the frequency of $synset in whatever information content file
is currently being used.

If $synset is a wps string, then the mode must be 'wps'; if $synset
is an offset, then $mode must be 'offset'.

Usually the C<IC()> and C<probability()> methods will be more useful
than this method.  This method is useful in determining if the
frequency of a synset was 0.

=cut

sub getFrequency
{
  my $self = shift;
  my $wn = $self->{wn};
  my ($synset, $pos, $mode) = @_;

  my $offset;
  if ($mode eq 'wps') {
    $offset = $wn->offset ($synset);
  }
  else {
    $offset = $synset;
  }
  my $freq = $self->{offsetFreq}->{$pos}->{$offset};
  return $freq;
}


=item $module->configure (Z<>)

Overrides the configure method of WordNet::Similarity to process the
information content file (also calles WordNet::Similarity::configure()
so that all the work done by that method is still accomplished).

=cut

sub configure {
  my $self = shift;
  $self->SUPER::configure (@_);
  my $wn = $self->{wn};
  my $class = ref $self || $self;

  unless (defined $self->{infocontent}) {
    # look for info content file
    my $path;
    my $wnver;
    my @possiblePaths = ();

    # Look for all possible default data files installed.
    foreach $path (@INC) {
      if(-e $path."/WordNet/ic-semcor.dat") {
	push @possiblePaths, $path."/WordNet/ic-semcor.dat";
      }
      elsif(-e $path."\\WordNet\\ic-semcor.dat") {
	push @possiblePaths, $path."\\WordNet\\ic-semcor.dat";
      }
    }

    # If there are multiple possibilities, get the one that matches the
    # the installed version of WordNet.
    foreach $path (@possiblePaths) {
      if (open (ICF, $path)) {
	my $wnver = <ICF>;
	$wnver =~ s/[\r\f\n\t ]+//g;
	if ($wnver =~ /wnver::(.*)/) {
	  $wnver = $1;
	  if (defined $wnver && $wnver eq $wn->version()) {
	    $self->{infocontent} = $path;
	    close (ICF);
	    last;
	  }
	}
	close (ICF);
      }
    }
  }

  unless (defined $self->{infocontent}) {
    $self->{errorString} .= "Error (${class}::configure()) - ";
    $self->{errorString} .= "Could not find a default information content file\n";
    $self->{error} = 2;
    return;
  }

  unless (open ICF, $self->{infocontent}) {
    $self->{errorString} .= "Error (${class}::configure()) - ";
    $self->{errorString} .= "Could not open information content file $self->{infocontent}\n";
    $self->{error} = 2;
    return;
  }

  # load the info content file data
  my $wnver = <ICF>;
  $wnver =~ s/[\r\f\n\t ]+//g;
  if($wnver =~ /wnver::(.*)/) {
    $wnver = $1;
    if(defined $wnver && $wnver eq $wn->version()) {
      $self->{offsetFreq}->{n}->{0} = 0;
      $self->{offsetFreq}->{v}->{0} = 0;
      while(<ICF>) {
	s/[\r\f\n]//g;
	s/^\s+//;
	s/\s+$//;
	my ($offsetPOS, $frequency, $topmost) = split /\s+/, $_, 3;
	if($offsetPOS =~ /([0-9]+)([nvar])/) {
	  my $curOffset;
	  my $curPOS;

	  $curOffset = $1;
	  $curPOS = $2;
	  $self->{offsetFreq}->{$curPOS}->{$curOffset} = $frequency;
	  if(defined $topmost && $topmost =~ /ROOT/) {
	    $self->{offsetFreq}->{$curPOS}->{0} += $self->{offsetFreq}->{$curPOS}->{$curOffset};
	  }
	}
	else {
	  $self->{errorString} .= "\nError (${class}::configure()) - ";
	  $self->{errorString} .= "Bad file format ($self->{infocontent}).";
	  $self->{error} = 2;
	  return;
	}
      }
    }
    else {
      $self->{errorString} .= "\nError (${class}::configure()) - ";
      $self->{errorString} .= "WordNet version does not match data file.";
      $self->{error} = 2;
      return;
    }
  }
  else {
    $self->{errorString} .= "\nError (${class}::configure()) - ";
    $self->{errorString} .= "Bad file format ($self->{infocontent}).";
    $self->{error} = 2;
    return;		
  }
  close (ICF);

}

=back

=head3 Private Methods

=over

=item $module->_loadInfoContentFile ($file)

Subroutine to load frequency counts from an information content file.

=cut

sub _loadInfoContentFile
{
    my $self = shift;
    my $infoContentFile = shift;
    my $wn = $self->{'wn'};
    my $wnver;
    my $offsetPOS;
    my $frequency;
    my $topmost;
    my $localFreq = {};

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
		$localFreq->{"n"}->{0} = 0;
		$localFreq->{"v"}->{0} = 0;
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
			$localFreq->{$curPOS}->{$curOffset} = $frequency;
			if(defined $topmost && $topmost =~ /ROOT/)
			{
			    $localFreq->{$curPOS}->{0} += $localFreq->{$curPOS}->{$curOffset};
			}
		    }
		    else
		    {
			return "Bad file format ($infoContentFile).";
		    }
		}
	    }
	    else
	    {
		return "WordNet version does not match data file.";
	    }
	}
	else
	{
	    return "Bad file format ($infoContentFile).";
	}
	close(INFOCONTENT);
    }
    else
    {
	return "Unable to open '$infoContentFile'.";
    }

    $self->{'offsetFreq'} = $localFreq;

    return "";
}

=item $module->_isValidInfoContentFile ($filename)

Subroutine that checks the validity of an information content file.

=cut

sub _isValidInfoContentFile
{
    my $self = shift;
    my $path = shift;
    my $wn = $self->{'wn'};
    my $wnver;

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
		close(INFOCONTENT);
		return 1;
	    }
	}
	close(INFOCONTENT);
    }

    return 0;
}

1;

__END__

=back

=head1 AUTHORS

  Jason Michelizzi, Univeristy of Minnesota Duluth
  mich0212 at d.umn.edu

  Siddharth Patwardhan, University of Utah, Salt Lake City
  sidd at cs.utah.edu

  Ted Pedersen, University of Minnesota Duluth
  tpederse at d.umn.edu

=head1 BUGS

None.

To report a bug e-mail tpederse at d.umn.edu or go to
http://groups.yahoo.com/group/wn-similarity/.

=head1 SEE ALSO

WordNet::Similarity(3)
WordNet::Similarity::res(3)
WordNet::Similarity::lin(3)
WordNet::Similarity::jcn(3)

=head1 COPYRIGHT

Copyright (c) 2004, Jason Michelizzi, Siddharth Patwardhan, and Ted Pedersen

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
at <http://www.gnu.org/licenses/gpl.txt> and is included in this
distribution as GPL.txt.

=cut