#!/usr/bin/perl
#-*-perl-*-


use strict;
use FindBin;
use lib $FindBin::Bin.'/../lib';

# use Lingua::Align::Corpus::Treebank;
use Lingua::Align::Corpus::Treebank::Stanford;
use Lingua::Align::Corpus::Treebank::TigerXML;


my $corpus = new Lingua::Align::Corpus::Treebank::Stanford(
    -file => '/storage/tiedeman/projects/PACO-MT/data/treebanks/Europarl3/english/ep-00-01-17.stanford.gz');

my $output =  new Lingua::Align::Corpus::Treebank::TigerXML;


my %tree=();

while ($corpus->next_sentence(\%tree)){
    print $output->print_tree(\%tree);
}

