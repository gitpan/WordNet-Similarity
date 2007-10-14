# This script generates default infocontent files for WordNet::Similarity
# (Last updated $Id: Infocontent.PL,v 1.1 2007/10/09 12:05:39 sidz1979 Exp $)
#
# ----------------------------------------------------------------------------

print STDERR "Generating default information content files.\n";
my $fname = shift;
die "Undefined information content file specified.\n" if(!defined($fname));
@ARGV = ("--outfile=$fname"); 
if(open(WNPATH, "build/wnpath.txt"))
{
  my $wndictpath = <WNPATH>;
  $wndictpath =~ s/[\r\f\n]+//g;
  $wndictpath =~ s/^\s+//;
  $wndictpath =~ s/\s+$//;
  push(@ARGV, "--wnpath=$wndictpath");
  close(WNPATH);
}
require "utils/semCorFreq.pl";
if(-z $fname) 
{
  print STDERR "Error: Failed to create default infocontent file.\n";
  exit(1);
}
