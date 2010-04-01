package Lingua::Align::Trees;
#---------------------------------------------------------------------------    
# Copyright (C) 2009 Jörg Tiedemann                                             
# jorg.tiedemann@lingfil.uu.se
#                                                                               
# This program is free software; you can redistribute it and/or modify          
# it under the terms of the GNU General Public License as published by          
# the Free Software Foundation; either version 2 of the License, or             
# (at your option) any later version.                                           
#                                                                               
# This program is distributed in the hope that it will be useful,               
# but WITHOUT ANY WARRANTY; without even the implied warranty of                
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the                 
# GNU General Public License for more details.                                  
#                                                                               
# You should have received a copy of the GNU General Public License             
# along with this program; if not, write to the Free Software                   
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA     
#---------------------------------------------------------------------------    
#
# Lingua::Align::Trees - Perl modules implementing a discriminative tree aligner
#

use 5.005;
use strict;

use vars qw($VERSION @ISA);
@ISA = qw(Lingua::Align);
$VERSION = '0.01';

use FileHandle;
use Time::HiRes qw ( time alarm sleep );

use Lingua::Align;
use Lingua::Align::Corpus::Parallel;
use Lingua::Align::Classifier;           # binary classifier
use Lingua::Align::LinkSearch;           # link search algorithms
use Lingua::Align::Features;             # feature extraction module


my $DEFAULTFEATURES = 'inside:outside';

sub new{
    my $class=shift;
    my %attr=@_;

    my $self={};
    bless $self,$class;

    # set features (or default features)
    $self->{-features}=$attr{-features} || 'inside1:outside1:inside1*outside1';

    foreach (keys %attr){
	$self->{$_}=$attr{$_};
    }

    $self->{CLASSIFIER} = new Lingua::Align::Classifier(%attr);
    $self->{FEATURE_EXTRACTOR} = new Lingua::Align::Features(%attr);
    # make a Treebank object for processing trees
    $self->{TREES} = new Lingua::Align::Corpus::Treebank();

    return $self;
}


#----------------------------------------------------------------
#
# train a classifier for alignment
#
# $aligner->train($corpus,$model,$max,$skip[,features])
#
#    corpus .... hash parallel treebank used for training
#    model ..... file for storing base classifier model
#    max ....... max number of tree pairs to be aligned
#    skip ...... number of innitial tree pairs to be skipped
#    features .. hash of features to be used (optional)
#                (if not specified: use $aligner->{-features})
#
#----------------------------------------------------------------

sub train{
    my $self=shift;

    $self->{START_TRAINING}=time();
    my ($corpus,$model,$max,$skip)=@_;
    my $features = $_[4] || $self->{-features};

    # $corpus is a pointer to hash with all parameters necessary 
    # to access the training corpus
    #
    # $features is a pointer to a hash specifying the features to be used
    #
    # $model is the name of the model-file

    my $done=0;
    my $iter=0;

    # this loop is used to do some "SEARN" like adaptation of history features

    do {
	# initialize training
	$self->{SENT_COUNT}=0;
	$self->{NODE_COUNT}=0;
	$self->{SRCNODE_COUNT}=0;
	$self->{TRGNODE_COUNT}=0;

	# extract training data (data instances as feature-vectors)
	$self->{START_EXTRACT_FEATURES}=time();
	$self->{CLASSIFIER}->initialize_training();
	$self->extract_training_data($corpus,$features,$max,$skip);
	$self->{TIME_EXTRACT_FEATURES}+=time()-$self->{START_EXTRACT_FEATURES};

	# train the model (call external learner)
	$self->{START_TRAIN_MODEL}=time();
	$model = $self->{CLASSIFIER}->train($model);
	$self->{TIME_TRAIN_MODEL} += time() - $self->{START_TRAIN_MODEL};

	# iterative "SEARN-like" learning --> adapt history features
	# (this is probably not appropriate, need to look into this later)
	$done=1;
	if (exists $self->{-searn}){
	    if ($iter<$self->{-searn}){
		$self->{-searn_model} = $model;
		$self->{CLASSIFIER}->initialize_classification($model);
		$done=0;
	    }
	}
	$iter++;

    }
    until ($done);

    # store features types (to have access to used features when aligning)
    $self->store_features_used($model,$features);
    $self->{TIME_TRAINING} = time() - $self->{START_TRAINING};

    # print some runtime information
    if ($self->{-verbose}){
    if ($self->{SENT_COUNT} && $self->{NODE_COUNT}){
	print STDERR "\n============ ";
	print STDERR "statistics for training an alignment model ";
	print STDERR "======\n";

	printf STDERR "%30s: %d (%d source nodes, %d target nodes)\n",
	"link candidates",
	$self->{NODE_COUNT},
	$self->{SRCNODE_COUNT},
	$self->{TRGNODE_COUNT};

	printf STDERR "%30s: %f (%f/sent, %f/node pair)\n",
	"time for feature extraction",
	$self->{TIME_EXTRACT_FEATURES},
	$self->{TIME_EXTRACT_FEATURES}/$self->{SENT_COUNT},
	$self->{TIME_EXTRACT_FEATURES}/$self->{NODE_COUNT};

	printf STDERR "%30s: %f\n","time for training classifier",
	$self->{TIME_TRAIN_MODEL};
	printf STDERR "%30s: %f\n","total time training",
	$self->{TIME_TRAINING};
	print STDERR "==================";
	print STDERR "============================================\n\n";
    }
    }
}

#
# end of train
#----------------------------------------------------------------



#----------------------------------------------------------------
#
# tree alignment: run through the parallel treebank & align nodes
#
# $aligner->align($corpus,$model,$type,$max,$skip)
#
#    corpus .... hash specifying parallel treebank to be aligned
#    model ..... model file for base classifier
#    type ...... type of alignment inference (link search)
#    max ....... max number of tree pairs to be aligned
#    skip ...... number of innitial tree pairs to be skipped
#
#----------------------------------------------------------------

