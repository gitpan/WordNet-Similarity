# WordNet::Tools v2.01
# (Last updated $Id: Tools.pm,v 1.1 2007/10/09 12:05:39 sidz1979 Exp $)

package WordNet::Tools;

=head1 NAME

WordNet::Tools - Some tools for use with WordNet.

=head1 SYNOPSIS

  use WordNet::QueryData;

  use WordNet::Tools;

  my $wn = WordNet::QueryData->new;

  my $wntools = WordNet::Tools->new($wn);

  my $wnHashCode = $wntools->hashCode();

  my $newstring = $wntools->compoundify("find compound words like new york city in this text");

=head1 DESCRIPTION

This module provides some tools for use with WordNet. For example, the
'compoundify' method detects compound words (as found in WordNet) in a
text string and it combines these words into single tokens using
underscore separators. Another tool in this module generates a unique
hash code corresponding to a WordNet distribution. This hash code is
meant to replace the "version" information in WordNet, which is no
longer reliable.

=head1 METHODS

The following methods are defined:

=over

=cut

use strict;
use warnings;
use Exporter;
use WordNet::QueryData;
use Digest::SHA1  qw(sha1_base64);

our @ISA = qw(Exporter);
our $VERSION = '2.01';

=item WordNet::Tools->new($wn)

This is a constructor for this class (and creates a new object of this
class). It requires a WordNet::QueryData object as a parameter.

Parameters: $wn -- a WordNet::QueryData object.

Returns: a new WordNet::Tools object.

=cut

# Constructor for this module
sub new
{
  my $class = shift;
  my $wn    = shift;
  my $self  = {};

  # Create the preprocessor object
  $class = ref $class || $class;
  bless($self, $class);

  # Verify the given WordNet::QueryData object
  return undef if(!defined $wn || !ref $wn || ref($wn) ne "WordNet::QueryData");
  $self->{wn} = $wn;

  # Get the compounds from WordNet
  foreach my $pos ('n', 'v', 'a', 'r')
  {
    foreach my $word ($wn->listAllWords($pos))
    {
      $self->{compounds}->{$word} = 1 if ($word =~ /_/);
    }
  }

  # Compute the WordNet hash-code and store
  $self->{hashcode} = $self->_computeHashCode();
  return undef if(!defined($self->{hashcode}));

  return $self;
}

=item $wntools->compoundify($string)

This is method identifies all compound words occurring in the given input
string. Compound words are multi-word tokens appearing in WordNet.

Parameters: $string -- an input text string.

Returns: a string with compound words identified.

=cut

# Detect compounds in a block of text
sub compoundify
{
  my $self  = shift;
  my $block = shift;

  return $block if(!defined $block || !ref $self || !defined $self->{compounds});

  my $string;
  my $done;
  my $temp;
  my $firstPointer;
  my $secondPointer;
  my @wordsArray;

  # get all the words into an array
  @wordsArray = ();
  while($block =~ /(\w+)/g)
  {
    push(@wordsArray, $1);
  }

  # now compoundify, GREEDILY!!
  $firstPointer = 0;
  $string = "";

  while($firstPointer <= $#wordsArray)
  {
    $secondPointer = (($#wordsArray > ($firstPointer + 7)) ? ($firstPointer + 7) : ($#wordsArray));
    $done = 0;
    while(($secondPointer > $firstPointer) && !$done)
    {
      $temp = join("_", @wordsArray[$firstPointer .. $secondPointer]);
      if(defined $self->{compounds}->{$temp})
      {
        $string .= "$temp ";
        $done = 1;
      }
      else
      {
        $secondPointer--;
      }
    }
    $string .= "$wordsArray[$firstPointer] " unless($done);
    $firstPointer = $secondPointer + 1;
  }
  $string =~ s/\s+$//;

  return $string;
}

=item $wntools->hashCode()

This is method returns a unique identifier representing a specific
distribution of WordNet.

Parameters: none.

Returns: a unique identifier (string).

=cut

# Return the computed hash-code
sub hashCode
{
  my $self = shift;
  return $self->{hashcode};
}

# Compute the hash code for the given WordNet distribution
# Most of this code was written by Ben Haskell <ben at clarity dot princeton dot edu>
sub _computeHashCode
{
  my $self = shift;
  my $qd = $self->{wn};
  return undef if(!defined($qd));

  my $dir = $qd->dataPath();
  my $pos = '{noun,verb,adj,adv}';
  my @files = sort grep -f, map glob("\Q$dir\E/$_"), "{index,data}.$pos", "$pos.{idx,dat}";

  # (stat)[7] returns file size in bytes
  my $concat = join '.', map { (stat)[7] } @files;
  return sha1_base64($concat);
}

1;

__END__

=back

=head1 EXPORT

None by default.

=head1 SEE ALSO

perl(1)

WordNet::QueryData(3)

=head1 AUTHORS

Ted Pedersen, tpederse at d.umn.edu

Siddharth Patwardhan, sidd at cs.utah.edu

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2005 by Ted Pedersen and Siddharth Patwardhan

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.3 or,
at your option, any later version of Perl 5 you may have available.

=cut
