package Lingua::Align::Trees;

use 5.005;
use strict;

use vars qw($VERSION @ISA);
@ISA = qw();
$VERSION = '0.01';

use FileHandle;
use Lingua::Align::Corpus::Parallel;
use Lingua::Align::Corpus::Treebank;
use Lingua::Align::Classifier;
use Lingua::Align::Trees::Greedy;


my $DEFAULTFEATURES = 'inside:outside';

sub new{
    my $class=shift;
    my %attr=@_;

    my $self={};
    bless $self,$class;

    foreach (keys %attr){
	$self->{$_}=$attr{$_};
    }

    $self->{CLASSIFIER} = new Lingua::Align::Classifier(%attr);

    return $self;
}



# train a classifier for alignment

sub train{
    my $self=shift;
    my ($corpus,$model,$max,$skip)=@_;
    my $features = $_[4] || $self->{-features};

    # $corpus is a pointer to hash with all parameters necessary 
    # to access the training corpus
    #
    # $features is a pointer to a hash specifying the features to be used
    #
    # $model is the name of the model-file

    $self->extract_training_data($corpus,$features,$max,$skip);
    $self->{CLASSIFIER}->train($model);

}


sub align{
    my $self=shift;
    my ($corpus,$model,$max,$skip)=@_;
    my $features = $_[4] || $self->{-features};
    my $max_score = $self{-max_score} || 0.2;


    $self->initialize_features($features);
    if (ref($corpus) ne 'HASH'){die "please specify a corpus!";}

    # make a corpus object
    my $corpus = new Lingua::Align::Corpus::Parallel(%{$corpus});
    # make a Treebank object for processing trees
    $self->{TREES} = new Lingua::Align::Corpus::Treebank();
    # make a search object
    my $searcher = new Lingua::Align::Trees::Greedy;

    my %src=();my %trg=();my $links;

    my $count=0;
    my $skipped=0;

    my ($correct,$wrong,$missed)=(0,0);

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

	$self->{INSTANCES}=[];
	$self->extract_classification_data(\%src,\%trg,$links);
	my @scores = $self->{CLASSIFIER}->classify($model);

	my %links=();
	my ($c,$w,$m)=$searcher->search(\%links,\@scores,$max_score,
					$self->{INSTANCES},
					$self->{LABELS});

	$correct+=$c;
	$wrong+=$w;
	$missed+=$m;

	foreach my $snid (keys %links){
	    foreach my $tnid (keys %{$links{$snid}}){
		print "<align comment=\"$links{$snid}{$tnid}\" type=\"auto\">\n";
		print "  <node node_id=\"$snid\" treebank_id=\"src\"/>\n";
		print "  <node node_id=\"$tnid\" treebank_id=\"trg\"/>\n";
		print "<align/>\n";
	    }
	}
		
# 	for (0..$#scores){
# 	    if ($scores[$_]>0.5){
# #		print $self->{INSTANCES}->[$_],"\n";
# 		my ($sid,$tid,$snid,$tnid)=
# 		    split(/\:/,$self->{INSTANCES}->[$_]);
# 		print "<align comment=\"$scores[$_]\" type=\"automatical\">\n";
# 		print "  <node node_id=\"$snid\" treebank_id=\"src\"/>\n";
# 		print "  <node node_id=\"$tnid\" treebank_id=\"trg\"/>\n";
# 		print "<align/>\n";
# 	    }
# 	}

    }

    ## if there were any lables
    if ($correct || $missed){
	my $precision = $correct/($correct+$wrong);
	my $recall = $correct/($correct+$missed);

	printf STDERR "precision = %5.2f (%d/%d)\n",
	$precision*100,$correct,$correct+$wrong;
	printf STDERR "recall = %5.2f (%d/%d)\n",
	$recall*100,$correct,$correct+$missed;
	printf STDERR "balanced F = %5.2f\n",
	200*$precision*$recall/($precision+$recall);
	print STDERR "=======================================\n";

    }
}

