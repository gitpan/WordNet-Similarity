# WordNet::Similarity.pm version 0.03
# (Updated 03/10/2003 -- Sid)
#
# Module containing the version information and pod 
# for the WordNet::Similarity package.
#
# Copyright (c) 2003,
# Satanjeev Banerjee, Carnegie Mellon University, Pittsburgh
# banerjee+@cs.cmu.edu
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

package WordNet::Similarity;

use 5.005;
use strict;

require Exporter;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

@ISA = qw(Exporter);

%EXPORT_TAGS = ();

@EXPORT_OK = ();

@EXPORT = ();

$VERSION = '0.03';

1;

__END__

=head1 NAME

WordNet::Similarity - Perl extensions for computing semantic relatedness
of word senses defined in WordNet.

=head1 SYNOPSIS

=head2 # Basic Usage Example

use WordNet::QueryData;

use WordNet::Similarity::jcn;

my $wn = WordNet::QueryData->new();

my $measure = WordNet::Similarity::jcn->new($wn);

my $value = $measure->getRelatedness("car#n#1", "bus#n#2");

($error, $errorString) = $measure->getError();

die "$errorString\n" if($error);

print "car (sense 1) <-> bus (sense 2) = $value\n";

=head2 # Using a configuration file to initialize the measure

use WordNet::Similarity::edge;

my $sim = WordNet::Similarity::edge->new($wn, "/home/sid/edge.conf");

my $value = $sim->getRelatedness("dog#n#1", "cat#n#1");

($error, $errorString) = $sim->getError();

die "$errorString\n" if($error);

print "dog (sense 1) <-> cat (sense 1) = $value\n";

=head2 Printing traces

print "Trace String -> ".($sim->getTraceString())."\n";

=head1 ABSTRACT

  We observe that humans find it extremely easy to say if two words are
related and if one word is more related to a given word than another. For
example, if we come across two words -- 'car' and 'bicycle', we know they
are related as both are means of transport. Also, we easily observe that
'bicycle' is more related to 'car' than 'fork' is. But is there some way to
assign a quantitative value to this relatedness? Some ideas have been put
forth by researchers to quantify the concept of relatedness of words, with
encouraging results.

  Six of these different measures of relatedness have been implemented in
this software package. A simple edge counting measure and a random measure 
have also been provided. These measures rely heavily on the vast store of
knowledge available in the online electronic dictionary -- WordNet. So, we
use a Perl interface for WordNet called WordNet::QueryData to make it
easier for us to access WordNet. The modules in this package REQUIRE that 
the WordNet::QueryData module be installed on the system before these 
modules are installed.

=head1 DESCRIPTION

  This package consists of Perl modules along with supporting Perl programs
that implement the semantic distance measures described by Leacock Chodorow
(1998), Jiang Conrath (1997), Resnik (1995), Lin (1998), Hirst St Onge
(1998) and the adapted Lesk measure by Banerjee and Pedersen (2002). The 
package contains Perl modules designed as object classes with methods that 
take as input two word senses. The semantic distance between these word 
senses is returned by these methods. A quantitative measure of the degree 
to which two word senses are related has wide ranging applications in 
numerous areas, such as word sense disambiguation, information retrieval,
etc. For example, in order to determine which sense of a given word is being 
used in a particular context, the sense having the highest relatedness with 
its context word senses is most likely to be the sense being used. Similarly,
in information retrieval, retrieving documents containing highly related
concepts are more likely to have higher precision and recall values.

  A command line interface to these modules is also present in the
package. The simple, user-friendly interface simply returns the relatedness
measure of two given words. Number of switches and options have been
provided to modify the output and enhance it with trace information and
other useful output. Support programs for generating information
content files from various corpora are also available in the package. The
information content files are required by three of the measures for
computing the relatedness of two concepts.

=head1 USAGE

  The semantic relatedness modules in this distribution are built as classes
that expose the following methods:
  new()
  getRelatedness()
  getError()
  getTraceString()

=head2 new()

  The first thing that is done in order to use one of the semantic
relatedness measures is to create an object of the measure. This is done by
calling the 'new' method of that measure or module. For all the semantic
relatedness measures provided in this package, the 'new' method takes two
parameters -- 
    (a) a WordNet::QueryData object (REQUIRED)
    (b) the name of a configuration file for that module (Optional)
  This method initializes an object of the requested measure, using the
configuration file data, or with default values if a configuration file is
not provided. A reference to this object is returned by the 'new' method
and must be saved by the calling program, if any of the other methods of
this module are to be called. It is possible to create multiple objects of
the same module (possibly initialized differently by specifying different
configuration files for each). The format of the configuration files is
discussed later in this section.

  An 'undef' value returned by the 'new' method, indicates that it was unable
to create an object. It is also possible that non-fatal errors occur during
the creation of the object. In this case an object is created by the 'new'
method using default conditions. However, a non-fatal error condition flag
is set within the object, which can be retrieved using the getError()
method. It is advisable to check for this error condition after the
creation of every such object.

