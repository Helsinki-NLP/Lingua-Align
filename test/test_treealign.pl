#!/usr/bin/perl
#-*-perl-*-
#
# this is a test script to run a simple training/alignment procedure
# on the SMULTRON corpus
#

use strict;
use FindBin;
use lib $FindBin::Bin.'/../lib';

use Lingua::Align::Trees;

my @features = (
    'nr_leafs_ratio',          # ratio of nr_leafs in both subtrees
    'inside1',                 # non-normalized inside score
    'outside1',                # non-normalized outside score
    'inside1*outside1',        # product of the 2 above
    'parent_inside1',          # inside score of parent nodes
    'catpos',                  # cat OR pos attribute pair
    'insideST1',               # inside1 score for lex.e2f only
    'insideTS1',               # inside1 score for lex.f2e only
    'joerg_insideST',          # disjunction of prob's
    'inside1*parent_inside1',  # current * parent's inside score
    'tree_level_sim',          # similarity in relative tree level
    'tree_level_sim*inside1'
    );


my $featureStr = join(':',@features);

my $treealigner = new Lingua::Align::Trees(

    -features => $featureStr,             # features to be used

    -classifier => 'megam',               # classifier used
    -classifier_weight_sure => 3,         # training: weight for sure links
    -classifier_weight_possible => 1,     # training: weight for possible links
    -classifier_weight_negative => 1,     # training: weight for non-linked

    -keep_training_data => 1,            # don't remove feature file
#    -count_good_only => 1,               # in evaluation: discard fuzzy!

#    -lexe2f => 'moses/model/lex.0-0.e2f', # moses lex models
#    -lexf2e => 'moses/model/lex.0-0.f2e', # for inside & outside scores
    -lexe2f => 'ep+sw.lex.e2f',
    -lexf2e => 'ep+sw.lex.f2e',
    -lex_lower => 1,                      # always convert to lower case!

#    -output_format => 'dublin',          # Dublin format (default = sta)
    -min_score => 0.2,                    # classification score threshold
    -verbose => 1,

    );


# corpus to be used for training (and testing)

my $SMULTRON = $ENV{HOME}.'/projects/SMULTRON/';
my %corpus = (
    -alignfile => $SMULTRON.'/Alignments_SMULTRON_Sophies_World_SV_EN.xml',
    -type => 'STA');


#-------------------------------------------------------------------
# train a model on the first 20 sentences 
# and save it into 'testmodel.megam'
#-------------------------------------------------------------------

$treealigner->train(\%corpus,'testmodel.megam',20);


#-------------------------------------------------------------------
# skip the first 20 sentences and aligne the following 10 tree pairs
# with the model stored in 'testmodel.megam' using various search algorithms
# (this will print alignments to STDOUT and a short evaluation to STDERR)
#-------------------------------------------------------------------

$treealigner->align(\%corpus,'testmodel.megam','greedy',20,20);
# $treealigner->align(\%corpus,'testmodel.megam','inter',10,20);
# $treealigner->align(\%corpus,'testmodel.megam','src2trg',10,20);
# $treealigner->align(\%corpus,'testmodel.megam','trg2src',10,20);



# test aligning the training data (this should be forbidden ... sanity check)
# $treealigner->align(\%corpus,'testmodel.megam','greedy',20,0);


