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

    $self->{SENT_COUNT}=0;
    $self->{START_EXTRACT_FEATURES}=time();
    $self->extract_training_data($corpus,$features,$max,$skip);
    $self->{TIME_EXTRACT_FEATURES}=time()-$self->{START_EXTRACT_FEATURES};

    $self->{START_TRAIN_MODEL}=time();
    $model = $self->{CLASSIFIER}->train($model);
    $self->{TIME_TRAIN_MODEL} = time() - $self->{START_TRAIN_MODEL};

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

    my %src=();my %trg=();my $links;

    my $count=0;
    my $skipped=0;

    my ($correct,$wrong,$total)=(0,0,0);
    my ($SrcId,$TrgId);

    $self->{TIME_EXTRACT_FEATURES}=0;
    $self->{TIME_CLASSIFICATION}=0;
    $self->{TIME_LINK_SEARCH}=0;
    $self->{SENT_COUNT}=0;

    while ($corpus->next_alignment(\%src,\%trg,\$links)){

	# this is useful to skip sentences that have been used for training
	if (defined $skip){
	    if ($skipped<$skip){
		$skipped++;
		next;
	    }
	}

	$count++;
	if (not($count % 10)){print STDERR '.';}
	if (not($count % 100)){
	    print STDERR " $count aligments\n";
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

	my @scores = $self->classify($model,\%src,\%trg,$links);

	my %links=();
	$self->{START_LINK_SEARCH}=time();
	my ($c,$w,$t)=$searcher->search(\%links,\@scores,$min_score,
					$self->{INSTANCES_SRC},
					$self->{INSTANCES_TRG},
					$self->{LABELS},
					\%src,\%trg);
	$self->{TIME_LINK_SEARCH}+=time()-$self->{START_LINK_SEARCH};

	$correct+=$c;
	$wrong+=$w;
	$total+=$t;

	if ((not defined $SrcId) || (not defined $TrgId)){
	    $SrcId=$corpus->src_treebankID();
	    $TrgId=$corpus->trg_treebankID();
	    my $SrcFile=$corpus->src_treebank();
	    my $TrgFile=$corpus->trg_treebank();
	    print $alignments->print_header($SrcFile,$TrgFile,$SrcId,$TrgId);
	}

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

    ## if there were any lables
    if ($total){
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

    my $corpus = new Lingua::Align::Corpus::Parallel(%{$corpus});

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

    while ($corpus->next_alignment(\%src,\%trg,\$links)){

	# this is useful to skip sentences that shouldn't been used for train
	if (defined $skip){
	    if ($skipped<$skip){
		$skipped++;
		next;
	    }
	}

	# clear the feature value cache
	$FE->clear_cache();

	$count++;
	if (not($count % 10)){
	    print STDERR '.';
	}
	if (not($count % 100)){
	    print STDERR " $count aligments\n";
	}

	if (defined $max){
	    if ($count>$max){
		$corpus->close();
		last;
	    }
	}

	$self->{SENT_COUNT}++;

	foreach my $sn (keys %{$src{NODES}}){
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

		# option: first order dependence on children links
		if ($self->{-linked_children}){
		    $self->linked_children(\%values,\%src,\%trg,
					   $sn,$tn,$links);
		}
		if ($self->{-linked_subtree}){
		    $self->linked_subtree(\%values,\%src,\%trg,
					   $sn,$tn,$links);
		}
		if ($self->{-linked_parent}){
		    $self->linked_parent(\%values,\%src,\%trg,
					 $sn,$tn,$links);
		}
		if ($self->{-linked_parent_distance}){
		    $self->linked_parent_distance(\%values,\%src,\%trg,
						  $sn,$tn,$links);
		}

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

	    push(@{$self->{INSTANCES}},"$$src{ID}:$$trg{ID}:$sn:$tn");
	    push(@{$self->{INSTANCES_SRC}},$sn);
	    push(@{$self->{INSTANCES_TRG}},$tn);

	}
    }
}





1;
__END__

=head1 NAME

YADWA - Perl modules for Yet Another Discriminative Word Aligner

=head1 SYNOPSIS

  use YADWA;

=head1 DESCRIPTION

=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

Joerg Tiedemann, E<lt>j.tiedemanh@rug.nl@E<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 by Joerg Tiedemann

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.


=cut