=head2 getRelatedness()

  The 'getRelatedness' method is called on the created object to determine
the semantic relatedness of two concepts (synsets in WordNet) as computed
by that measure. The input parameters are two WordNet synsets, represented
in the word#pos#sense format returned/used by WordNet::QueryData. In this
format each synset is represented by a word from that synset, its
part-of-speech and its sense number. For example, if the second sense of
'teacher' as a noun occurs in a synset containing synonyms for 'teacher',
then this synset can be represented by the string 'teacher#n#2'. The
'getRelatedness' method takes as input two strings of this form and returns
a floating point value, which is the semantic relatedness of these (as
computed by the measure).

=head2 getError()

  During a call to either the 'new' method or the 'getRelatedness' method
of a measure, if a fatal or non-fatal error occurs, the module sets an
error flag within the created object and sets an error string within (the
exception to this is when the module is unable to create an object upon a
call to the 'new' method, in which case it simply returns 'undef'). Both
the error condition flag and the error string can be retrieved using the
'getError' method on the created object. The method is called without any
parameters and it returns an array containing the error flag as the first
element and the error string as the second element. The error flag can take
the values 0, 1 or 2. A value of 0 indicates that there was no error or
warning since the last call to 'getError'. 1 indicates that there was/were
non-fatal error(s) (warnings) since the last call to 'getError'. A value of
2 usually indicates that the errors were serious enough to warrant the
termination of the program. However, how these errors are handled is
completely upto the writing the Perl program. It is advisable that the
error flag be checked after every call to either 'new' or 'getRelatedness',
but this is not a necessary step and the error condition may be tested at
less regular intervals also.

=head2 getTraceString()

  If traces are enabled, a trace string generated during the last call to the
'getRelatedness' method is stored within the object. This trace string can
be retrieved using the 'getTraceString' method. This method is called with
no parameters and returns a scalar containing the most recently generated
trace string. By default traces are not enabled. Traces can be enabled by
specifying this as an option in the configuration file for the
measure. Instructions for writing configuration files for the measures
follow in later sections.

=head1 TYPICAL USAGE EXAMPLES

  To create an object of the Resnik measure, we would have the following
lines of code in the Perl program. 

   use WordNet::Similarity::res;
   $object = WordNet::Similarity::res->new($wn, '/home/sid/resnik.conf');

The reference of the initialized object is stored in the scalar variable
'$object'. '$wn' contains a WordNet::QueryData object that should have been
created earlier in the program. The second parameter to the 'new' method is
the path of the configuration file for the resnik measure. If the 'new'
method is unable to create the object, '$object' would be undefined. This, as
well as any other error/warning may be tested.

   die "Unable to create resnik object.\n" if(!defined $object);
   ($err, $errString) = $object->getError();
   die $errString."\n" if($err);

To create a Leacock-Chodorow measure object, using default values, i.e. no
configuration file, we would have the following:

   use WordNet::Similarity::lch;
   $measure = WordNet::Similarity::lch->new($wn);

To find the sematic relatedness of the first sense of the noun 'car' and
the second sense of the noun 'bus' using the resnik measure, we would write
the following piece of code:

   $relatedness = $object->getRelatedness('car#n#1', 'bus#n#2');
  
To get traces for the above computation:

   print $object->getTraceString();

However, traces must be enabled using configuration files. By default
traces are turned off.

=head1 CONFIGURATION FILES

  The behaviour of the measures of semantic relatedness can be controlled by
using configuration files. These configuration files specify how certain
parameters are initialized within the object. A configuration file may be
specififed as a parameter during the creation of an object using the new
method. The configuration files must follow a fixed format.

  Every configuration file starts the name of the module ON THE FIRST LINE of
the file. For example, a configuration file for the Resnik module will have
on the first line 'WordNet::Similarity::res'. This is followed by the various
parameters, each on a new line and having the form 'name::value'. The
'value' of a parameter is optional (in case of boolean parameters). In case
'value' is omitted, we would have just 'name::' on that line. Comments are
supported in the configuration file. Anything following a '#' is ignored in
the configuration file.

  Sample configuration files are present in the '/samples' subdirectory of
the package. Each of the modules has specific parameters that can be
set/reset using the configuration files. Please read the manpages or the
perldocs of the respective modules for details on the parameters specific
to each of the modules. For instance, 'man WordNet::Similarity::res' or
'perldoc WordNet::Similarity::res' should display the documentation for the
Resnik module.

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

For example, if WordNet version 1.7.1 was used for creation of the
information content file, the following line would be present at the start
of the information content file.

wnver::1.7.1

The rest of the file contains on each line a WordNet synset offset, 
part-of-speech and a frequency count, in the form

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

=head1 SEE ALSO

perl(1), WordNet::Similarity::jcn(3), WordNet::Similarity::res(3), WordNet::Similarity::lin(3), 
WordNet::Similarity::lch(3), WordNet::Similarity::hso(3), WordNet::Similarity::lesk(3),
WordNet::Similarity::edge(3), WordNet::Similarity::random(3), WordNet::QueryData(3)

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
