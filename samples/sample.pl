#!/usr/local/bin/perl

use strict;
use warnings;

# Sample Perl program, showing how to use the
# WordNet::Similarity measures.

# WordNet::QueryData is required by all the
# relatedness modules.
use WordNet::QueryData;

# 'use' each module that you wish to use.
use WordNet::Similarity::jcn;
use WordNet::Similarity::res;
use WordNet::Similarity::lin;
use WordNet::Similarity::lch;
use WordNet::Similarity::hso;
use WordNet::Similarity::path;
use WordNet::Similarity::wup;
use WordNet::Similarity::random;
use WordNet::Similarity::lesk;
use WordNet::Similarity::vector;

# Get the concepts.
my $wps1 = shift;
my $wps2 = shift;

unless (defined $wps1 and defined $wps2) {
    print STDERR "Undefined input\n";
    print STDERR "Usage: sample.pl synset1 synset2\n";
    print STDERR "\tSynsets must be in word#pos#sense format (ex., dog#n#1)\n";
    exit 1;
}

# Load WordNet::QueryData
print STDERR "Loading WordNet... ";
my $wn = WordNet::QueryData->new;
die "Unable to create WordNet object.\n" if(!$wn);
print STDERR "done.\n";


# Create an object for each of the measures of
# semantic relatedness.
print STDERR "Creating jcn object... ";
my $jcn = WordNet::Similarity::jcn->new($wn);
die "Unable to create jcn object.\n" if(!defined $jcn);
my ($error, $errString) = $jcn->getError();
die $errString if($error > 1);
print STDERR "done.\n";

print STDERR "Creating res object... ";
my $res = WordNet::Similarity::res->new($wn);
die "Unable to create res object.\n" if(!defined $res);
($error, $errString) = $res->getError();
die $errString if($error > 1);
print STDERR "done.\n";

print STDERR "Creating lin object... ";
my $lin = WordNet::Similarity::lin->new($wn);
die "Unable to create lin object.\n" if(!defined $lin);
($error, $errString) = $lin->getError();
die $errString if($error > 1);
print STDERR "done.\n";

print STDERR "Creating lch object... ";
my $lch = WordNet::Similarity::lch->new($wn);
die "Unable to create lch object.\n" if(!defined $lch);
($error, $errString) = $lch->getError();
die $errString if($error > 1);
print STDERR "done.\n";

print STDERR "Creating hso object... ";
my $hso = WordNet::Similarity::hso->new($wn, "config-files/config-hso.conf");
die "Unable to create hso object.\n" if(!defined $hso);
($error, $errString) = $hso->getError();
die $errString if($error > 1);
print STDERR "done.\n";

print STDERR "Creating path object... ";
my $path = WordNet::Similarity::path->new($wn);
die "Unable to create path object.\n" if(!defined $path);
($error, $errString) = $path->getError();
die $errString if($error > 1);
print STDERR "done.\n";

print STDERR "Creating random object... ";
my $random = WordNet::Similarity::random->new($wn);
die "Unable to create random object.\n" if(!defined $random);
($error, $errString) = $random->getError();
die $errString if($error > 1);
print STDERR "done.\n";

print STDERR "Creating lesk object... ";
my $lesk = WordNet::Similarity::lesk->new($wn);
die "Unable to create lesk object.\n" if(!defined $lesk);
($error, $errString) = $lesk->getError();
die $errString if($error > 1);
print STDERR "done.\n";



# Find the relatedness of the concepts using each of
# the measures.
my $value = $jcn->getRelatedness($wps1, $wps2);
($error, $errString) = $jcn->getError();
die $errString if($error > 1);

print "Similarity = $value\n";
print "ErrorString = $errString\n" if $error;

$value = $res->getRelatedness($wps1, $wps2);
($error, $errString) = $res->getError();
die $errString if($error > 1);

print "Similarity = $value\n";
print "ErrorString = $errString\n" if $error;

$value = $lin->getRelatedness($wps1, $wps2);
($error, $errString) = $lin->getError();
die $errString if($error > 1);

print "Similarity = $value\n";
print "ErrorString = $errString\n" if $error;

$value = $lch->getRelatedness($wps1, $wps2);
($error, $errString) = $lch->getError();
die $errString if($error > 1);

print "Similarity = $value\n";
print "ErrorString = $errString\n" if $error;

$value = $hso->getRelatedness($wps1, $wps2);
($error, $errString) = $hso->getError();
die $errString if($error > 1);
my $trace = $hso->getTraceString();

print "Similarity = $value\n";
print "ErrorString = $errString\n" if $error;
print "TRACE\n\n$trace\n";

$value = $path->getRelatedness($wps1, $wps2);
($error, $errString) = $path->getError();
die $errString if($error > 1);

print "Similarity = $value\n";
print "ErrorString = $errString\n" if $error;

$value = $random->getRelatedness($wps1, $wps2);
($error, $errString) = $random->getError();
die $errString if($error > 1);

print "Similarity = $value\n";
print "ErrorString = $errString\n" if $error;

$value = $lesk->getRelatedness($wps1, $wps2);
($error, $errString) = $lesk->getError();
die $errString if($error > 1);

print "Similarity = $value\n";
print "ErrorString = $errString\n" if $error;

__END__