sub align{
    my $self=shift;

    #----------------------------------------------------------------
    # initialize
    #----------------------------------------------------------------

    $self->{START_ALIGNING}=time();
    my ($corpus,$model,$type,$max,$skip)=@_;
    if (ref($corpus) ne 'HASH'){die "please specify a corpus!";}
    my $min_score = $self->{-min_score};

    # initialize classifier and feature extractor
    $self->{CLASSIFIER}->initialize_classification($model);
    my $features = $self->get_features_used($model);

    my $FE=$self->{FEATURE_EXTRACTOR};
    $FE->initialize_features($features);

    # make a new corpus object & link search object
    my $corpus   = new Lingua::Align::Corpus::Parallel(%{$corpus});
    my $searcher = new Lingua::Align::LinkSearch(-link_search => $type);

    # initialize output data object
    my %output;
    $output{-type} = $self->{-output_format} || 'sta';
    my $alignments = new Lingua::Align::Corpus::Parallel(%output);

    my %src=();
    my %trg=();
    my $existing_links;
    my $count=0;
    my $skipped=0;
    my ($SrcId,$TrgId);

    # initialize variables for runtime information
    $self->{TIME_EXTRACT_FEATURES}=0;
    $self->{TIME_CLASSIFICATION}=0;
    $self->{TIME_LINK_SEARCH}=0;
    $self->{SENT_COUNT}=0;
    $self->{NODE_COUNT}=0;
    $self->{SRCNODE_COUNT}=0;
    $self->{TRGNODE_COUNT}=0;


    #----------------------------------------------------------------
    # main loop: run through the parallel corpus and align!
    #----------------------------------------------------------------

    while ($corpus->next_alignment(\%src,\%trg,\$existing_links)){

	# this is useful to skip sentences that have been used for training
	if (defined $skip){
	    if ($skipped<$skip){
		$skipped++;
		next;
	    }
	}

	# generate some runtime output to show progress
	$count++;
	if (not($count % 10)){print STDERR '.';}
	if (not($count % 100)){
	    print STDERR " $count aligments (";
	    my $elapsed = time() - $self->{START_ALIGNING};
	    print STDERR $elapsed;
	    printf STDERR " sec, %f/sentence)\n",$elapsed/$count;
	}

	# stop after MAX number of sentence pairs (if specified)
	if (defined $max){
	    if ($count>$max){
		$corpus->close();
		last;
	    }
	}

	$self->{SENT_COUNT}++;
	$self->{SRCNODE_COUNT}+=scalar keys %{$src{NODES}};
	$self->{TRGNODE_COUNT}+=scalar keys %{$trg{NODES}};

	$self->{INSTANCES}=[];
	$self->{INSTANCES_SRC}=[];
	$self->{INSTANCES_TRG}=[];

	# clear the feature value cache
	$self->{FEATURE_EXTRACTOR}->clear_cache();


	#----------------------------------------------------------------
	# check if already existing links are OK

	my $nr_existing_links=0;
	if ($self->{-verbose}){
	    foreach my $sid (keys %{$existing_links}){
		if (! exists $src{NODES}{$sid}){
		    print STDERR "Strange! There is a link from $sid but this node does not seem to exist in the source language tree!\n";
		}
		foreach my $tid (keys %{$$existing_links{$sid}}){
		    $nr_existing_links++;
		    if (! exists $trg{NODES}{$tid}){
			print STDERR "Strange! There is a link to $tid from $sid but the node does not seem to exist in the target language tree!\n";
		    }
		}
	    }
	}

	#----------------------------------------------------------------
	# extract features and classify link candidates
	#----------------------------------------------------------------

	my @scores = $self->classify($model,\%src,\%trg,$existing_links);

	#----------------------------------------------------------------
	# link search: use classification result to do the actual alignment
	#----------------------------------------------------------------

	my %links=();
	$self->{START_LINK_SEARCH}=time();

	# add previously existing links before link search
	# --> they may influence the link search (wellformedness constraint ...)
	#
	# 1) "compete-mode":
	#    let the existing links compete with the new ones
	if ($self->{-add_links}=~/compet/){
	    foreach my $sid (keys %{$existing_links}){
		foreach my $tid (keys %{$$existing_links{$sid}}){
		    push(@{$self->{INSTANCES_SRC}},$sid);
		    push(@{$self->{INSTANCES_TRG}},$tid);
		    push(@scores,$$existing_links{$sid}{$tid});
		}
	    }
	}
	# 2) "standard-mode":
	#    leave existing links as they are and just add new ones in search
	elsif ($self->{-add_links}){
	    foreach my $sid (keys %{$existing_links}){
		foreach my $tid (keys %{$$existing_links{$sid}}){
		    if (exists $links{$sid}{$tid} && $self->{-verbose}>1){
			print STDERR "link between $sid and $tid exists\n";
		    }
		    $links{$sid}{$tid}=$$existing_links{$sid}{$tid};
		}
	    }
	}

	# do the actual inference: search for the best alignment using
	#                          the selected link search algorithm

	$searcher->search(\%links,\@scores,$min_score,
			  $self->{INSTANCES_SRC},
			  $self->{INSTANCES_TRG},
			  \%src,\%trg);
	$self->{TIME_LINK_SEARCH}+=time()-$self->{START_LINK_SEARCH};

	#----------------------------------------------------------------
	# print alignment output
	#----------------------------------------------------------------

	if ((not defined $SrcId) || (not defined $TrgId)){
	    $SrcId=$corpus->src_treebankID();
	    $TrgId=$corpus->trg_treebankID();
	    my $SrcFile=$corpus->src_treebank();
	    my $TrgFile=$corpus->trg_treebank();
	    print $alignments->print_header($SrcFile,$TrgFile,$SrcId,$TrgId);
	}

	print $alignments->print_alignments(\%src,\%trg,\%links,$SrcId,$TrgId);
    }

    #----------------------------------------------------------------
    # end of the main loop
    #----------------------------------------------------------------

    # close alignment output & print some runtime information

    print $alignments->print_tail();

    $self->{TIME_ALIGNING} = time() - $self->{START_ALIGNING};

    if ($self->{-verbose}){
	if ($self->{SENT_COUNT} && $self->{NODE_COUNT}){
	    print STDERR "\n================= ";
	    print STDERR "statistics for aligning trees ==============\n";

	    printf STDERR "%30s: %d (%d source nodes, %d target nodes)\n",
	    "link candidates",
	    $self->{NODE_COUNT},
	    $self->{SRCNODE_COUNT},
	    $self->{TRGNODE_COUNT};

	    printf STDERR "%30s: %f (%f/sent, %f/node pair)\n",
	    "time for feature extraction",
	    $self->{TIME_EXTRACT_FEATURES},
	    $self->{TIME_EXTRACT_FEATURES}/$self->{SENT_COUNT},
	    $self->{TIME_EXTRACT_FEATURES}/$self->{NODE_COUNT};

	    printf STDERR "%30s: %f (%f/sentence)\n","time for classification",
	    $self->{TIME_CLASSIFY},$self->{TIME_CLASSIFY}/$self->{SENT_COUNT};
	    printf STDERR "%30s: %f (%f/sentence)\n","time for link search",
	    $self->{TIME_LINK_SEARCH},
	    $self->{TIME_LINK_SEARCH}/$self->{SENT_COUNT};
	    printf STDERR "%30s: %f (%f/sentence)\n","total time aligning",
	    $self->{TIME_ALIGNING},$self->{TIME_ALIGNING}/$self->{SENT_COUNT};
	    print STDERR "==================";
	    print STDERR "============================================\n\n";
	}
    }
}


