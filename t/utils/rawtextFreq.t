#!/usr/local/bin/perl

# Before 'make install' is run this script should be runnable with
# 'make test'.  After 'make install' it should work as 'perl rawtextFreq.t'

# A script to test the rawtextFreq.pl utility.  We can't really test most
# of the other infocontent programs (*Freq.pl programs) because the users
# are unlikely to have all or even some of the corpora.  For this test, we
# just run the rawtextFreq.pl program using the GPL as input.

use strict;
use warnings;

use Test::More tests => 27;

BEGIN {use_ok 'File::Spec'}

my $rawtextFreq = File::Spec->catfile ('utils', 'rawtextFreq.pl');
# where's the null device?
my $devnull = File::Spec->devnull;
my $corpus = 'GPL.txt';
my $compfile = File::Spec->catfile ('samples', 'wn20compounds.txt');

ok (-e $devnull);
ok (-e $rawtextFreq);
ok (-r $rawtextFreq);
ok (-x $rawtextFreq);
ok (-e $corpus);
ok (-r $corpus);
ok (-e $compfile);
ok (-r $compfile);

my $outfile = "rtout$$.txt";
my $perl = 'perl';

system "$perl -MExtUtils::testlib $rawtextFreq --compfile=$compfile --outfile=$outfile $corpus 2>$devnull";
is ($?, 0);
ok (-e $outfile);
ok (open FH, "$outfile") or diag "Cannot open temporary file '$outfile': $!";

my $line = <FH>;
ok ($line =~ m/^wnver::([\d\.]+)$/);
my $wnver = $1;

# Test::More lets us use this nifty SKIP block for situations like this.
# Here, we are checking the results only if WordNet 2.0, 1.7.1, 1.7, or 1.6
# is used, otherwise we skip it (versions 2.0 is recommended and 1.7 and
# 1.6 are deprecated).  This is a simple test to ensure that the frequency
# counts are (probably) correct.
SKIP: {
  my $line = <FH>;
  my ($offsetpos, $freq, $isroot) = split qr/\s+/, $line;

  if ($wnver eq '2.0') {
    is ($offsetpos, '1740n');
    is ($freq, 4066);
    ok ($isroot);
  }
  elsif ($wnver eq '1.7.1') {
    is ($offsetpos, '1742n');
    is ($freq, 3808);
    ok ($isroot);
  }
  elsif ($wnver eq '1.7') {
    is ($offsetpos, '1740n');
    is ($freq, 3562);
    ok ($isroot);
  }
  elsif ($wnver eq '1.6') {
    is ($offsetpos, '1740n');
    is ($freq, 2248);
    ok ($isroot);
  }
  else {
    skip ("using an unknown version of WordNet: $wnver", 3);
  }
}

ok (close FH);

# now do it with Resnik counting
system "$perl -MExtUtils::testlib $rawtextFreq --compfile=$compfile --resnik --outfile=$outfile $corpus 2>$devnull";
is ($?, 0);
ok (-e $outfile);
ok (open FH, "$outfile") or diag "Cannot open temporary file '$outfile': $!";

$line = <FH>;
ok ($line =~ m/^wnver::([\d\.]+)$/);
$wnver = $1;

# see note above.  The following block does essentially the same thing,
# except it uses Resnik counting.
SKIP: {
  my $line = <FH>;
  my ($offsetpos, $freq, $isroot) = split qr/\s+/, $line;

  if ($wnver eq '2.0') {
    is ($offsetpos, '1740n');
    # expected frequency is 568.5933
    cmp_ok ($freq, '>=', 568.5);
    cmp_ok ($freq, '<=', 568.6);
    ok ($isroot);
  }
  elsif ($wnver eq '1.7.1') {
    is ($offsetpos, '1742n');
    # expected frequency is 550.8350
    cmp_ok ($freq, '>=', 550.8);
    cmp_ok ($freq, '<=', 550.9);
    ok ($isroot);
  }
  elsif ($wnver eq '1.7') {
    is ($offsetpos, '1740n');
    # expected frequency is 534.5786
    cmp_ok ($freq, '>=', 534.5);
    cmp_ok ($freq, '<=', 534.6);
    ok ($isroot);
  }
  elsif ($wnver eq '1.6') {
    is ($offsetpos, '1740n');
    # expected frequency is 339.2464
    cmp_ok ($freq, '>=', 339.2);
    cmp_ok ($freq, '<=', 339.3);
    ok ($isroot);
  }
  else {
    skip ("using an unknown version of WordNet: $wnver", 4);
  }
}

ok (close FH);

END {ok (unlink $outfile)}