sub align_old{
    my $self=shift;
    my ($corpus,$model,$max,$skip)=@_;
    my $features = $_[4] || $self->{-features};
    $self->initialize_features($features);
    $self->extract_classification_data_old($corpus,$features,$max,$skip);
#    $self->{CLASSIFIER}->classify($model);
    my @scores = $self->{CLASSIFIER}->classify($model);

    for (0..$#scores){
	if ($scores[$_]>0.5){
#		print $self->{INSTANCES}->[$_],"\n";
	    my ($sid,$tid,$snid,$tnid)=
		split(/\:/,$self->{INSTANCES}->[$_]);
	    print "<align comment=\"$scores[$_]\" type=\"automatical\">\n";
	    print "  <node node_id=\"$snid\" treebank_id=\"src\"/>\n";
	    print "  <node node_id=\"$tnid\" treebank_id=\"trg\"/>\n";
	    print "<align/>\n";
	}
    }

}


sub extract_training_data{
    my $self=shift;
    my ($corpus,$features,$max,$skip)=@_;
    if (not $features){$features = $self->{-features};}

    print STDERR "extract features for training!\n";

    $self->initialize_features($features);

    if (ref($corpus) ne 'HASH'){
	die "please specify a corpus to be used for training!";
    }
    if (ref($features) ne 'HASH'){
	$features = { inside => 1,
		      outside => 1};
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

    # make a Treebank object for processing trees
    $self->{TREES} = new Lingua::Align::Corpus::Treebank();

    my %src=();
    my %trg=();
    my $links;

    my $count=0;

    while ($corpus->next_alignment(\%src,\%trg,\$links)){

	# clear the feature value cache
	$self->clear_cache();

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

	foreach my $sn (keys %{$src{NODES}}){
	    foreach my $tn (keys %{$trg{NODES}}){

		# positive training events
		# (good/sure examples && fuzzy/possible examples)

		if ((ref($$links{$sn}) eq 'HASH') && 
		    (exists $$links{$sn}{$tn})){

		    if ($$links{$sn}{$tn}=~/(good|S)/){
			if ($weightSure){
			    my %values = $self->features(\%src,\%trg,$sn,$tn);
			    $self->{CLASSIFIER}->add_train_instance(
				1,\%values,$weightSure);
			}
		    }
		    elsif ($$links{$sn}{$tn}=~/(fuzzy|possible|P)/){
			if ($weightPossible){
			    my %values = $self->features(\%src,\%trg,$sn,$tn);
			    $self->{CLASSIFIER}->add_train_instance(
				1,\%values,$weightPossible);
			}
		    }
		}

		# negative training events

		elsif ($weightNegative){
		    my %values = $self->features(\%src,\%trg,$sn,$tn);
		    $self->{CLASSIFIER}->add_train_instance(
			'0',\%values,$weightNegative);
		}
	    }
	}
    }
}


sub extract_classification_data{
    my $self=shift;
    my ($src,$trg,$links)=@_;
    $self->{LABELS}=[];
    foreach my $sn (keys %{$$src{NODES}}){
	foreach my $tn (keys %{$$trg{NODES}}){
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
	    my %values = $self->features($src,$trg,$sn,$tn);
	    $self->{CLASSIFIER}->add_test_instance(\%values,$label);

	    push(@{$self->{INSTANCES}},"$$src{ID}:$$trg{ID}:$sn:$tn");

	}
    }
}


sub extract_classification_data_old{
    my $self=shift;
    my ($corpus,$features,$max,$skip)=@_;
    if (not $features){$features = $self->{-features};}

    print STDERR "extract features for classification!\n";
    $self->initialize_features($features);

    if (ref($corpus) ne 'HASH'){
	die "please specify a corpus!";
    }

    my $corpus = new Lingua::Align::Corpus::Parallel(%{$corpus});

    # make a Treebank object for processing trees
    $self->{TREES} = new Lingua::Align::Corpus::Treebank();

    my %src=();
    my %trg=();
    my $links;

    my $count=0;
    my $skipped=0;

    $self->{INSTANCES}=[];

    while ($corpus->next_alignment(\%src,\%trg,\$links)){

	# this is useful to skip sentences that have been used for training
	if (defined $skip){
	    if ($skipped<$skip){
		$skipped++;
		next;
	    }
	}

	# clear the feature value cache
	$self->clear_cache();

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

	foreach my $sn (keys %{$src{NODES}}){
	    foreach my $tn (keys %{$trg{NODES}}){
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
		my %values = $self->features(\%src,\%trg,$sn,$tn);
		$self->{CLASSIFIER}->add_test_instance(\%values,$label);

		push(@{$self->{INSTANCES}},"$src{ID}:$trg{ID}:$sn:$tn");

	    }
	}
    }
}



#########################################################################
#
# sub routines for extracting features .......
#
# should I divide this a bit more into smaller sub's?
# maybe a separate module?
#


sub __need_lex{
    my $features=shift;
    foreach (keys %{$features}){
	return 1 if (/(inside|outside)/);
    }
    return 0;
}

sub initialize_features{
    my $self=shift;
    my $features=shift;

    # check if features is a pointer to a hash
    # or a string based feature specification

    if (ref($features) ne 'HASH'){
	if (not defined $features){
	    $features = $self->{-features} || $DEFAULTFEATURES;
	}
	my @feat=split(/\:/,$features);          # split feature string
	$self->{FEATURES}={};
	foreach (@feat){
	    my ($name,$val)=split(/\=/);
	    $self->{FEATURES}->{$name}=$val;
	}
    }
    %{$self->{FEATURE_TYPES}} = $self->feature_types();

    if (__need_lex($self->{FEATURE_TYPES})){    # load lexicon if necessary
	$self->load_moses_lex();
    }
}




# return feature types used in all features used (simple or complex ones)

sub feature_types{
    my $self=shift;

    if (ref($self->{FEATURES}) ne 'HASH'){
	$self->initialize_features();
    }

    my %feattypes=();

    foreach my $f (keys %{$self->{FEATURES}}){
	if ($f=~/\*/){
	    my @fact = split(/\*/,$f);
	    foreach (@fact){
		$feattypes{$_}=$self->{FEATURES}->{$f};
	    }
	}

	## average
	elsif ($f=~/\+/){
	    my @fact = split(/\+/,$f);
	    foreach (@fact){
		$feattypes{$_}=$self->{FEATURES}->{$f};
	    }
	}

	## standard single type features
	else{
	    $feattypes{$f}=$self->{FEATURES}->{$f};
	}
    }

    return %feattypes;

}


sub features{
    my $self=shift;
    my ($srctree,$trgtree,$srcnode,$trgnode)=@_;
    my %feat = $self->get_features($srctree,$trgtree,$srcnode,$trgnode);

    ## combine features if necessary
    my %retfeat=();
    foreach my $f (keys %{$self->{FEATURES}}){
	if ($f=~/\*/){                       # multiply factors
	    my @fact = split(/\*/,$f);
	    my $score=1;
	    foreach (@fact){
		if (exists $feat{$_}){
		    $score*=$feat{$_};
		}
		else{              # factor doesn't exist!
		    $score=0;      # --> score = 0 & stop!
		    last;
		}
	    }
	    $retfeat{$f}=$score;
	}

	elsif ($f=~/\+/){                    # average of factors
	    my @fact = split(/\+/,$f);
	    my $score=0;
	    foreach (@fact){
		if (exists $feat{$_}){
		    $score+=$feat{$_};
		}
	    }
	    $score/=($#fact+1);
	    $retfeat{$f}=$score;
	}

	else{                                # standard single type features
	    $retfeat{$f}=$feat{$f};
	}

	if ($retfeat{$f} == 0){
	    delete $retfeat{$f};
	}
    }


    foreach (keys %feat){
	if (not exists $retfeat{$_}){
	    if (/\_/){                   # feature template like 'pos'
		my @part = split(/\_/);
		if (exists $self->{FEATURES}->{$part[0]}){
		    $retfeat{$_}=$feat{$_};
		}
	    }
	}
    }

    return %retfeat;
}








sub load_moses_lex{
    my $self=shift;

    return 1 if ((exists $self->{LEXE2F}) && (exists $self->{LEXF2E}));

    my $lexe2f = $self->{-lexe2f} || 'moses/model/lex.0-0.e2f';
    my $encoding = $self->{-lexe2f_encoding} || 'utf8';

    if (-e $lexe2f){
	print STDERR "load $lexe2f ....";
	open F,"<$lexe2f" || die "cannot open lexe2f file $lexe2f\n";
	binmode(F,":encoding($encoding)");
	while (<F>){
	    chomp;
	    my ($src,$trg,$score)=split(/\s+/);
	    $self->{LEXE2F}->{$src}->{$trg}=$score;
	}
	close F;
	print STDERR " done!\n";
    }

    my $lexf2e = $self->{-lexf2e} || 'moses/model/lex.0-0.f2e';
    if (-e $lexf2e){
	print STDERR "load $lexe2f ....";
	open F,"<$lexf2e" || die "cannot open lexf2e file $lexf2e\n";
	binmode(F,":encoding($encoding)");
	while (<F>){
	    chomp;
	    my ($trg,$src,$score)=split(/\s+/);
	    $self->{LEXF2E}->{$trg}->{$src}=$score;
	}
	close F;
	print STDERR " done!\n";
    }
}


sub clear_cache{
    my $self=shift;
    $self->{CACHE}={};   # is this good enough?
}


sub get_features{
    my $self=shift;
    my ($srctree,$trgtree,$srcnode,$trgnode)=@_;
    my $features = $_[4] || $self->{FEATURE_TYPES};

    my %values=();

    my @srcleafs = $self->{TREES}->get_leafs($srctree,$srcnode);
    my @trgleafs = $self->{TREES}->get_leafs($trgtree,$trgnode);


    my %todo=%{$features};
    my $key = "$srctree->{ID}:$trgtree->{ID}:$srcnode:$trgnode";
    foreach (keys %{$features}){
	if (exists $self->{CACHE}->{$key}->{$_}){
	    $values{$_}=$self->{CACHE}->{$key}->{$_};
	    delete $todo{$_};
	}
    }

    ## category or POS pair

    if (exists $todo{catpos}){
	my $key='catpos_';
	if (exists $srctree->{NODES}->{$srcnode}->{cat}){
	    $key.=$srctree->{NODES}->{$srcnode}->{cat};
	}
	elsif (exists $srctree->{NODES}->{$srcnode}->{pos}){
	    $key.=$srctree->{NODES}->{$srcnode}->{pos};
	}
	$key.='_';
	if (exists $trgtree->{NODES}->{$trgnode}->{cat}){
	    $key.=$trgtree->{NODES}->{$trgnode}->{cat};
	}
	elsif (exists $trgtree->{NODES}->{$trgnode}->{pos}){
	    $key.=$trgtree->{NODES}->{$trgnode}->{pos};
	}
	$values{$key}=1;
    }

    ## ratio between the number of source language words and 
    ## the number of target language words dominated by the given nodes

    if (exists $todo{nr_leafs_ratio}){
	
	if (@srcleafs && @trgleafs){
	    if ($#srcleafs>$#trgleafs){
		$values{nr_leafs_ratio}=($#trgleafs+1)/($#srcleafs+1);
	    }
	    else{
		$values{nr_leafs_ratio}=($#srcleafs+1)/($#trgleafs+1);
	    }
	}
    }

    ## lower casing if necessary

    if ($self->{-lex_lower}){
	for (0..$#srcleafs){
	    $srcleafs[$_]=lc($srcleafs[$_]);
	}
	for (0..$#trgleafs){
	    $trgleafs[$_]=lc($trgleafs[$_]);
	}
    }

    ## lexical inside scores
    ## -----------------------
    ## insideST1 ...... un-normalized inside score a(s|t)
    ## insideST1 ...... un-normalized inside score a(t|s)
    ## insideST2 ...... normalized inside score a(s|t)
    ## insideST2 ...... normalized inside score a(t|s)

    if (exists $todo{insideST1}){
	$values{insideST1} = 
	    $self->zhechev_scoreXY(\@srcleafs,\@trgleafs,$self->{LEXE2F},0);
    }
    if (exists $todo{insideTS1}){
	$values{insideTS1} = 
	    $self->zhechev_scoreXY(\@trgleafs,\@srcleafs,$self->{LEXF2E},0);
    }

    if (exists $todo{insideST2}){
	$values{insideST2} = 
	    $self->zhechev_scoreXY(\@srcleafs,\@trgleafs,$self->{LEXE2F},1);
    }
    if (exists $todo{insideTS2}){
	$values{insideTS2} = 
	    $self->zhechev_scoreXY(\@trgleafs,\@srcleafs,$self->{LEXF2E},1);
    }


    ## inside scores a la Dublin Tree Aligner
    ## (without normalization)

    if (exists $todo{inside1}){
	my $insideST1;
	if (exists $values{insideST1}){$insideST1=$values{insideST1};}
	else{
	    $insideST1=
		$self->zhechev_scoreXY(\@srcleafs,\@trgleafs,$self->{LEXE2F},0);
	}
	my $insideTS1;
	if (exists $values{insideTS1}){$insideTS1=$values{insideTS1};}
	else{
	    $insideTS1=
		$self->zhechev_scoreXY(\@trgleafs,\@srcleafs,$self->{LEXF2E},0);
	}
	$values{inside1}=$insideST1*$insideTS1;

#	if ($values{inside1} == 0){
#	    print STDERR "0: '";
#	    print STDERR join('-',@srcleafs);
#	    print STDERR "' & '";
#	    print STDERR join('-',@trgleafs);
#	    print STDERR "'\n";
#	}

    }

    ## inside scores a la Dublin Tree Aligner
    ## (with normalization)

    if (exists $todo{inside2}){
	my $insideST2;
	if (exists $values{insideST2}){$insideST2=$values{insideST2};}
	else{
	    $insideST2=
		$self->zhechev_scoreXY(\@srcleafs,\@trgleafs,$self->{LEXE2F},1);
	}
	my $insideTS2;
	if (exists $values{insideTS2}){$insideTS2=$values{insideTS2};}
	else{
	    $insideTS2=
		$self->zhechev_scoreXY(\@trgleafs,\@srcleafs,$self->{LEXF2E},1);
	}
	$values{inside2}=$insideST2*$insideTS2;
    }


    if (exists $todo{joerg_insideST}){
	$values{joerg_insideST} = 
	    $self->joerg_scoreXY(\@srcleafs,\@trgleafs,$self->{LEXE2F});
    }


    ## lexical outside scores
    ## -----------------------
    ## outsideST1 ...... un-normalized outside score a(s|t)
    ## outsideST1 ...... un-normalized outside score a(t|s)
    ## outsideST2 ...... normalized outside score a(s|t)
    ## outsideST2 ...... normalized outside score a(t|s)


    if ((exists $todo{outsideST1}) || 
	(exists $todo{outsideTS1}) ||
	(exists $todo{outside1}) ||
	(exists $todo{outsideST2}) || 
	(exists $todo{outsideTS2}) ||
	(exists $todo{outside2})){

	## get leafs outside of current subtrees
	my @srcout = $self->{TREES}->get_outside_leafs($srctree,$srcnode);
	my @trgout = $self->{TREES}->get_outside_leafs($trgtree,$trgnode);

	## lower casing if necessary

	if ($self->{-lex_lower}){
	    for (0..$#srcout){
		$srcout[$_]=lc($srcout[$_]);
	    }
	    for (0..$#trgout){
		$trgout[$_]=lc($trgout[$_]);
	    }
	}

	if (exists $todo{outsideST1}){
	    $values{outsideST1} = 
		$self->zhechev_scoreXY(\@srcout,\@trgout,$self->{LEXE2F},0);
	}
	if (exists $todo{outsideTS1}){
	    $values{outsideST1} = 
		$self->zhechev_scoreXY(\@trgout,\@srcout,$self->{LEXF2E},0);
	}

	if (exists $todo{outsideST2}){
	    $values{outsideST2} = 
		$self->zhechev_scoreXY(\@srcout,\@trgout,$self->{LEXE2F},1);
	}
	if (exists $todo{outsideTS2}){
	    $values{outsideST2} = 
		$self->zhechev_scoreXY(\@trgout,\@srcout,$self->{LEXF2E},1);
	}


	## outside scores a la Dublin Tree Aligner
	## (without normalization)

	if (exists $todo{outside1}){
	    my $outsideST1;
	    if (exists $values{outsideST1}){$outsideST1=$values{outsideST1};}
	    else{
		$outsideST1=
		    $self->zhechev_scoreXY(\@srcout,\@trgout,$self->{LEXE2F},0);
	    }
	    my $outsideTS1;
	    if (exists $values{outsideTS1}){$outsideTS1=$values{outsideTS1};}
	    else{
		$outsideTS1=
		    $self->zhechev_scoreXY(\@trgout,\@srcout,$self->{LEXF2E},0);
	    }
	    $values{outside1}=$outsideST1*$outsideTS1;
	}

	## outside scores a la Dublin Tree Aligner
	## (wit normalization)

	if (exists $todo{outside2}){
	    my $outsideST2;
	    if (exists $values{outsideST2}){$outsideST2=$values{outsideST2};}
	    else{
		$outsideST2=
		    $self->zhechev_scoreXY(\@srcout,\@trgout,$self->{LEXE2F},1);
	    }
	    my $outsideTS2;
	    if (exists $values{outsideTS2}){$outsideTS2=$values{outsideTS2};}
	    else{
		$outsideTS2=
		    $self->zhechev_scoreXY(\@trgout,\@srcout,$self->{LEXF2E},1);
	    }
	    $values{outside2}=$outsideST2*$outsideTS2;
	}


	if (exists $todo{joerg_outsideST}){
	    $values{joerg_outsideST} = 
		$self->joerg_scoreXY(\@srcout,\@trgout,$self->{LEXE2F});
	}


    }


    ## add features from immediate parents
    ## 1) both, source and target language parent

    my %parent_features=();
    foreach (keys %{$features}){
	if (/parent_(.*)$/){
	    $parent_features{$1}=$features->{$_};
	}
    }
    if (keys %parent_features){
	my $srcparent;
	if (exists $srctree->{NODES}->{$srcnode}->{PARENTS}){
	    $srcparent = $srctree->{NODES}->{$srcnode}->{PARENTS}->[0];
	}
	my $trgparent;
	if (exists $trgtree->{NODES}->{$trgnode}->{PARENTS}){
	    $trgparent = $trgtree->{NODES}->{$trgnode}->{PARENTS}->[0];
	}
	if ((defined $srcparent) && (defined $trgparent)){
	    my %newvalues = $self->get_features($srctree,$trgtree,
						$srcparent,$trgparent,
						\%parent_features);
	    foreach (keys %newvalues){
		$values{'parent_'.$_}=$newvalues{$_};
	    }
	}
    }

    ## 2) source language parent and current target language node

    my %parent_features=();
    foreach (keys %{$features}){
	if (/srcparent_(.*)$/){
	    $parent_features{$1}=$features->{$_};
	}
    }
    if (keys %parent_features){
	my $srcparent;
	if (exists $srctree->{NODES}->{$srcnode}->{PARENTS}){
	    $srcparent = $srctree->{NODES}->{$srcnode}->{PARENTS}->[0];
	}
	if (defined $srcparent){
	    my %newvalues = $self->get_features($srctree,$trgtree,
						$srcparent,$trgnode,
						\%parent_features);
	    foreach (keys %newvalues){
		$values{'srcparent_'.$_}=$newvalues{$_};
	    }
	}
    }


    ## 3) target language parent and current source language node

    my %parent_features=();
    foreach (keys %{$features}){
	if (/trgparent_(.*)$/){
	    $parent_features{$1}=$features->{$_};
	}
    }
    if (keys %parent_features){
	my $trgparent;
	if (exists $trgtree->{NODES}->{$trgnode}->{PARENTS}){
	    $trgparent = $trgtree->{NODES}->{$trgnode}->{PARENTS}->[0];
	}
	if (defined $trgparent){
	    my %newvalues = $self->get_features($srctree,$trgtree,
						$srcnode,$trgparent,
						\%parent_features);
	    foreach (keys %newvalues){
		$values{'trgparent_'.$_}=$newvalues{$_};
	    }
	}
    }




    ## save values in cache
    ## (could be useful if we need features from parents etc ....)

    foreach (keys %values){
	$self->{CACHE}->{$key}->{$_}=$values{$_};
	delete $values{$_} if (not $values{$_});
    }
    


    ## delete features with value = zero
    foreach (keys %values){
	delete $values{$_} if (not $values{$_});
    }


    return %values;	
}


sub zhechev_scoreXY{
    my $self=shift;
    my ($src,$trg,$lex,$normalize)=@_;

    return 0 if (not @{$trg});
    return 0 if (not @{$src});

    my $a=1;
    foreach my $s (@{$src}){
	my $sum=0;

	# if one of the source words does not exist in the lexicon:
	# --> sum(s) is going to be zero
	# --> a(s|t) is going to be zero --> just ignore
	# (or should we return 0?)
	if (not exists($lex->{$s})){
	    print STDERR "no entry in lexicon for $s! --> ignore this word!\n";
	    next;
#	    return 0;
	}

	foreach my $t (@{$trg}){
	    if (exists($lex->{$s})){
		if (exists($lex->{$s}->{$t})){
		    $sum+=$lex->{$s}->{$t};
		}
	    }
	}

	return 0 if (not $sum);  # sum=0? --> immediately stop and return 0

	if ($normalize){
	    $sum/=($#{$trg}+1);  # normalize sum by number of target tokens
	}
	$a*=$sum;                # multiply with previous a(s|t)
    }
    return $a;
}


sub joerg_scoreXY{
    my $self=shift;
    my ($src,$trg,$lex)=@_;

    return 0 if (not @{$trg});
    return 0 if (not @{$src});

    my $score=0;
    foreach my $s (@{$src}){
	next if (not exists($lex->{$s}));
	foreach my $t (@{$trg}){
	    if (exists($lex->{$s})){
		if (exists($lex->{$s}->{$t})){
		    $score+=$lex->{$s}->{$t}-$score*$lex->{$s}->{$t};
		}
	    }
	}
    }
    return $score;
}







##################### OLD OLD OLD OLD OLD ############################

sub load_moses_lex_old{
    my $self=shift;
    return 1 if (exists $self->{LEXE2F});

    my $lexe2f = $self->{-lexe2f} || 'moses/model/lex.0-0.e2f';
    if (-e $lexe2f){
	open F,"<$lexe2f" || die "cannot open lexe2f file $lexe2f\n";

	if (ref($self->{SRCVCB}) ne 'HASH'){$self->{SRCVCB}={};}
	if (ref($self->{TRGVCB}) ne 'HASH'){$self->{TRGVCB}={};}

	$self->{SRCWORDCOUNT}=scalar keys %{$self->{SRCVCB}};
	$self->{TRGWORDCOUNT}=scalar keys %{$self->{TRGVCB}};

	while (<F>){
	    chomp;
	    my ($src,$trg,$score)=split(/\s+/);
	    if (! exists $self->{SRCVCB}->{$src}){
		$self->{SRCWORDCOUNT}++;
		$self->{SRCVCB}->{$src}=$self->{SRCWORDCOUNT};
	    }
	    if (! exists $self->{TRGVCB}->{$trg}){
		$self->{TRGWORDCOUNT}++;
		$self->{TRGVCB}->{$trg}=$self->{TRGWORDCOUNT};
	    }
	    my $sid = $self->{SRCVCB}->{$src};
	    my $tid = $self->{TRGVCB}->{$trg};
#	    $self->{LEXE2F}->{$sid}->{$tid}=$score;
	    $self->{LEXE2F}->{$src}->{$trg}=$score;
	}
	close F;
    }

    my $lexf2e = $self->{-lexf2e} || 'moses/model/lex.f2e';
    if (-e $lexf2e){
	open F,"<$lexf2e" || die "cannot open lexf2e file $lexf2e\n";

	if (ref($self->{SRCVCB}) ne 'HASH'){$self->{SRCVCB}={};}
	if (ref($self->{TRGVCB}) ne 'HASH'){$self->{TRGVCB}={};}

	$self->{SRCWORDCOUNT}=scalar keys %{$self->{SRCVCB}};
	$self->{TRGWORDCOUNT}=scalar keys %{$self->{TRGVCB}};

	while (<F>){
	    chomp;
	    my ($trg,$src,$score)=split(/\s+/);
	    if (! exists $self->{SRCVCB}->{$src}){
		$self->{SRCWORDCOUNT}++;
		$self->{SRCVCB}->{$src}=$self->{SRCWORDCOUNT};
	    }
	    if (! exists $self->{TRGVCB}->{$trg}){
		$self->{TRGWORDCOUNT}++;
		$self->{TRGVCB}->{$trg}=$self->{TRGWORDCOUNT};
	    }
	    my $sid = $self->{SRCVCB}->{$src};
	    my $tid = $self->{TRGVCB}->{$trg};
#	    $self->{LEXF2E}->{$sid}->{$tid}=$score;
	    $self->{LEXF2E}->{$src}->{$trg}=$score;
	}
	close F;
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
