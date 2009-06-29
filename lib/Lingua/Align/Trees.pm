package Lingua::Align::Trees;

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
use Lingua::Align::Trees::Features;      # feature extraction module


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
    $self->{FEATURE_EXTRACTOR} = new Lingua::Align::Trees::Features(%attr);
    # make a Treebank object for processing trees
    $self->{TREES} = new Lingua::Align::Corpus::Treebank();

    return $self;
}



# train a classifier for alignment

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

    do {
	$self->{SENT_COUNT}=0;
	$self->{START_EXTRACT_FEATURES}=time();
	$self->{CLASSIFIER}->initialize_training();
	$self->extract_training_data($corpus,$features,$max,$skip);
	$self->{TIME_EXTRACT_FEATURES}+=time()-$self->{START_EXTRACT_FEATURES};

	$self->{START_TRAIN_MODEL}=time();
	$model = $self->{CLASSIFIER}->train($model);
	$self->{TIME_TRAIN_MODEL} += time() - $self->{START_TRAIN_MODEL};

	$done=1;

	# iterative SEARN learning --> adapt structural features
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



    $self->store_features_used($model,$features);
    $self->{TIME_TRAINING} = time() - $self->{START_TRAINING};

    if ($self->{-verbose}){
	print STDERR "\n============ ";
	print STDERR "statistics for training an alignment model ";
	print STDERR "======\n";
	printf STDERR "%30s: %f (%f/sentence)\n","time for feature extraction",
	$self->{TIME_EXTRACT_FEATURES},
	$self->{TIME_EXTRACT_FEATURES}/$self->{SENT_COUNT};
	printf STDERR "%30s: %f\n","time for training classifier",
	$self->{TIME_TRAIN_MODEL};
	printf STDERR "%30s: %f\n","total time training",
	$self->{TIME_TRAINING};
	print STDERR "==================";
	print STDERR "============================================\n\n";
    }
}