#
# end of align
#----------------------------------------------------------------






#----------------------------------------------------------------
# extract training data instances
#
# - run through training corpus (aligned parallel treebank)
#   and extract data instances in terms of labeled feature vectors
# - extract also history features
# - add each instance to training data
#
# extract_training_data($corpus,$features,$max,$skip)
#
#  corpus .... pointer to hash specifying the parallel tree bank
#  features .. set of features to be used
#  max ....... number of tree pairs to be used for training (default: all)
#  skip ...... number of initial tree pairs to be skipped (default: 0)
#----------------------------------------------------------------



sub extract_training_data{
    my $self=shift;

    my ($corpus,$features,$max,$skip)=@_;
    if (not $features){$features = $self->{-features};}
    if (ref($corpus) ne 'HASH'){
	die "please specify a corpus to be used for training!";
    }

    print STDERR "extract features for training!\n";

    # initialize

    my $FE=$self->{FEATURE_EXTRACTOR};
    $FE->initialize_features($features);
    my $CorpusHandle = new Lingua::Align::Corpus::Parallel(%{$corpus});

    my ($weightSure,$weightPossible,$weightNegative) = (1,0,1);
    if (defined $self->{-classifier_weight_sure}){
	$weightSure = $self->{-classifier_weight_sure};
    }
    if (defined $self->{-classifier_weight_possible}){
	$weightPossible = $self->{-classifier_weight_possible};
    }
    if (defined $self->{-classifier_weight_negative}){
	$weightNegative = $self->{-classifier_weight_negative};
    }

    my %src=();
    my %trg=();
    my $links;

    my $count=0;
    my $skipped=0;

    #----------------------------------------------------------------
    # main loop: run through treebank and extract features
    #----------------------------------------------------------------    

    while ($CorpusHandle->next_alignment(\%src,\%trg,\$links)){

	# this is useful to skip sentences that shouldn't been used for train
	if (defined $skip){
	    if ($skipped<$skip){
		$skipped++;
		next;
	    }
	}

	# clear the feature value cache
	$FE->clear_cache();

	#-------------------------------------------------------------------
	# adaptive "SEARN-like" learning (combine true & predicted values)
	#-------------------------------------------------------------------

	if (defined $self->{-searn_model}){

	    # make link prob's out of link types ....
	    # HARDCODED STUFF!!!
	    # --> good = 1
	    # --> fuzzy = 0.2
	    if (not defined $self->{LP}){
		$self->{LP}={};
		foreach my $s (keys %{$links}){
		    foreach my $t (keys %{$$links{$s}}){
			if ($$links{$s}{$t}=~/(good|S)/){
			    $$self{LP}{$s}{$t}=1;
			}
			elsif ($$links{$s}{$t}=~/(fuzzy|possible|P)/){
			    $$self{LP}{$s}{$t}=0.2;
			}
		    }
		}
	    }

	    # interpolation beta: take from $self->{-searn_beta}
	    # or simply set it to 0.3
	    # ---> beta should be estimated on development data!!!!

	    my $model = $self->{-searn_model};
	    my @scores = $self->classify($model,\%src,\%trg);
	    my $b=$self->{-searn_beta} || 0.3;

	    for (0..$#scores){
		my $sid = $self->{INSTANCES_SRC}->[$_];
		my $tid = $self->{INSTANCES_TRG}->[$_];
		$$self{LP}{$sid}{$tid}=
		    (1-$b)*$$self{LP}{$sid}{$tid}+$b*$scores[$_];
	    }
	}

	# show progress at runtime
	$count++;
	if (not($count % 10)){print STDERR '.';}
	elsif (not($count % 100)){print STDERR " $count aligments\n";}

	# stop after max number of tree pairs (if specified)
	if (defined $max){
	    if ($count>$max){
		$CorpusHandle->close();
		last;
	    }
	}

	#-------------------------------------------------------------------
	# loop through all node pairs and extract data instances
	#-------------------------------------------------------------------

	$self->{SENT_COUNT}++;
	$self->{SRCNODE_COUNT}+=scalar keys %{$src{NODES}};
	$self->{TRGNODE_COUNT}+=scalar keys %{$trg{NODES}};

	foreach my $sn (keys %{$src{NODES}}){
	    next if ($sn!~/\S/);
	    my $s_is_terminal=$self->{TREES}->is_terminal(\%src,$sn);
	    next if ($self->skip_node($sn,\%src,$s_is_terminal));
	    
	    foreach my $tn (keys %{$trg{NODES}}){
		next if ($tn!~/\S/);
		my $t_is_terminal=$self->{TREES}->is_terminal(\%trg,$tn);

		## align ony terminals with terminals and
		## nonterminals with nonterminals
		if ($self->{-same_types_only}){
		    if ($s_is_terminal){
			next if (not $t_is_terminal);
		    }
		    elsif ($t_is_terminal){next;}
		}
		next if ($self->skip_node($tn,\%trg,$t_is_terminal));

		#------------------------------------------------
		# finally: extract features for given node pair!
		#------------------------------------------------

		my %values = $FE->features(\%src,\%trg,$sn,$tn);
		$self->{NODE_COUNT}++;

		#-----------------------------------------------------------
		# add history features
		#------------------------------------------------

		if ($self->{-linked_children}){
		    if (defined $self->{LP}){
			$self->linked_children(\%values,\%src,\%trg,
					       $sn,$tn,$self->{LP},1);
		    }
		    else{
			$self->linked_children(\%values,\%src,\%trg,
					       $sn,$tn,$links);
		    }
		}
		if ($self->{-linked_subtree}){
		    if (defined $self->{LP}){
			$self->linked_subtree(\%values,\%src,\%trg,
					      $sn,$tn,$self->{LP},1);
		    }
		    else{
			$self->linked_subtree(\%values,\%src,\%trg,
					      $sn,$tn,$links);
		    }
		}
		if ($self->{-linked_parent}){
		    if (defined $self->{LP}){
			$self->linked_parent(\%values,\%src,\%trg,
					     $sn,$tn,$self->{LP},1);
		    }
		    else{
			$self->linked_parent(\%values,\%src,\%trg,
					     $sn,$tn,$links);
		    }
		}
		if ($self->{-linked_parent_distance}){
		    if (defined $self->{LP}){
			$self->linked_parent_distance(\%values,\%src,\%trg,
						      $sn,$tn,$self->{LP},1);
		    }
		    else{
			$self->linked_parent_distance(\%values,\%src,\%trg,
						      $sn,$tn,$links);
		    }
		}

		#-----------------------------------------------------------
		# add positive training events
		# (good/sure examples && fuzzy/possible examples)
		#-----------------------------------------------------------

		if ((ref($$links{$sn}) eq 'HASH') && 
		    (exists $$links{$sn}{$tn})){

		    if ($$links{$sn}{$tn}=~/(good|S)/){
			if ($weightSure){
#			    my %values = $FE->features(\%src,\%trg,$sn,$tn);
			    $self->{CLASSIFIER}->add_train_instance(
				1,\%values,$weightSure);
			}
		    }
		    elsif ($$links{$sn}{$tn}=~/(fuzzy|possible|P)/){
			if ($weightPossible){
			    $self->{CLASSIFIER}->add_train_instance(
				1,\%values,$weightPossible);
			}
		    }
		}

		#-----------------------------------------------------------
		# add negative training events
		#-----------------------------------------------------------

		elsif ($weightNegative){
		    $self->{CLASSIFIER}->add_train_instance(
			'0',\%values,$weightNegative);
		}
	    }
	}
    }
}



