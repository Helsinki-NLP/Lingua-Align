#!/usr/bin/perl
#-*-perl-*-


use strict;
use FindBin;
use lib $FindBin::Bin.'/../lib';

use Test::More;
use File::Compare;
use File::Temp qw(tempfile tempdir);

use Lingua::Align::Corpus::Parallel::Dublin;
use Lingua::Align::Corpus::Treebank;

my $corpus = new Lingua::Align::Corpus::Parallel::Dublin(-alignfile => 'data/tree-align.dublin');
my $trees = new Lingua::Align::Corpus::Treebank;

my %srctree=();
my %trgtree=();
my $links;

my ($fh, $filename) = tempfile();

while ($corpus->next_alignment(\%srctree,\%trgtree,\$links)){
    foreach my $s (keys %{$links}){
	foreach my $t (keys %{$$links{$s}}){
	    my @src = $trees->get_leafs(\%srctree,$s);
	    my @trg = $trees->get_leafs(\%trgtree,$t);
	    print $fh join (' ',@src);
	    print $fh ' <-> ';
	    print $fh join (' ',@trg);
	    print $fh " ($s:$t)\n";
	}
    }
    print $fh "====================================================\n";
}

close $fh;
is ( compare( $filename, 'data/output/tree-align.dublin' ), 0, "Subtree Aligner Format" );

done_testing;

