#!/usr/bin/perl
#-*-perl-*-
#
# OPTIONS
#
#  -c align-file ..... aligned treebank in stockholm treealigner format
#  -f features ....... specify features to be used in training
#  -t nrTrain ........ max number of training sentences (default = 100)
#  -a nrAlign ........ max number of test sentences (default = 100)
#  -s strategy ....... alignment search strategy (default = greedy)
#
#

use strict;
use FindBin;
use lib $FindBin::Bin.'/../lib';

use vars qw($opt_f $opt_t $opt_a $opt_s $opt_c $opt_m $opt_C $opt_S $opt_P $opt_D $opt_k);
use Getopt::Std;

getopts('f:t:a:s:c:m:SCPDk');


use Lingua::Align::Trees;

my @features = (
    'nr_leafs_ratio',          # ratio of nr_leafs in both subtrees
    'inside2',                 # non-normalized inside score
    'outside2',                # non-normalized outside score
    'inside2*outside2',        # product of the 2 above
    'parent_inside2',          # inside score of parent nodes
#    'catpos',                  # cat OR pos attribute pair
    'parent_catpos',           # labels of the parent nodes
    'catpos.parent_catpos',     # label plus parent's label
    'insideST2',               # inside1 score for lex.e2f only
    'insideTS2',               # inside1 score for lex.f2e only
    'max_insideST',          # disjunction of prob's (lexe2f)
    'max_insideTS',          # disjunction of prob's (lexf2e)
#    'max_inside*inside2',
#    'max_inside',           # disjunction of prob's (lexe2f & lexf2e)
#    'max_outside',          # the same for outside word pairs
    'inside2*parent_inside2',  # current * parent's inside score
    'tree_level_sim',          # similarity in relative tree level
    'tree_level_sim*inside2',
    'tree_span_sim',           # similarity of subtree positions
    'tree_span_sim*tree_level_sim',
#    'gizae2f',                 # proportion of word links inside/outside
#    'gizaf2e',                 # the same for the other direction
    'giza',                    # both alignment directions combined
    'parent_giza',
#    'parent_giza*giza',
#    'gizae2f*gizaf2e'
    'giza.catpos',              # catpos with giza score
#    'parent_giza.parent_catpos',
    'moses',
    'moses.catpos',
    );


my $featureStr = $opt_f || join(':',@features);
my $nrTrain = $opt_t || 100;
my $nrAlign = $opt_a || 100;
my $search = $opt_s || 'greedy';
my $model = $opt_m || 'megam';


my $algfile = $opt_c || 'Alignments_SMULTRON_Sophies_World_SV_EN.xml';


my $treealigner = new Lingua::Align::Trees(

    -features => $featureStr,             # features to be used

    -classifier => $model,                # classifier used
    -classifier_weight_sure => 3,         # training: weight for sure links
    -classifier_weight_possible => 1,     # training: weight for possible links
    -classifier_weight_negative => 1,     # training: weight for non-linked

    -keep_training_data => $opt_k,             # don't remove feature file

    -same_types_only => 1,                # link only T&T and nonT&nonT
#    -nonterminals_only => 1,              # link non-terminals only
#    -terminals_only => 1,                 # link terminals only
    -skip_unary => 1,                     # skip nodes with unary productions

    -linked_children => $opt_C,                # add first-order dependency
                                          # (proportion of linked children)
    -linked_subtree => $opt_S,                # add first-order dependency
    -linked_parent => $opt_P,
    -linked_parent_distance => $opt_D,

    -lexe2f => 'moses-sophie/model/lex.0-0.e2f',
    -lexf2e => 'moses-sophie/model/lex.0-0.f2e',
#    -lexe2f => 'moses-all/model/lex.0-0.e2f',
#    -lexf2e => 'moses-all/model/lex.0-0.f2e',


    ## for the GIZA++ word alignment features
    -gizaA3_e2f => 'moses-sophie/giza.src-trg/src-trg.A3.final.gz',
    -gizaA3_f2e => 'moses-sophie/giza.trg-src/trg-src.A3.final.gz',
#    -gizaA3_e2f => 'moses-all/giza.src-trg/src-trg.A3.final.gz',
#    -gizaA3_f2e => 'moses-all/giza.trg-src/trg-src.A3.final.gz',

    ## for the Moses word alignment features
    -moses_align => 'moses-sophie/model/aligned.intersect',
#    -moses_align => 'moses-sophie/model/aligned.grow-diag-final-and',
#    -moses_align => 'moses-all/model/aligned.grow-diag-final-and',


    -lex_lower => 1,                      # always convert to lower case!

#    -output_format => 'dublin',          # Dublin format (default = sta)
#    -min_score => 0.6,                    # classification score threshold
#    -min_score => 0.15,                    # classification score threshold
    -min_score => 0.25,                    # classification score threshold
#    -min_score => 0.1,                    # classification score threshold
#    -min_score => 0,
    -verbose => 1,
#    -clue_min_freq => 10,

    );


# corpus to be used for training (and testing)

my %corpus = (
    -alignfile => $algfile,
    -type => 'STA');


#-------------------------------------------------------------------
# train a model on the first <nrTrain> sentences 
# and save it into "sophie.$model"
#-------------------------------------------------------------------

$treealigner->train(\%corpus,'sophie.'.$model,$nrTrain);
exit;

#-------------------------------------------------------------------
# skip the first <nrTrain> sentences and aligne the following <nrAlign>
# tree pairs with the model stored in "sophie.$model" 
#-------------------------------------------------------------------

$treealigner->align(\%corpus,'sophie.'.$model,$search,$nrAlign,$nrTrain);
