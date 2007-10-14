# This script generates default depth files for WordNet::Similarity
# (Last updated $Id: Depthfiles.PL,v 1.1 2007/10/09 12:05:39 sidz1979 Exp $)
#
# ----------------------------------------------------------------------------

print STDERR "Generating default depth files.\n";
my $synsetsfile = shift;
die "Undefined synset depths file.\n" if(!defined($synsetsfile));
my $taxonomyfile = $synsetsfile;
$taxonomyfile =~ s/[a-zA-Z_\.]+$/treedepths.dat/;
@ARGV = ("--outfile=$taxonomyfile", "--depthfile=$synsetsfile");
if(open(WNPATH, "build/wnpath.txt"))
{
  my $wndictpath = <WNPATH>;
  $wndictpath =~ s/[\r\f\n]+//g;
  $wndictpath =~ s/^\s+//;
  $wndictpath =~ s/\s+$//;
  push(@ARGV, "--wnpath=$wndictpath");
  close(WNPATH);
}
require "utils/wnDepths.pl";
if(-z $synsetsfile or -z $taxonomyfile)
{
  print STDERR "Error: failed to create WordNet depths files.\n";
  exit(1);
}