sub align{
    my $self=shift;

    $self->{START_ALIGNING}=time();
    my ($corpus,$model,$type,$max,$skip)=@_;

    $self->{CLASSIFIER}->initialize_classification($model);
    my $features = $self->get_features_used($model);
#    my $features = $_[5] || $self->{-features};
#    my $min_score = $self->{-min_score} || 0.2;
    my $min_score = $self->{-min_score};

    my $FE=$self->{FEATURE_EXTRACTOR};
    $FE->initialize_features($features);
#    $self->initialize_features($features);
    if (ref($corpus) ne 'HASH'){die "please specify a corpus!";}

    # make a corpus object
    my $corpus = new Lingua::Align::Corpus::Parallel(%{$corpus});
    # make a search object
    my $searcher = new Lingua::Align::LinkSearch(-link_search => $type);

    # output data
    my %output;
    $output{-type} = $self->{-output_format} || 'sta';
    my $alignments = new Lingua::Align::Corpus::Parallel(%output);

    my %src=();my %trg=();my $existing_links;

    my $count=0;
    my $skipped=0;

    my ($correct,$wrong,$total)=(0,0,0);
    my ($SrcId,$TrgId);

    $self->{TIME_EXTRACT_FEATURES}=0;
    $self->{TIME_CLASSIFICATION}=0;
    $self->{TIME_LINK_SEARCH}=0;
    $self->{SENT_COUNT}=0;

    while ($corpus->next_alignment(\%src,\%trg,\$existing_links)){

	# this is useful to skip sentences that have been used for training
	if (defined $skip){
	    if ($skipped<$skip){
		$skipped++;
		next;
	    }
	}

#	if ($src{NODES}{'12_9'}{'word'} eq 'Evans'){
#	    print '';
#	}

	$count++;
	if (not($count % 10)){print STDERR '.';}
	if (not($count % 100)){
	    print STDERR " $count aligments (";
	    my $elapsed = time() - $self->{START_ALIGNING};
	    print STDERR $elapsed;
	    printf STDERR " sec, %f/sentence)\n",$elapsed/$count;
	}
	if (defined $max){
	    if ($count>$max){
		$corpus->close();
		last;
	    }
	}

	$self->{SENT_COUNT}++;

	$self->{INSTANCES}=[];
	$self->{INSTANCES_SRC}=[];
	$self->{INSTANCES_TRG}=[];

# 	# extract features
# 	$self->{START_EXTRACT_FEATURES}=time();
# 	$self->extract_classification_data(\%src,\%trg,$links);
# 	$self->{TIME_EXTRACT_FEATURES}+=time()-$self->{START_EXTRACT_FEATURES};

# 	# classify data instances
# 	$self->{START_CLASSIFICATION}=time();
# 	my @scores = $self->{CLASSIFIER}->classify($model);
# 	$self->{TIME_CLASSIFY}+=time()-$self->{START_CLASSIFICATION};

	my @scores = $self->classify($model,\%src,\%trg,$existing_links);

	my %links=();
	$self->{START_LINK_SEARCH}=time();

	# add existing links if necessary --> good to inlcude here already
	# because they may influence the link search (wellformedness ...)

	# "compete" --> let the existing links compete with the new ones
	if ($self->{-add_links}=~/compet/){
	    foreach my $sid (keys %{$existing_links}){
		foreach my $tid (keys %{$$existing_links{$sid}}){
		    push(@{$self->{INSTANCES_SRC}},$sid);
		    push(@{$self->{INSTANCES_TRG}},$tid);
		    push(@{$self->{LABELS}},1);
		    push(@scores,$$existing_links{$sid}{$tid});
		}
	    }
	}
	# otherwise: just leave the existing links as they are and just add new
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

	my ($c,$w,$t)=$searcher->search(\%links,\@scores,$min_score,
					$self->{INSTANCES_SRC},
					$self->{INSTANCES_TRG},
					$self->{LABELS},
					\%src,\%trg);
	$self->{TIME_LINK_SEARCH}+=time()-$self->{START_LINK_SEARCH};

	# option add_links means that we keep existing links and
	# add the new ones to the exting ones!
	# --> don't us existing ones for evaluation!
	if (not $self->{-add_links}){
	    $correct+=$c;
	    $wrong+=$w;
	    $total+=$t;
	}

	if ((not defined $SrcId) || (not defined $TrgId)){
	    $SrcId=$corpus->src_treebankID();
	    $TrgId=$corpus->trg_treebankID();
	    my $SrcFile=$corpus->src_treebank();
	    my $TrgFile=$corpus->trg_treebank();
	    print $alignments->print_header($SrcFile,$TrgFile,$SrcId,$TrgId);
	}

# 	if ($self->{-add_links}){
# 	    foreach my $sid (keys %{$existing_links}){
# 		foreach my $tid (keys %{$$existing_links{$sid}}){
# 		    if (exists $links{$sid}{$tid} && $self->{-verbose}>1){
# 			print STDERR "link between $sid and $tid exists\n";
# 		    }
# 		    $links{$sid}{$tid}=$$existing_links{$sid}{$tid};
# 		}
# 	    }
# 	}

	print $alignments->print_alignments(\%src,\%trg,\%links,$SrcId,$TrgId);

# 	foreach my $snid (keys %links){
# 	    foreach my $tnid (keys %{$links{$snid}}){
# 		print "<align comment=\"$links{$snid}{$tnid}\" type=\"auto\">\n";
# 		print "  <node node_id=\"$snid\" treebank_id=\"src\"/>\n";
# 		print "  <node node_id=\"$tnid\" treebank_id=\"trg\"/>\n";
# 		print "<align/>\n";
# 	    }
# 	}


    }
    print $alignments->print_tail();

    ## if there were any lables & we are not in 'add_links' mode
    if ($total && (not $self->{-add_links})){
	my $precision = 0;
	if ($correct || $wrong){
	    $precision = $correct/($correct+$wrong);
	}
	my $recall = $correct/($total);

	printf STDERR "\n%20s = %5.2f (%d/%d)\n","precision",
	$precision*100,$correct,$correct+$wrong;
	printf STDERR "%20s = %5.2f (%d/%d)\n","recall",
	$recall*100,$correct,$total;
	my $F=0;
	if ($precision || $recall){
	    $F=2*$precision*$recall/($precision+$recall);
	}
	printf STDERR "%20s = %5.2f\n","balanced F",100*$F;
#	print STDERR "=======================================\n";

    }
    $self->{TIME_ALIGNING} = time() - $self->{START_ALIGNING};

    if ($self->{-verbose}){
	if ($self->{SENT_COUNT}){
	    print STDERR "\n================= ";
	    print STDERR "statistics for aligning trees ==============\n";
	    printf STDERR "%30s: %f (%f/sentence)\n","time for feature extraction",
	    $self->{TIME_EXTRACT_FEATURES},
	    $self->{TIME_EXTRACT_FEATURES}/$self->{SENT_COUNT};
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


sub extract_training_data{
    my $self=shift;
    my ($corpus,$features,$max,$skip)=@_;
    if (not $features){$features = $self->{-features};}

    print STDERR "extract features for training!\n";

    my $FE=$self->{FEATURE_EXTRACTOR};
    $FE->initialize_features($features);
#    $self->initialize_features($features);

    if (ref($corpus) ne 'HASH'){
	die "please specify a corpus to be used for training!";
    }

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
#    my $LinkProbs;

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
	# adaptive learning a la SEARN (combine true & predicted values)

	if (defined $self->{-searn_model}){

	    # make link prob's out of link types ....

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

	#-------------------------------------------------------------------



	$count++;
	if (not($count % 10)){print STDERR '.';}
	elsif (not($count % 100)){print STDERR " $count aligments\n";}

	if (defined $max){
	    if ($count>$max){
		$CorpusHandle->close();
		last;
	    }
	}

	$self->{SENT_COUNT}++;

	foreach my $sn (keys %{$src{NODES}}){
	    next if ($sn!~/\S/);
	    my $s_is_terminal=$self->{TREES}->is_terminal(\%src,$sn);

	    ## align only non-terminals!
	    if ($self->{-nonterminals_only}){
		next if ($s_is_terminal);
	    }
	    ## align only terminals!
	    ## (do we need this?)
	    if ($self->{-terminals_only}){
		next if (not $s_is_terminal);
	    }
	    # skip nodes with unary productions
	    if ($self->{-skip_unary}){
		if ($self->{-nonterminals_only} ||  # special treatment for
		    $self->{-same_types_only}){     # unary subtrees with
		    my $c=undef;                    # a terminal as child
		    if ($self->{TREES}->is_unary_subtree(\%src,$sn,\$c)){
			next if ($self->{TREES}->is_nonterminal(\%src,$c));
		    }
		}
		else{
		    next if ($self->{TREES}->is_unary_subtree(\%src,$sn));
		}
	    }
	    
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
		## align only non-terminals!
		if ($self->{-nonterminals_only}){
		    next if ($t_is_terminal);
		}
		## align only terminals!
		if ($self->{-terminals_only}){
		    next if (not $t_is_terminal);
		}
		# skip nodes with unary productions
		if ($self->{-skip_unary}){
		    if ($self->{-nonterminals_only} ||  # special treatment for
			$self->{-same_types_only}){     # unary subtrees with
			my $c=undef;                    # a terminal as child
			if ($self->{TREES}->is_unary_subtree(\%trg,$tn,\$c)){
			    next if ($self->{TREES}->is_nonterminal(\%trg,$c));
			}
		    }
		    else{
			next if ($self->{TREES}->is_unary_subtree(\%trg,$tn));
		    }
		}
		# skip nodes with unary productions
		if ($self->{-skip_unary}){
		    next if ($self->{TREES}->is_unary_subtree(\%trg,$tn));
		}

		my %values = $FE->features(\%src,\%trg,$sn,$tn);


		#-----------------------------------------------------------
		# structural dependencies
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

#		$values{"$sn-$tn"} = 1;

		# positive training events
		# (good/sure examples && fuzzy/possible examples)

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
#			    my %values = $FE->features(\%src,\%trg,$sn,$tn);
			    $self->{CLASSIFIER}->add_train_instance(
				1,\%values,$weightPossible);
			}
		    }
		}

		# negative training events

		elsif ($weightNegative){
#		    my %values = $FE->features(\%src,\%trg,$sn,$tn);
		    $self->{CLASSIFIER}->add_train_instance(
			'0',\%values,$weightNegative);
		}
	    }
	}
    }
}


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