#---------------------------------------------------------------
# skip_node($node,$tree,$is_terminal)
#    - check if we should skip nodes because of some constraints & settings
#
# node ......... node ID
# tree ......... pointer to tree structure
# is_terminal .. flag to indicate that node is terminal node (or not)
#---------------------------------------------------------------

sub skip_node{
    my $self=shift;
    my ($n,$tree,$is_terminal)=@_;

    ## align only non-terminals!
    if ($self->{-nonterminals_only}){
	return 1 if ($is_terminal);
    }
    ## align only terminals!
    ## (do we need this?)
    if ($self->{-terminals_only}){
	return 1 if (not $is_terminal);
    }
    # skip nodes with unary productions
    if ((not $is_terminal) && $self->{-skip_unary}){

	# IF "nonterminals_only" is switched on OR
	#    "same_types_only" is switched on THEN
	# do NOT skip unary subtrees 
	# IF the only child is a terminal node!
	# Why? --> "nonterminals_only" --> we want to link those nodes!
	#          down at the end of branches
	#      --> "same_types_only" --> there might be a non-unary
	#          subtree in the target language to be linked to!

	if ($self->{-nonterminals_only} || $self->{-same_types_only}){
	    my $c=undef;
	    if ($self->{TREES}->is_unary_subtree($tree,$n,\$c)){
		return 1 if ($self->{TREES}->is_nonterminal($tree,$c));
	    }
	}
	else{
	    return 1 if ($self->{TREES}->is_unary_subtree($tree,$n));
	}
    }
    return 0;
}



#----------------------------------------------------------------
#
# history features
#
#----------------------------------------------------------------


# linked_children
#
# - look at link predictions for all *immediate* children nodes 
#   of the current subtree pair
# - normalize number of linked children nodes 
#   by largest number of nodes on either source or target language side
# - in alignment: use prediction likelihood as "soft count"

