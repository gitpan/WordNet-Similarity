#!/usr/bin/perl -wT

use strict;

use CGI;
use Socket;

my $cgi = CGI->new;

my $word1 = $cgi->param ('word1');
my $word2 = $cgi->param ('word2');
my $type = $cgi->param ('type');

unless ($type eq 'gloss'
	or $type eq 'synset');

__END__
