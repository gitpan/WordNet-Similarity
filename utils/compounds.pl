#!/usr/local/bin/perl -w
#
# compounds.pl ver 0.6
# (Updated 08/29/2003 -- Sid)
#
# Program to generate a list of all compound words 
# present in WordNet.
#
# Copyright (c) 2002-2003
#
# Ted Pedersen, University of Minnesota, Duluth
# tpederse@d.umn.edu
#
# Satanjeev Banerjee, Carnegie Mellon University, Pittsburgh
# banerjee+@cs.cmu.edu
#
# Siddharth Patwardhan, University of Utah, Salt Lake City
# sidd@cs.utah.edu
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to: 
#
#    The Free Software Foundation, Inc., 
#    59 Temple Place - Suite 330, 
#    Boston, MA  02111-1307, USA.
#
#
#-----------------------------------------------------------------------------

use Getopt::Long;

# Now get the options!
&GetOptions("version", "help", "wnpath=s");

# If the version information has been requested
if(defined $opt_version)
{
    $opt_version = 1;
    &printVersion();
    exit;
}

# If detailed help has been requested
if(defined $opt_help)
{
    $opt_help = 1;
    &printHelp();
    exit;
}

# Check if path to WordNet Data files has been provided ... If so ... save it.
if(defined $opt_wnpath)
{
    $wnPCPath = $opt_wnpath;
    $wnUnixPath = $opt_wnpath;
}
else
{
    $wnPCPath = (defined $ENV{"WNHOME"}) ? $ENV{"WNHOME"} : "C:\\Program Files\\WordNet\\1.7.1";
    $wnUnixPath = (defined $ENV{"WNHOME"}) ? $ENV{"WNHOME"} : "/usr/local/WordNet-1.7.1";
    $wnPCPath = (defined $ENV{"WNSEARCHDIR"}) ? $ENV{"WNSEARCHDIR"} : $wnPCPath."\\dict";
    $wnUnixPath = (defined $ENV{"WNSEARCHDIR"}) ? $ENV{"WNSEARCHDIR"} : $wnUnixPath."/dict";    
}

open(NIDX, $wnUnixPath."/index.noun") || open(NIDX, $wnPCPath."\\noun.idx") || die "Unable to open index file.\n";
open(VIDX, $wnUnixPath."/index.verb") || open(VIDX, $wnPCPath."\\verb.idx") || die "Unable to open index file.\n";
open(AIDX, $wnUnixPath."/index.adj") || open(AIDX, $wnPCPath."\\adj.idx") || die "Unable to open index file.\n";
open(RIDX, $wnUnixPath."/index.adv") || open(RIDX, $wnPCPath."\\adv.idx") || die "Unable to open index file.\n";
foreach(1 .. 29)
{
    $line = <NIDX>;
}
while($line = <NIDX>)
{
    $line =~ s/[\r\f\n]//g;
    $line =~ s/^\s+//;
    $line =~ s/\s+$//;
    ($word) = split(/\s+/, $line, 2);
    print "$word\n" if($word =~ /_/);
}

foreach(1 .. 29)
{
    $line = <VIDX>;
}
while($line = <VIDX>)
{
    $line =~ s/[\r\f\n]//g;
    $line =~ s/^\s+//;
    $line =~ s/\s+$//;
    ($word) = split(/\s+/, $line, 2);
    print "$word\n" if($word =~ /_/);
}

foreach(1 .. 29)
{
    $line = <AIDX>;
}
while($line = <AIDX>)
{
    $line =~ s/[\r\f\n]//g;
    $line =~ s/^\s+//;
    $line =~ s/\s+$//;
    ($word) = split(/\s+/, $line, 2);
    print "$word\n" if($word =~ /_/);
}

foreach(1 .. 29)
{
    $line = <RIDX>;
}
while($line = <RIDX>)
{
    $line =~ s/[\r\f\n]//g;
    $line =~ s/^\s+//;
    $line =~ s/\s+$//;
    ($word) = split(/\s+/, $line, 2);
    print "$word\n" if($word =~ /_/);
}

close(NIDX);
close(VIDX);
close(AIDX);
close(RIDX);

# Subroutine to print detailed help
sub printHelp
{
    &printUsage();
    print "\nThis program generates a list of all compound words found\n";
    print "in WordNet\n";
    print "Options: \n";
    print "--wnpath         WNPATH specifies the path of the WordNet data files.\n";
    print "                 Ordinarily, this path is determined from the \$WNHOME\n";
    print "                 environment variable. But this option overides this\n";
    print "                 behavior.\n";
    print "--help           Displays this help screen.\n";
    print "--version        Displays version information.\n\n";
}

# Subroutine to print minimal usage notes
sub minimalUsageNotes
{
    &printUsage();
    print "Type compounds.pl --help for detailed help.\n";
}

# Subroutine that prints the usage
sub printUsage
{
    print "compounds.pl [{ --wnpath WNPATH | --help | --version }]\n"
}

# Subroutine to print the version information
sub printVersion
{
    print "compounds.pl version 0.6\n";
    print "Copyright (c) 2002-2003 Ted Pedersen, Satanjeev Banerjee & Siddharth Patwardhan.\n";
}