sub linked_children{
    my $self=shift;
    my ($values,$src,$trg,$sn,$tn,$links,$softcount)=@_;
    my @srcchildren=$self->{TREES}->children($src,$sn);
    my @trgchildren=$self->{TREES}->children($trg,$tn);
    my $nr=0;
    foreach my $s (@srcchildren){
	foreach my $t (@trgchildren){
	    if (exists $$links{$s}){
		if (exists $$links{$s}{$t}){
		    if ($softcount){                 # prediction mode:
			$nr+=$$links{$s}{$t};        # use prediction prob
#			if ($softcount>0.5){$nr++;}  # use classification
		    }
		    else{$nr++;}                     # training mode
		}
	    }
	}
    }
    # normalize by the size of the larger subtree
    # problem: might give us scores > 1 (is this a problem?)
    if ($nr){
	if ($#srcchildren > $#trgchildren){
	    if ($#srcchildren>=0){
		$$values{linkedchildren}=$nr/($#srcchildren+1);
	    }
	}
	elsif ($#trgchildren>=0){
	    $$values{linkedchildren}=$nr/($#trgchildren+1);
	}
    }
}


# linked_subtree
#
# same as linked_subtree but cosider all nodes in the subtree!

sub linked_subtree{
    my $self=shift;
    my ($values,$src,$trg,$sn,$tn,$links,$softcount)=@_;
    my @srcchildren=$self->{TREES}->subtree_nodes($src,$sn);
    my @trgchildren=$self->{TREES}->subtree_nodes($trg,$tn);
    my $nr=0;
    foreach my $s (@srcchildren){
	foreach my $t (@trgchildren){
	    if (exists $$links{$s}){
		if (exists $$links{$s}{$t}){
		    if ($softcount){
			$nr+=$$links{$s}{$t};
		    }
		    else{$nr++;}
		}
	    }
	}
    }
    if ($nr){
	if ($#srcchildren > $#trgchildren){
	    if ($#srcchildren>=0){
		$$values{linkedsubtree}=$nr/($#srcchildren+1);
	    }
	}
	elsif ($#trgchildren>=0){
	    $$values{linkedsubtree}=$nr/($#trgchildren+1);
	}
    }
}



# linked_parent
#
# - for top-down classification: 
#   return whether parent nodes are linked or not
# - in alignment mode: return prediction likelihood

sub linked_parent{
    my $self=shift;
    my ($values,$src,$trg,$sn,$tn,$links,$softcount)=@_;
    my $srcparent=$self->{TREES}->parent($src,$sn);
    my $trgparent=$self->{TREES}->parent($trg,$tn);
    my $nr=0;
    if (exists $$links{$srcparent}){
	if (exists $$links{$srcparent}{$trgparent}){
	    if ($softcount){
		$nr+=$$links{$srcparent}{$trgparent};
#		if ($softcount>0.5){$nr++;}
	    }
	    else{$nr++;}
	}
    }
    if ($nr){
	$$values{linkedparent}=$nr;
    }
}


# linked_parent_distance
#
# - for top-down prediction: 
#   measure the distance between the linked parent 
#   and the parent of the current link candidate
# - in case of multiple links (or multiple link likelihoods):
#   compute average distance

sub linked_parent_distance{
    my $self=shift;
    my ($values,$src,$trg,$sn,$tn,$links,$softcount)=@_;
    my $srcparent=$self->{TREES}->parent($src,$sn);
    my $trgparent=$self->{TREES}->parent($trg,$tn);

    my $nrlinks=0;
    my $dist=0;

    my ($start,$end)=$self->{TREES}->subtree_span($trg,$tn);
    my $trgpos=($start+$end)/2;

    if (exists $$links{$srcparent}){
	foreach my $l (keys %{$$links{$srcparent}}){
	    $nrlinks++;
	    my ($start,$end)=$self->{TREES}->subtree_span($trg,$l);
	    my $pos=($start+$end)/2;
	    if ($softcount){
		$dist+=$$links{$srcparent}{$trgparent}*(abs($pos-$trgpos));
	    }
	    else{
		$dist+=abs($pos-$trgpos);
	    }
	}
    }

    if ($nrlinks){
	$dist/=$nrlinks;
	my $trgsize=$#{$$trg{TERMINALS}}+1;
	$dist/=$trgsize;
	if ($dist){
	    $$values{linkedparentdist}=1-$dist;
	}
    }
}






# alternative history features .... not used yet
#
# linked_children_proper
# linked_subtree_proper
#     --> normalize with total number of src & trg nodes
#     --> scores are always between 0 and 1
#     (punishes nodes with many children too much?!)

sub linked_children_proper{
    my $self=shift;
    my ($values,$src,$trg,$sn,$tn,$links,$softcount)=@_;
    my @srcchildren=$self->{TREES}->children($src,$sn);
    my @trgchildren=$self->{TREES}->children($trg,$tn);
    my $nr=0;
    my $total=0;
    foreach my $s (@srcchildren){
	if (exists $$links{$s}){
	    foreach my $t (@trgchildren){
		if (exists $$links{$s}{$t}){
		    if ($softcount){$nr+=$$links{$s}{$t};}
		    else{$nr++;}
		}
	    }
	    foreach my $t (keys %{$$links{$s}}){
		if ($softcount){$total+=$$links{$s}{$t};}
		else{$total++;}	
	    }
	}
    }
    if ($nr){
	$$values{linkedchildren}=$nr/$total;
    }
}

sub linked_subtree_proper{
    my $self=shift;
    my ($values,$src,$trg,$sn,$tn,$links,$softcount)=@_;
    my @srcchildren=$self->{TREES}->subtree_nodes($src,$sn);
    my @trgchildren=$self->{TREES}->subtree_nodes($trg,$tn);
    my $nr=0;
    my $total=0;
    foreach my $s (@srcchildren){
	if (exists $$links{$s}){
	    foreach my $t (@trgchildren){
		if (exists $$links{$s}{$t}){
		    if ($softcount){$nr+=$$links{$s}{$t};}
		    else{$nr++;}
		}
	    }
	    foreach my $t (keys %{$$links{$s}}){
		if ($softcount){$total+=$$links{$s}{$t};}
		else{$total++;}	
	    }
	}
    }
    if ($nr){
	$$values{linkedsubtree}=$nr/$total;
    }
}


# linked_children_inside_outside
#
# ratio between links within the subtree pair 
# and links outside of the subtree pair

sub linked_children_inside_outside{
    my $self=shift;
    my ($values,$src,$trg,$sn,$tn,$links,$softcount)=@_;
    my @srcchildren=$self->{TREES}->children($src,$sn);
    my @trgchildren=$self->{TREES}->children($trg,$tn);

    my %trgLeafIDs=();
    foreach (@trgchildren){$trgLeafIDs{$_}=1;}

    my $inside=0;
    my $outside=0;

    foreach my $s (@srcchildren){
	if (exists $$links{$s}){
	    foreach my $t (keys %{$$links{$s}}){
		if (exists $trgLeafIDs{$t}){
		    if ($softcount){$inside+=$$links{$s}{$t};}
		    else{$inside++;}
		}
		else{
		    if ($softcount){$outside+=$$links{$s}{$t};}
		    else{$outside++;}
		}
	    }
	}
    }
    if ($inside){
	$$values{linkedchildren}=$inside/($inside+$outside);
    }
}




#----------------------------------------------------------------
#
# classify
#
# call classifier for all node pairs
# - classify_bottom_up .... if linked_children history features are used 
# - classify_top_down ..... if linked_parent history features are used 
# - simply run through all pairsotherwise
#
#----------------------------------------------------------------


sub classify{
    my $self=shift;

    if ($self->{-linked_children} || $self->{-linked_subtree} ||
	$self->{-linked_parent} || $self->{-linked_parent_distance}){
	return $self->classify_with_history(@_);
    }

    # if ($self->{-linked_children} || $self->{-linked_subtree}){
    # 	return $self->classify_bottom_up(@_);
    # }
    # elsif ($self->{-linked_parent} || $self->{-linked_parent_distance}){
    # 	return $self->classify_top_down(@_);
    # }

    my ($model,$src,$trg,$links)=@_;

    # extract features
    $self->{START_EXTRACT_FEATURES}=time();
    $self->extract_classification_data($src,$trg,$links);
    $self->{TIME_EXTRACT_FEATURES}+=time()-$self->{START_EXTRACT_FEATURES};
    
    # classify data instances
    $self->{START_CLASSIFICATION}=time();
    my @scores = $self->{CLASSIFIER}->classify($model);
    $self->{TIME_CLASSIFY}+=time()-$self->{START_CLASSIFICATION};

    return @scores;
}



#----------------------------------------------------------------
#
# classify_with_history
#
#----------------------------------------------------------------

sub classify_with_history{
    my $self=shift;
    my ($model,$src,$trg,$links)=@_;

    my $BottomUp = 1;
    if ($self->{-linked_parent} || $self->{-linked_parent_distance}){
	$BottomUp = 0;
    }

    my $FE=$self->{FEATURE_EXTRACTOR};
    my @srcnodes=();
    my %srcdone=();
    my @scores=();


    # Bottom-Up: start with leaf nodes

    if ($BottomUp){
	@srcnodes=@{$$src{TERMINALS}};

	# special case: "link non-terminals only"
	# ---> we have to start with the parents of all source terminal nodes!

	foreach my $sn (@srcnodes){
	    my @parents=$self->{TREES}->parents($src,$sn);
	    foreach my $p (@parents){
		push(@srcnodes,$p);
	    }
	}
    }


    # Top-Down: start with root node

    else{
	@srcnodes=($$src{ROOTNODE});

	# special case: link only terminal nodes
	# makes only sense in combination with 'use_existing_links'
	# and parent links exist in the input!

	if ($self->{-terminals_only}){
	    @srcnodes=@{$$src{TERMINALS}};
	}

    }



    # another special case:
    # --> use existing links (mark them as "done")

    if ($self->{-use_existing_links}){
	foreach my $sn (keys %{$links}){
	    foreach my $tn (keys %{$$links{$sn}}){
		$srcdone{$sn}{$tn}=$$links{$sn}{$tn};
	    }
	}
    }


    # run as long as there are srcnodes that we haven't classified yet

    while (@srcnodes){

	$self->{START_EXTRACT_FEATURES}=time();
	my $sn = shift(@srcnodes);
	my $s_is_terminal=$self->{TREES}->is_terminal($src,$sn);
	next if ($self->skip_node($sn,$src,$s_is_terminal));

	my @trgnodes=();
	foreach my $tn (keys %{$$trg{NODES}}){
	    my $t_is_terminal=$self->{TREES}->is_terminal($trg,$tn);

	    ## align ony terminals with terminals and
	    ## nonterminals with nonterminals
	    if ($self->{-same_types_only}){
		if ($s_is_terminal){
		    next if (not $t_is_terminal);
		}
		elsif ($t_is_terminal){next;}
	    }
	    next if ($self->skip_node($tn,$trg,$t_is_terminal));

	    my %values = $FE->features($src,$trg,$sn,$tn);

	    # Bottom-Up: need to add children features

	    if ($BottomUp){
		if ($self->{-linked_children}){
		    $self->linked_children(\%values,$src,$trg,
					   $sn,$tn,\%srcdone,1);
		}
		if ($self->{-linked_subtree}){
		    $self->linked_subtree(\%values,$src,$trg,
					  $sn,$tn,\%srcdone,1);
		}
	    }

	    # Top-Down: need to add parent features

	    else{
		if ($self->{-linked_parent}){
		    $self->linked_parent(\%values,$src,$trg,
					 $sn,$tn,\%srcdone,1);
		}
		if ($self->{-linked_parent_distance}){
		    $self->linked_parent_distance(\%values,$src,$trg,
						  $sn,$tn,\%srcdone,1);
		}
	    }


	    $self->{CLASSIFIER}->add_test_instance(\%values);
	    $self->{NODE_COUNT}++;

	    push(@{$self->{INSTANCES}},"$$src{ID}:$$trg{ID}:$sn:$tn");
	    push(@{$self->{INSTANCES_SRC}},$sn);
	    push(@{$self->{INSTANCES_TRG}},$tn);
	    push(@trgnodes,$tn);

	}
	$self->{TIME_EXTRACT_FEATURES}+=time()-$self->{START_EXTRACT_FEATURES};

	# classify data instances
	$self->{START_CLASSIFICATION}=time();
	my @res = $self->{CLASSIFIER}->classify($model);
	push (@scores,@res);
	$self->{TIME_CLASSIFY}+=time()-$self->{START_CLASSIFICATION};

	# store scores in srcdone hash
	# for linked-children feature
	foreach (0..$#trgnodes){
	    $srcdone{$sn}{$trgnodes[$_]}=$res[$_];
#	    if ($res[$_]>0.5){
#		$srcdone{$sn}{$trgnodes[$_]}=1;
#	    }
	}


	# Bottom-Up: add only those parent nodes 
	#            for which ALL children are done already!

	if ($BottomUp){

	    # add sn's parent nodes to srcnodes if all its children are 
	    # classified already (is this good enough?)

	    my @parents=$self->{TREES}->parents($src,$sn);
	    foreach my $p (@parents){
		next if (exists $srcdone{$p});
		my @children=$self->{TREES}->children($src,$p);
		my $isok=1;
		foreach my $c (@children){
		    $isok = 0 if (not exists $srcdone{$c});
		}
		if ($isok){
		    push(@srcnodes,$p);
		}
	    }
	}

	# Top-Down: easy! --> take children next!

	else{
	    my @srcchildren=$self->{TREES}->children($src,$sn);
	    push(@srcnodes,@srcchildren);
	}


    }

#    print STDERR scalar @scores if ($self->{-verbose});
#    print STDERR " ... scores returned\n"  if ($self->{-verbose});
    return @scores;

}


#
# end of classify_with_history
#----------------------------------------------------------------






sub extract_classification_data{
    my $self=shift;
    my ($src,$trg,$links)=@_;

    my $FE=$self->{FEATURE_EXTRACTOR};
    $FE->clear_cache();

    foreach my $sn (keys %{$$src{NODES}}){
	next if ($sn!~/\S/);
	my $s_is_terminal=$self->{TREES}->is_terminal($src,$sn);
	next if ($self->skip_node($sn,$src,$s_is_terminal));

	foreach my $tn (keys %{$$trg{NODES}}){
	    next if ($tn!~/\S/);
	    my $t_is_terminal=$self->{TREES}->is_terminal($trg,$tn);

	    ## align ony terminals with terminals and
	    ## nonterminals with nonterminals
	    if ($self->{-same_types_only}){
		if ($s_is_terminal){
		    next if (not $t_is_terminal);
		}
		elsif ($t_is_terminal){next;}
	    }
	    next if ($self->skip_node($tn,$trg,$t_is_terminal));

	    my %values = $FE->features($src,$trg,$sn,$tn);
	    $self->{CLASSIFIER}->add_test_instance(\%values);
	    $self->{NODE_COUNT}++;

	    push(@{$self->{INSTANCES}},"$$src{ID}:$$trg{ID}:$sn:$tn");
	    push(@{$self->{INSTANCES_SRC}},$sn);
	    push(@{$self->{INSTANCES_TRG}},$tn);

	}
    }
}







#################################################################
#################################################################
### OLD: separate sub-routines for bottom-up and top-down
#################################################################
#################################################################



#----------------------------------------------------------------
#
# classify_bottom_up
#
# start with leaf nodes and move upwards
#----------------------------------------------------------------

sub classify_bottom_up{
    my $self=shift;
    my ($model,$src,$trg,$links)=@_;

    my $FE=$self->{FEATURE_EXTRACTOR};

    my @srcnodes=@{$$src{TERMINALS}};

    my %srcdone=();
    my @scores=();


    # special case: "link non-terminals only"
    # ---> we have to start with the parents of all source terminal nodes!

    foreach my $sn (@srcnodes){
	my @parents=$self->{TREES}->parents($src,$sn);
	foreach my $p (@parents){
	    push(@srcnodes,$p);
	}
    }

    # another special case:
    # --> use existing links (mark them as "done")

    if ($self->{-use_existing_links}){
	foreach my $sn (keys %{$links}){
	    foreach my $tn (keys %{$$links{$sn}}){
		$srcdone{$sn}{$tn}=$$links{$sn}{$tn};
	    }
	}
    }


    # run as long as there are srcnodes that we haven't classified yet

    while (@srcnodes){

	$self->{START_EXTRACT_FEATURES}=time();
	my $sn = shift(@srcnodes);
	my $s_is_terminal=$self->{TREES}->is_terminal($src,$sn);
	next if ($self->skip_node($sn,$src,$s_is_terminal));

	my @trgnodes=();
	foreach my $tn (keys %{$$trg{NODES}}){
	    my $t_is_terminal=$self->{TREES}->is_terminal($trg,$tn);

	    ## align ony terminals with terminals and
	    ## nonterminals with nonterminals
	    if ($self->{-same_types_only}){
		if ($s_is_terminal){
		    next if (not $t_is_terminal);
		}
		elsif ($t_is_terminal){next;}
	    }
	    next if ($self->skip_node($tn,$trg,$t_is_terminal));

	    my %values = $FE->features($src,$trg,$sn,$tn);
	    if ($self->{-linked_children}){
		$self->linked_children(\%values,$src,$trg,$sn,$tn,\%srcdone,1);
	    }
	    if ($self->{-linked_subtree}){
		$self->linked_subtree(\%values,$src,$trg,$sn,$tn,\%srcdone,1);
	    }

	    $self->{CLASSIFIER}->add_test_instance(\%values);
	    $self->{NODE_COUNT}++;

	    push(@{$self->{INSTANCES}},"$$src{ID}:$$trg{ID}:$sn:$tn");
	    push(@{$self->{INSTANCES_SRC}},$sn);
	    push(@{$self->{INSTANCES_TRG}},$tn);
	    push(@trgnodes,$tn);

	}
	$self->{TIME_EXTRACT_FEATURES}+=time()-$self->{START_EXTRACT_FEATURES};

	# classify data instances
	$self->{START_CLASSIFICATION}=time();
	my @res = $self->{CLASSIFIER}->classify($model);
	push (@scores,@res);
	$self->{TIME_CLASSIFY}+=time()-$self->{START_CLASSIFICATION};

	# store scores in srcdone hash
	# for linked-children feature
	foreach (0..$#trgnodes){
	    $srcdone{$sn}{$trgnodes[$_]}=$res[$_];
#	    if ($res[$_]>0.5){
#		$srcdone{$sn}{$trgnodes[$_]}=1;
#	    }
	}

	# add sn's parent nodes to srcnodes if all its children are 
	# classified already (is this good enough?)

	my @parents=$self->{TREES}->parents($src,$sn);
	foreach my $p (@parents){
	    next if (exists $srcdone{$p});
	    my @children=$self->{TREES}->children($src,$p);
	    my $isok=1;
	    foreach my $c (@children){
		$isok = 0 if (not exists $srcdone{$c});
	    }
	    if ($isok){
		push(@srcnodes,$p);
	    }
	}

    }

#    print STDERR scalar @scores if ($self->{-verbose});
#    print STDERR " ... scores returned\n"  if ($self->{-verbose});
    return @scores;

}


#
# end of classify_bottom_up
#----------------------------------------------------------------



#----------------------------------------------------------------
#
# classify_top_down
#
# start with the root nodes and move downwards
#----------------------------------------------------------------


sub classify_top_down{
    my $self=shift;
    my ($model,$src,$trg,$links)=@_;

    my $FE=$self->{FEATURE_EXTRACTOR};

    my @srcnodes=($$src{ROOTNODE});

    my %srcdone=();
    my @scores=();

    # special case: link only terminal nodes
    # makes only sense in combination with 'use_existing_links'
    # and parent links exist in the input!

    if ($self->{-terminals_only}){
	@srcnodes=@{$$src{TERMINALS}};
    }

    # another special case:
    # --> use existing links (mark them as "done")

    if ($self->{-use_existing_links}){
	foreach my $sn (keys %{$links}){
	    foreach my $tn (keys %{$$links{$sn}}){
		$srcdone{$sn}{$tn}=$$links{$sn}{$tn};
	    }
	}
    }


    while (@srcnodes){

	$self->{START_EXTRACT_FEATURES}=time();
	my $sn = shift(@srcnodes);
	my $s_is_terminal=$self->{TREES}->is_terminal($src,$sn);
	next if ($self->skip_node($sn,$src,$s_is_terminal));

	my @trgnodes=();
	foreach my $tn (keys %{$$trg{NODES}}){
	    my $t_is_terminal=$self->{TREES}->is_terminal($trg,$tn);

	    ## align ony terminals with terminals and
	    ## nonterminals with nonterminals
	    if ($self->{-same_types_only}){
		if ($s_is_terminal){
		    next if (not $t_is_terminal);
		}
		elsif ($t_is_terminal){next;}
	    }
	    next if ($self->skip_node($tn,$trg,$t_is_terminal));

	    my %values = $FE->features($src,$trg,$sn,$tn);
	    if ($self->{-linked_parent}){
		$self->linked_parent(\%values,$src,$trg,$sn,$tn,\%srcdone,1);
	    }
	    if ($self->{-linked_parent_distance}){
		$self->linked_parent_distance(\%values,$src,$trg,$sn,$tn,\%srcdone,1);
	    }

	    $self->{CLASSIFIER}->add_test_instance(\%values);
	    $self->{NODE_COUNT}++;

	    push(@{$self->{INSTANCES}},"$$src{ID}:$$trg{ID}:$sn:$tn");
	    push(@{$self->{INSTANCES_SRC}},$sn);
	    push(@{$self->{INSTANCES_TRG}},$tn);
	    push(@trgnodes,$tn);

	}
	$self->{TIME_EXTRACT_FEATURES}+=time()-$self->{START_EXTRACT_FEATURES};

	# classify data instances
	$self->{START_CLASSIFICATION}=time();
	my @res = $self->{CLASSIFIER}->classify($model);
	push (@scores,@res);
	$self->{TIME_CLASSIFY}+=time()-$self->{START_CLASSIFICATION};

	# store scores in srcdone hash
	# for linked-children feature
	foreach (0..$#trgnodes){
	    $srcdone{$sn}{$trgnodes[$_]}=$res[$_];
#	    if ($res[$_]>0.5){
#		$srcdone{$sn}{$trgnodes[$_]}=1;
#	    }
	}

	my @srcchildren=$self->{TREES}->children($src,$sn);
	push(@srcnodes,@srcchildren);

    }

#    print STDERR scalar @scores if ($self->{-verbose});
#    print STDERR " ... scores returned\n"  if ($self->{-verbose});
    return @scores;

}






1;
__END__

=head1 NAME

Lingua::Align::Trees - Perl modules implementing a discriminative tree aligner

=head1 SYNOPSIS

  use Lingua::Align::Trees;

  my $treealigner = new Lingua::Align::Trees(

    -features => 'inside2:outside2',  # features to be used

    -classifier => 'megam',           # classifier used
    -megam => '/path/to/megam',       # path to learner (megam)

    -classifier_weight_sure => 3,     # training: weight for sure links
    -classifier_weight_possible => 1, # training: weight for possible
    -classifier_weight_negative => 1, # training: weight for non-linked
    -keep_training_data => 1,         # don't remove feature file

    -same_types_only => 1,            # link only T-T and nonT-nonT
    #  -nonterminals_only => 1,       # link non-terminals only
    #  -terminals_only => 1,          # link terminals only
    -skip_unary => 1,                 # skip nodes with unary production

    -linked_children => 1,            # add first-order dependency
    -linked_subtree => 1,             # (children or all subtree nodes)
    # -linked_parent => 0,            # dependency on parent links

    # lexical prob's (src2trg & trg2src)
    -lexe2f => 'moses/model/lex.0-0.e2f',
    -lexf2e => 'moses/model/lex.0-0.f2e',

    # for the GIZA++ word alignment features
    -gizaA3_e2f => 'moses/giza.src-trg/src-trg.A3.final.gz',
    -gizaA3_f2e => 'moses/giza.trg-src/trg-src.A3.final.gz',

    # for the Moses word alignment features
    -moses_align => 'moses/model/aligned.intersect',

    -lex_lower => 1,                  # always convert to lower case!
    -min_score => 0.2,                # classification score threshold
    -verbose => 1,                    # verbose output
  );


  # corpus to be used for training (and testing)
  # default input format is the 
  # Stockholm Tree Aligner format (STA)

  my %corpus = (
      -alignfile => 'Alignments_SMULTRON_Sophies_World_SV_EN.xml',
      -type => 'STA');

  #----------------------------------------------------------------
  # train a model on the first 20 sentences 
  # and save it into "treealign.megam"
  #----------------------------------------------------------------

  $treealigner->train(\%corpus,'treealign.megam',20);

  #----------------------------------------------------------------
  # skip the first 20 sentences (used for training) 
  # and align the following 10 tree pairs 
  # with the model stored in "treealign.megam"
  # alignment search heuristics = greedy
  #----------------------------------------------------------------

  $treealigner->align(\%corpus,'treealign.megam','greedy',10,20);


=head1 DESCRIPTION

This module implements a discriminative tree aligner based on binary classification. Alignment features are extracted for each candidate node pair to be used in a standard binary classifier. As a default we use a MaxEnt learner using a log-linerar combination of features. Feature weights are learned from a tree aligned training corpus. 

=head2 Link search heuristics

For alignment we actually use the conditional probability scores and link search heuristics (3rd argumnt in C<align> method). The default strategy is a threshold based alignment which simply aligns all nodes whose score is above a certain threshold (default=0.5). This is equivalent to using the local classifier without any additional alignment inference step. Other alignment inference strategies include greedy best-first one-to-one alignment (greedy) with additional wellformedness constraints (GreedyWellformed) or greedy source-to-target alignment strategies (src2trg). Another approach is to view tree alignment in terms of standard assignment problems and to use the "Hungarian method" implemented by the Kuhn-Munkres algorithm for alignment inference (munkres). There are many other possibilities for alignment inference. For more information look at L<Lingua::Align::LinkSearch>.


=head2 External resources for feature extraction

Certain features require external resources. For example for lexical equivalence feature we need word alignments and lexical probabilities (see C<-lexe2f>, C<-lexf2e>, C<-gizaA3_e2f>, C<-gizaA3_f2e>, C<-moses_align> attributes). Note that you have to specify the character encoding if you use input that is not in Unicode UTF-8 (for example specify the encoding for C<-lexe2f> with the flag C<-lexe2f_encoding> in the constructor). Remember also to set the flag C<-lex_lower> if your word alignments are done on a lower cased corpus (all strings will be converted to lower case before matching them with the probabilistic lexicon)

B<Note:> Word alignments are read one by one from the given files! Make sure that they match the trees that will be aligned. They have to be in the same order. Important: If you use the C<skip> parameters reading word alignments will NOT be effected. Word alignment features for the first tree pair to be aligned will still be taken from the first word alignment in the given file! However, if you use the same object instance of Lingua::Align::Trees than the read pointer will not be moved (back to the beginning) after training! That means training with the first N tree pairs and aligning the following M tree pairs after skipping N sentences is fine!

The feature settings will be saved together with the model file. Hence, for aligning features do not have to be specified in the constructor of the tree aligner object. They will be read from the model file and the tree aligner will use them automatically when extracting features for alignment.

One exeption are B<link dependency features>. These features are not specified as the other features because they are not directly extracted from the data when aligning. They are based on previous alignment decisions (scores) and, therefore, also influence the alignment algorithm. Link dependency features are enabled by including appropriate flags in the constructor of the tree aligner object.

=over

=item C<-linked_children>

... adds a dependency on the average of the link scores for all (direct) child nodes of the current node pair. In training link scores are 1 for all linked nodes in the training data and 0 for non-linked nodes. In alignment the link prediction scores are used. In order to make this possible alignment will be done in a bottom-up fashion starting at the leaf nodes.

=item C<-linked_subtree>

... adds a dependency on the average of link scores for all descendents of the current node pair (all nodes in the subtrees dominated by the current nodes). It works in the same way as the C<-linked_children> feature and may also be combined with that feature

=item C<-linked_parent>

... adds a dependency on the link score of the immediate parent nodes. This causes the alignment procedure to run in a top-down fashion starting at the root nodes of the trees to be aligned. Hence, it cannot be combined with the previous two link dependency features as the alignment strategy conflicts with this one!

=back

Note that the use of link dependency features is not stored together with the model. Therefore, you always have to specify these flags even in the alignment mode if you want to use them and the model is trained with these features.


=head1 Example feature settings

A very simple example:

  inside4:outside4:inside4*outside4

This will use 3 features: inside4, outside4 and the combined (product) of inside4 and outside4. A more complex example:

  nrleafsratio:inside4:outside4:insideST2:inside4*parent_inside4:treelevelsim*inside4:giza:parent_catpos:moses:moseslink:sister_giza.catpos:parent_parent_giza

In the example above there are some contextual features such as C<parent_catpos> and C<sister_giza>. Note that you can also define recursive contexts such as in C<parent_parent_giza>. Combinations of features can be defined as described earlier. The product of two features is specified with '*' and the concatenation of a feature with a binary feature type such as C<catpos> is specified with '.'. (The example above is not intended to show the best setting to be used. It's only shown for explanatory reasons.)


=head1 SEE ALSO

For a descriptions of features that can be used see L<Lingua::Align::Features>.


=head1 AUTHOR

Joerg Tiedemann, E<lt>j.tiedemann@rug.nlE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 by Joerg Tiedemann

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.


=cut