sub linked_children_new{
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

sub linked_subtree_new{
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


sub linked_children_inside_outside{
    my $self=shift;
    my ($values,$src,$trg,$sn,$tn,$links,$softcount)=@_;
    my @srcchildren=$self->{TREES}->children($src,$sn);
    my @trgchildren=$self->{TREES}->children($trg,$tn);

#    my %srcLeafIDs=();
#    foreach (@srcchildren){$srcLeafIDs{$_}=1;}
    my %trgLeafIDs=();
    foreach (@trgchildren){$trgLeafIDs{$_}=1;}

    my $inside=0;
    my $outside=0;

#    my $nr=0;
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


sub classify{
    my $self=shift;

    if ($self->{-linked_children} || $self->{-linked_subtree}){
	return $self->classify_bottom_up(@_);
    }
    elsif ($self->{-linked_parent} || $self->{-linked_parent_distance}){
	return $self->classify_top_down(@_);
    }

    my ($model,$src,$trg,$links)=@_;

    # extract features
    $self->{START_EXTRACT_FEATURES}=time();
    $self->extract_classification_data($src,$trg,$links);
    $self->{TIME_EXTRACT_FEATURES}+=time()-$self->{START_EXTRACT_FEATURES};
    
    # classify data instances
    $self->{START_CLASSIFICATION}=time();
    my @scores = $self->{CLASSIFIER}->classify($model);
    $self->{TIME_CLASSIFY}+=time()-$self->{START_CLASSIFICATION};

#    print STDERR scalar @scores if ($self->{-verbose});
#    print STDERR " ... scores returned\n"  if ($self->{-verbose});
    return @scores;

}


sub classify_bottom_up{
    my $self=shift;
    my ($model,$src,$trg,$links)=@_;

    $self->{LABELS}=[];
    my $FE=$self->{FEATURE_EXTRACTOR};

    my @srcnodes=@{$$src{TERMINALS}};
    my @trgnodes=@{$$trg{TERMINALS}};

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

	## align only non-terminals!
	if ($self->{-nonterminals_only}){
	    next if ($s_is_terminal);
	}
	## align only terminals!
	## (do we need this?)
	if ($self->{-terminals_only}){
	    next if (not $s_is_terminal);
	}
	# skip nodes with unary productions
	if ($self->{-skip_unary}){
	    if ($self->{-nonterminals_only} ||  # special treatment for
		$self->{-same_types_only}){     # unary subtrees with
		my $child=undef;                # a terminal as child node
		if ($self->{TREES}->is_unary_subtree($src,$sn,\$child)){
		    next if ($self->{TREES}->is_nonterminal($src,$child));
		}
	    }
	    else{
		next if ($self->{TREES}->is_unary_subtree($src,$sn));
	    }
	}

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
	    ## align only non-terminals!
	    if ($self->{-nonterminals_only}){
		next if ($t_is_terminal);
	    }
	    ## align only terminals!
	    if ($self->{-terminals_only}){
		next if (not $t_is_terminal);
	    }
	    # skip nodes with unary productions
	    if ($self->{-skip_unary}){              
		if ($self->{-nonterminals_only} ||  # special treatment for
		    $self->{-same_types_only}){     # unary subtrees with
		    my $child=undef;                # a terminal as child node
		    if ($self->{TREES}->is_unary_subtree($trg,$tn,\$child)){
			next if ($self->{TREES}->is_nonterminal($trg,$child));
		    }
		}
		else{
		    next if ($self->{TREES}->is_unary_subtree($trg,$tn));
		}
	    }


	    my $label=0;
	    if ((ref($$links{$sn}) eq 'HASH') && 
		(exists $$links{$sn}{$tn})){
		if ($self->{-count_good_only}){           # discard fuzzy
		    if ($$links{$sn}{$tn}=~/(good|S)/){
			$label=1;
		    }
		}
		else{$label=1;}
	    }
	    push(@{$self->{LABELS}},$label);
	    my %values = $FE->features($src,$trg,$sn,$tn);
	    if ($self->{-linked_children}){
		$self->linked_children(\%values,$src,$trg,$sn,$tn,\%srcdone,1);
	    }
	    if ($self->{-linked_subtree}){
		$self->linked_subtree(\%values,$src,$trg,$sn,$tn,\%srcdone,1);
	    }

	    $self->{CLASSIFIER}->add_test_instance(\%values,$label);

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
	# classified already (good enough?)

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






sub classify_top_down{
    my $self=shift;
    my ($model,$src,$trg,$links)=@_;

    $self->{LABELS}=[];
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

	## align only non-terminals!
	if ($self->{-nonterminals_only}){
	    next if ($s_is_terminal);
	}
	## align only terminals!
	## (do we need this?)
	if ($self->{-terminals_only}){
	    next if (not $s_is_terminal);
	}
	# skip nodes with unary productions
	if ($self->{-skip_unary}){
	    if ($self->{-nonterminals_only} ||  # special treatment for
		$self->{-same_types_only}){     # unary subtrees with
		my $child=undef;                # a terminal as child node
		if ($self->{TREES}->is_unary_subtree($src,$sn,\$child)){
		    next if ($self->{TREES}->is_nonterminal($src,$child));
		}
	    }
	    else{
		next if ($self->{TREES}->is_unary_subtree($src,$sn));
	    }
	}

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
	    ## align only non-terminals!
	    if ($self->{-nonterminals_only}){
		next if ($t_is_terminal);
	    }
	    ## align only terminals!
	    if ($self->{-terminals_only}){
		next if (not $t_is_terminal);
	    }
	    # skip nodes with unary productions
	    if ($self->{-skip_unary}){              
		if ($self->{-nonterminals_only} ||  # special treatment for
		    $self->{-same_types_only}){     # unary subtrees with
		    my $child=undef;                # a terminal as child node
		    if ($self->{TREES}->is_unary_subtree($trg,$tn,\$child)){
			next if ($self->{TREES}->is_nonterminal($trg,$child));
		    }
		}
		else{
		    next if ($self->{TREES}->is_unary_subtree($trg,$tn));
		}
	    }


	    my $label=0;
	    if ((ref($$links{$sn}) eq 'HASH') && 
		(exists $$links{$sn}{$tn})){
		if ($self->{-count_good_only}){           # discard fuzzy
		    if ($$links{$sn}{$tn}=~/(good|S)/){
			$label=1;
		    }
		}
		else{$label=1;}
	    }
	    push(@{$self->{LABELS}},$label);
	    my %values = $FE->features($src,$trg,$sn,$tn);
	    if ($self->{-linked_parent}){
		$self->linked_parent(\%values,$src,$trg,$sn,$tn,\%srcdone,1);
	    }
	    if ($self->{-linked_parent_distance}){
		$self->linked_parent_distance(\%values,$src,$trg,$sn,$tn,\%srcdone,1);
	    }

	    $self->{CLASSIFIER}->add_test_instance(\%values,$label);

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




sub extract_classification_data{
    my $self=shift;
    my ($src,$trg,$links)=@_;

    $self->{LABELS}=[];
    my $FE=$self->{FEATURE_EXTRACTOR};

    foreach my $sn (keys %{$$src{NODES}}){
	next if ($sn!~/\S/);
	my $s_is_terminal=$self->{TREES}->is_terminal($src,$sn);

	## align only non-terminals!
	if ($self->{-nonterminals_only}){
	    next if ($s_is_terminal);
	}
	## align only terminals!
	## (do we need this?)
	if ($self->{-terminals_only}){
	    next if (not $s_is_terminal);
	}
	# skip nodes with unary productions
	if ($self->{-skip_unary}){
	    if ($self->{-nonterminals_only} ||  # special treatment for
		$self->{-same_types_only}){     # unary subtrees with
		my $child=undef;                # a terminal as child node
		if ($self->{TREES}->is_unary_subtree($src,$sn,\$child)){
		    next if ($self->{TREES}->is_nonterminal($src,$child));
		}
	    }
	    else{
		next if ($self->{TREES}->is_unary_subtree($src,$sn));
	    }
	}

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
	    ## align only non-terminals!
	    if ($self->{-nonterminals_only}){
		next if ($t_is_terminal);
	    }
	    ## align only terminals!
	    if ($self->{-terminals_only}){
		next if (not $t_is_terminal);
	    }
	    # skip nodes with unary productions
	    if ($self->{-skip_unary}){              
		if ($self->{-nonterminals_only} ||  # special treatment for
		    $self->{-same_types_only}){     # unary subtrees with
		    my $child=undef;                # a terminal as child node
		    if ($self->{TREES}->is_unary_subtree($trg,$tn,\$child)){
			next if ($self->{TREES}->is_nonterminal($trg,$child));
		    }
		}
		else{
		    next if ($self->{TREES}->is_unary_subtree($trg,$tn));
		}
	    }


	    my $label=0;
	    if ((ref($$links{$sn}) eq 'HASH') && 
		(exists $$links{$sn}{$tn})){
		if ($self->{-count_good_only}){           # discard fuzzy
		    if ($$links{$sn}{$tn}=~/(good|S)/){
			$label=1;
		    }
		}
		else{$label=1;}
	    }
	    push(@{$self->{LABELS}},$label);
	    my %values = $FE->features($src,$trg,$sn,$tn);
	    $self->{CLASSIFIER}->add_test_instance(\%values,$label);

#	    print STDERR $label,' ';
#	    print STDERR join(':',%values);
#	    print STDERR "\n";
#	    print STDERR "\n----------------------------------\n";

	    push(@{$self->{INSTANCES}},"$$src{ID}:$$trg{ID}:$sn:$tn");
	    push(@{$self->{INSTANCES_SRC}},$sn);
	    push(@{$self->{INSTANCES_TRG}},$tn);

	}
    }
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

For alignment we actually use the conditional probability scores and link search heuristics (3rd argumnt in C<align> method). The default heuristic is a greedy one-to-one alignment best-first heuristics. Other possibilities are "intersection", "src2trg", "trg2src" and "refined" which are defined in a similar way as word alignment symmetrization heuristics are defined. The C<-min_score> parameter is used to set a threshold for the minimum score for establishing a link (default is 0)


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

For a descriptions of features that can be used see L<Lingua::Align::Trees::Features>.


=head1 AUTHOR

Joerg Tiedemann, E<lt>j.tiedemann@rug.nlE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 by Joerg Tiedemann

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.


=cut
