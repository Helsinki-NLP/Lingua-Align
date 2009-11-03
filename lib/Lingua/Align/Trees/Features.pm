package Lingua::Align::Trees::Features;

use 5.005;
use strict;

use vars qw($VERSION @ISA);
@ISA = qw();
$VERSION = '0.01';

use FileHandle;
use Lingua::Align::Corpus::Treebank;
use Lingua::Align::Corpus::Parallel::Giza;
use Lingua::Align::Corpus::Parallel::Moses;

my $DEFAULTFEATURES = 'inside2:outside2';

sub new{
    my $class=shift;
    my %attr=@_;

    my $self={};
    bless $self,$class;

    foreach (keys %attr){
	$self->{$_}=$attr{$_};
    }

    # make a Treebank object for processing trees
    $self->{TREES} = new Lingua::Align::Corpus::Treebank();

    return $self;
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

    ## make a feature type string
    $self->{FEATURE_TYPES_STRING}=join(':',keys %{$self->{FEATURE_TYPES}});
    ## ... which we can use to look for specific requirements:
    ## load moses lexicon if necessary
    if ($self->{FEATURE_TYPES_STRING}=~/(inside|outside)/){
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

	# concatenations
	elsif ($f=~/\./){
	    my @fact = split(/\./,$f);
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

	elsif ($f=~/\./){                    # concatenate nominal features
	    my @fact = split(/\./,$f);
	    my $score=0;
	    my @keys=();
	    foreach my $x (@fact){           # for all factors
		my $found=0;
		foreach my $k (keys %feat){  # check if we have a feature
		    if ($k=~/^$x(\_|\Z)/){   # with this prefix
			push (@keys,$k);     # yes? --> concatenate
			$score+=$feat{$k};   # and add score
			$found=1;
			last;
		    }
		}
		if (not $found){             # nothing found?
		    push (@keys,$x);         # use prefix as key string
		}

	    }
	    if (@keys){
		my $key=join('_',@keys);   # this is the new feature string
		$score/=($#fact+1);        # this is the average score
		$retfeat{$key}=$score;     # (should be 1 for nominal)
	    }
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
		if ($#part){
		    for my $x (0..$#part-1){
			my $key = join('_',@part[0..$x]);
			if (exists $self->{FEATURES}->{$key}){
			    $retfeat{$_}=$feat{$_};
			}
		    }
		}
#		if (exists $self->{FEATURES}->{$part[0]}){
#		    $retfeat{$_}=$feat{$_};
#		}
#		# if combined with 'parent' or something like this
#		if (exists $self->{FEATURES}->{"$part[0]_$part[1]"}){
#		    $retfeat{$_}=$feat{$_};
#		}
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



#-------------------------------------------------------------------
# get values for each feature type
#-------------------------------------------------------------------


sub get_features{
    my $self=shift;
    my ($srctree,$trgtree,$srcnode,$trgnode)=@_;
    my $features = $_[4] || $self->{FEATURE_TYPES};

    my %values=();

    ## check if we have the values stored in cache already
    ## (feature extraction is expensive and we do not want to repeat it
    ##  for the same nodes over and over again)

    my %todo=%{$features};
    my $key = "$srctree->{ID}:$trgtree->{ID}:$srcnode:$trgnode";
    foreach (keys %{$features}){
	if (exists $self->{CACHE}->{$key}->{$_}){
	    $values{$_}=$self->{CACHE}->{$key}->{$_};
	    delete $todo{$_};
	}
    }


    # get features of different types

    $self->tree_features($srctree,$trgtree,$srcnode,$trgnode,\%todo,\%values);
    $self->label_features($srctree,$trgtree,$srcnode,$trgnode,\%todo,\%values);
    $self->lex_features($srctree,$trgtree,$srcnode,$trgnode,\%todo,\%values);
    $self->wordalign_features($srctree,$trgtree,$srcnode,$trgnode,\%todo,\%values);


    ## add features from immediate parents
    ## 1) both, source and target language parent

    my %parent_features=();
    foreach (keys %todo){
	if (/^parent_(.*)$/){
	    $parent_features{$1}=$features->{$_};
	}
    }
    if (keys %parent_features){
	my $srcparent=$self->{TREES}->parent($srctree,$srcnode);
#	if (exists $srctree->{NODES}->{$srcnode}->{PARENTS}){
#	    $srcparent = $srctree->{NODES}->{$srcnode}->{PARENTS}->[0];
#	}
	my $trgparent=$self->{TREES}->parent($trgtree,$trgnode);
#	my $trgparent;
#	if (exists $trgtree->{NODES}->{$trgnode}->{PARENTS}){
#	    $trgparent = $trgtree->{NODES}->{$trgnode}->{PARENTS}->[0];
#	}
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
    foreach (keys %todo){
	if (/^srcparent_(.*)$/){
	    $parent_features{$1}=$features->{$_};
	}
    }
    if (keys %parent_features){
	my $srcparent=$self->{TREES}->parent($srctree,$srcnode);
#	my $srcparent;
#	if (exists $srctree->{NODES}->{$srcnode}->{PARENTS}){
#	    $srcparent = $srctree->{NODES}->{$srcnode}->{PARENTS}->[0];
#	}
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
    foreach (keys %todo){
	if (/^trgparent_(.*)$/){
	    $parent_features{$1}=$features->{$_};
	}
    }
    if (keys %parent_features){
	my $trgparent=$self->{TREES}->parent($trgtree,$trgnode);
#	my $trgparent;
#	if (exists $trgtree->{NODES}->{$trgnode}->{PARENTS}){
#	    $trgparent = $trgtree->{NODES}->{$trgnode}->{PARENTS}->[0];
#	}
	if (defined $trgparent){
	    my %newvalues = $self->get_features($srctree,$trgtree,
						$srcnode,$trgparent,
						\%parent_features);
	    foreach (keys %newvalues){
		$values{'trgparent_'.$_}=$newvalues{$_};
	    }
	}
    }

    ## 4) sister nodes --> (max of) sister node features ...

    my %sister_features=();
    foreach (keys %todo){
	if (/^sister_(.*)$/){
	    $sister_features{$1}=$features->{$_};
	}
    }
    if (keys %sister_features){
	my @srcsisters=$self->{TREES}->sisters($srctree,$srcnode);
	my @trgsisters=$self->{TREES}->sisters($trgtree,$trgnode);

	## get features for all combinations of sister nodes ...
	foreach my $s (@srcsisters){
	    foreach my $t (@trgsisters){
		my %newvalues = $self->get_features($srctree,$trgtree,
						    $s,$t,
						    \%sister_features);
		foreach (keys %newvalues){
		    ## only if not exists or value is bigger!
		    if ($newvalues{$_} > $values{'sister_'.$_}){
			$values{'sister_'.$_}=$newvalues{$_};
		    }
		}
	    }
	}

# 	## get features for all combinations of sister nodes ...
# 	## save for each srcnode the best score with one of the trgnodes
# 	my %newvalues=();
# 	foreach my $s (@srcsisters){
# 	    foreach my $t (@trgsisters){
# 		my %new = $self->get_features($srctree,$trgtree,
# 					      $s,$t,
# 					      \%sister_features);
# 		foreach (keys %new){
# 		    ## only if not exists or value is bigger!
# 		    if ($new{$_} > $newvalues{'sister_'.$_}{$s}){
# 			$newvalues{'sister_'.$_}{$s}=$new{$_};
# 		    }
# 		}
# 	    }
# 	}
# 	## take averages of all features
# 	foreach my $k (keys %newvalues){
# 	    my $count=0;
# 	    foreach my $x (keys %{$newvalues{$k}}){
# 		$values{'sister_'.$k}+=$newvalues{$k}{$x};
# 		$count++;
# 	    }
# 	    $values{'sister_'.$k}/=$count if $count;
# 	}

    }



    ## 5) children nodes --> children node features ...

    my %children_features=();
    foreach (keys %todo){
	if (/^children_(.*)$/){
	    $children_features{$1}=$features->{$_};
	}
    }
    if (keys %children_features){
	my @srcchildren=$self->{TREES}->children($srctree,$srcnode);
	my @trgchildren=$self->{TREES}->children($trgtree,$trgnode);

	## get features for all combinations of sister nodes ...
	foreach my $s (@srcchildren){
	    foreach my $t (@trgchildren){
		my %newvalues = $self->get_features($srctree,$trgtree,
						    $s,$t,
						    \%children_features);
		foreach (keys %newvalues){
		    ## only if not exists or value is bigger!
		    if ($newvalues{$_} > $values{'children_'.$_}){
			$values{'children_'.$_}=$newvalues{$_};
		    }
		}
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
    ## (but it's good to keep them in the cache
    ##  as we might have to look for them again)
    foreach (keys %values){
	delete $values{$_} if (not $values{$_});
    }

    return %values;	
}






#-------------------------------------------------------------------
# sub routines for the different feature types 
# (this is time consuming and should be optimized!?)


sub label_features{
    my $self=shift;
    my ($srctree,$trgtree,$srcnode,$trgnode,$FeatTypes,$values)=@_;

    ## category or POS pair

    if (exists $$FeatTypes{catpos}){
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
	$$values{$key}=1;
    }

    # edge labels
    # (relation to (first) parent) 

    if (exists $$FeatTypes{edge}){
	my $key='edge_';
	if (exists $srctree->{NODES}->{$srcnode}->{RELATION}){
	    if (ref($srctree->{NODES}->{$srcnode}->{RELATION}) eq 'ARRAY'){
		$key.=$srctree->{NODES}->{$srcnode}->{RELATION}->[0];
	    }
	}
	$key.='_';
	if (exists $trgtree->{NODES}->{$trgnode}->{RELATION}){
	    if (ref($trgtree->{NODES}->{$trgnode}->{RELATION}) eq 'ARRAY'){
		$key.=$trgtree->{NODES}->{$trgnode}->{RELATION}->[0];
	    }
	}
	$$values{$key}=1;
    }


}


sub tree_features{
    my $self=shift;
    my ($srctree,$trgtree,         # entire parse tree (source & target)
	$srcnode,$trgnode,         # current tree nodes
	$FeatTypes,$values)=@_;    # feature types to be returned in values

    ## tree span similarity:
    ## take the middle of each subtree-span and 
    ## compute the relative closeness of these positions

    if (exists $$FeatTypes{treespansim}){
	my $srclength=scalar @{$srctree->{TERMINALS}};
	my $trglength=scalar @{$trgtree->{TERMINALS}};
	my ($srcstart,$srcend)=$self->{TREES}->subtree_span($srctree,$srcnode);
	my ($trgstart,$trgend)=$self->{TREES}->subtree_span($trgtree,$trgnode);
	$$values{treespansim}=
	    1-abs(($srcstart+$srcend)/(2*$srclength)-
		  ($trgstart+$trgend)/(2*$trglength));
    }

    ## tree-level similarity:
    ## similarity of relatie tree levels of given nodes
    ## (tree-level = distance from root)

    if (exists $$FeatTypes{treelevelsim}){
	my $dist1=$self->{TREES}->distance_to_root($srctree,$srcnode);
	my $size1=$self->{TREES}->tree_size($srctree);
	my $dist2=$self->{TREES}->distance_to_root($trgtree,$trgnode);
	my $size2=$self->{TREES}->tree_size($trgtree);
	my $diff=abs($dist1/$size1-$dist2/$size2);
	$$values{treelevelsim}=1-$diff;
    }

    ## ratio between the number of source language words and 
    ## the number of target language words dominated by the given nodes

    if (exists $$FeatTypes{nrleafsratio}){

	my @srcleafs = $self->{TREES}->get_leafs($srctree,$srcnode);
	my @trgleafs = $self->{TREES}->get_leafs($trgtree,$trgnode);

	if (@srcleafs && @trgleafs){
	    if ($#srcleafs>$#trgleafs){
		$$values{nrleafsratio}=($#trgleafs+1)/($#srcleafs+1);
	    }
	    else{
		$$values{nrleafsratio}=($#srcleafs+1)/($#trgleafs+1);
	    }
	}
    }
}



## word alignment features from GIZA++ word alignments

sub wordalign_features{
    my $self=shift;
    my ($src,$trg,$srcN,$trgN,$FeatTypes,$values)=@_;

    my ($insideEF,$outsideEF);
    my ($insideFE,$outsideFE);

    # Moses links (GIZA++ Viterbi after symmetrization)
    # feature = proportion of inside links
    if ((exists $$FeatTypes{moses}) || (exists $$FeatTypes{moseslink})){
	($insideEF,$outsideEF) = $self->moses_links($src,$trg,$srcN,$trgN);
	if (exists $$FeatTypes{moses}){
	    if ($insideEF || $outsideEF){
		$$values{moses} = $insideEF/($insideEF+$outsideEF);
	    }
	}

	# moseslink = 1 if srcN and trgN are aligned terminal nodes
	if (exists $$FeatTypes{moseslink}){
	    if ($insideEF && 
		$self->{TREES}->is_terminal($src,$srcN) && 
		$self->{TREES}->is_terminal($trg,$trgN)){
		$$values{moseslink}=1;
	    }
	}
    }

    # GIZA++ features
    if ((exists $$FeatTypes{gizae2f}) || (exists $$FeatTypes{giza})){
	($insideEF,$outsideEF) = $self->gizae2f($src,$trg,$srcN,$trgN);
#	($insideEF,$outsideEF) = $self->gizae2f($trg,$src,$trgN,$srcN);
    }
    if ((exists $$FeatTypes{gizaf2e}) || (exists $$FeatTypes{giza})){
	($insideFE,$outsideFE) = $self->gizaf2e($src,$trg,$srcN,$trgN);
    }

    # proportion of inside links (src->trg)
    if (exists $$FeatTypes{gizae2f}){
	if ($insideEF || $outsideEF){
	    $$values{gizae2f} = $insideEF/($insideEF+$outsideEF);
	}
    }

    # proportion of inside links (trg->src)
    if (exists $$FeatTypes{gizaf2e}){
	if ($insideFE || $outsideFE){
	    $$values{gizaf2e} = $insideFE/($insideFE+$outsideFE);
	}
    }

    # proportion of inside links (src->trg & trg->src combined)
    if (exists $$FeatTypes{giza}){
	if ($insideEF || $outsideEF || $insideFE || $outsideFE){
	    $$values{giza} = ($insideEF+$insideFE)/
		($insideEF+$insideFE+$outsideEF+$outsideFE);
	}
    }

}




sub gizae2f{
    my $self=shift;
    my ($src,$trg,$srcN,$trgN)=@_;

    if ($src->{ID} ne $self->{LASTGIZA_SRC_ID}){
	$self->{LASTGIZA_SRC_ID} = $src->{ID};
	$self->read_next_giza_links($src,$trg,'GIZA_E2F',
				    $self->{-gizaA3_e2f},
				    $self->{-gizaA3_e2f_encoding},
				    $self->{-gizaA3_e2f_ids});
    }

    # get leaf nodes dominated by the given node in the tree

    my @srcleafs = $self->{TREES}->get_leafs($src,$srcN,'id');
    my @trgleafs = $self->{TREES}->get_leafs($trg,$trgN,'id');

    my %srcLeafIDs=();
    foreach (@srcleafs){$srcLeafIDs{$_}=1;}
    my %trgLeafIDs=();
    foreach (@trgleafs){$trgLeafIDs{$_}=1;}

    my $inside=0;
    my $outside=0;

    foreach my $s (@srcleafs){
	foreach my $t (keys %{$self->{GIZA_E2F}->{S2T}->{$s}}){
	    if (exists $trgLeafIDs{$t}){
		$inside++;
	    }
	    else{$outside++;}
	}
    }

    foreach my $t (@trgleafs){
	foreach my $s (keys %{$self->{GIZA_E2F}->{T2S}->{$t}}){
	    if (exists $srcLeafIDs{$s}){
		$inside++;
	    }
	    else{$outside++;}
	}
    }

    return ($inside,$outside);

}



sub gizaf2e{
    my $self=shift;
    my ($src,$trg,$srcN,$trgN)=@_;

    if ($trg->{ID} ne $self->{LASTGIZA_TRG_ID}){
	$self->{LASTGIZA_TRG_ID} = $trg->{ID};
	$self->read_next_giza_links($src,$trg,'GIZA_F2E',
				    $self->{-gizaA3_f2e},
				    $self->{-gizaA3_f2e_encoding},
				    $self->{-gizaA3_f2e_ids});
    }

    # get leaf nodes dominated by the given node in the tree

    my @srcleafs = $self->{TREES}->get_leafs($src,$srcN,'id');
    my @trgleafs = $self->{TREES}->get_leafs($trg,$trgN,'id');

    my %srcLeafIDs=();
    foreach (@srcleafs){$srcLeafIDs{$_}=1;}
    my %trgLeafIDs=();
    foreach (@trgleafs){$trgLeafIDs{$_}=1;}

    my $inside=0;
    my $outside=0;

    foreach my $s (@srcleafs){
	foreach my $t (keys %{$self->{GIZA_F2E}->{T2S}->{$s}}){
	    if (exists $trgLeafIDs{$t}){
		$inside++;
	    }
	    else{$outside++;}
	}
    }

    foreach my $t (@trgleafs){
	foreach my $s (keys %{$self->{GIZA_F2E}->{S2T}->{$t}}){
	    if (exists $srcLeafIDs{$s}){
		$inside++;
	    }
	    else{$outside++;}
	}
    }

    return ($inside,$outside);

}


sub read_next_giza_links{
    my $self=shift;
    my ($src,$trg,$key,$file,$encoding,$idfile)=@_;

    if (not exists $self->{$key}){
	$self->{$key} = new Lingua::Align::Corpus::Parallel::Giza(
				 -alignfile => $file,
				 -encoding => $encoding,
				 -sent_id_file => $idfile);
    }

    my @srcwords=();
    my @trgwords=();
    my %wordlinks=();
    my @ids=();

    # read GIZA++ Viterbi word alignment for next sentence pair
    # (check IDs if there is an ID file to do that!)
    do {
	@srcwords=();
	@trgwords=();
	%wordlinks=();
	@ids=();
	if (not $self->{$key}->next_alignment(\@srcwords,\@trgwords,
					      \%wordlinks,
					      undef,undef,\@ids)){
	    if ($self->{-verbose}){
		print STDERR "reached EOF (looking for $$src{ID}:$$trg{ID})\n";
	    }
	    return 0;
	}

	if (($$src{ID}<$ids[0]) || ($$trg{ID}<$ids[1])){
	    if ($self->{-verbose}>1){
		print STDERR "gone too far? (looking for $$src{ID}:$$trg{ID}";
		print STDERR " - found ($ids[0]:$ids[1])\n";
	    }
	    $self->{$key}->add_to_buffer(\@srcwords,\@trgwords,
					 \%wordlinks,\@ids);
	    # I just assume that IDs are ordered --> do not try to read further
	    return 0;
	}

	if ($self->{-verbose}>1){
	    if (@ids){
		if (($$src{ID} ne $ids[0]) || ($$trg{ID} ne $ids[1])){
		    print STDERR "skip this GIZA++ alignment!";
		    print STDERR " ($$src{ID}/$ids[0] $$trg{ID}/$ids[1])\n";
		}
	    }
	}
    }
    until ((not defined $ids[0]) || 
	   (($$src{ID} eq $ids[0]) && ($$trg{ID} eq $ids[1])));

    # get terminal node IDs

    my @srcids = @{$src->{TERMINALS}};
    my @trgids = @{$trg->{TERMINALS}};

    # make the mapping from word position to ID

    my %srcPos2ID=();
    foreach (0..$#srcids){
	my $pos=$_+1;
	$srcPos2ID{$pos}=$srcids[$_];
    }
    my %trgPos2ID=();
    foreach (0..$#trgids){
	my $pos=$_+1;
	$trgPos2ID{$pos}=$trgids[$_];
    }

    # save word links with node IDs

    $self->{$key}->{S2T} = {};
    $self->{$key}->{T2S} = {};

    foreach my $s (keys %wordlinks){
	my $sid = $srcPos2ID{$s};
	my $tid = $trgPos2ID{$wordlinks{$s}};
	$self->{$key}->{S2T}->{$sid}->{$tid}=1;
	$self->{$key}->{T2S}->{$tid}->{$sid}=1;
    }
}




sub moses_links{
    my $self=shift;
    my ($src,$trg,$srcN,$trgN)=@_;

    if ($src->{ID} ne $self->{LASTMOSES_SRC_ID}){
	$self->{LASTMOSES_SRC_ID} = $src->{ID};
	$self->read_next_moses_links($src,$trg,'MOSES',
				     $self->{-moses_align},
				     $self->{-moses_align_encoding},
				     $self->{-moses_align_ids});
    }

    # get leaf nodes dominated by the given node in the tree

    my @srcleafs = $self->{TREES}->get_leafs($src,$srcN,'id');
    my @trgleafs = $self->{TREES}->get_leafs($trg,$trgN,'id');

    my %srcLeafIDs=();
    foreach (@srcleafs){$srcLeafIDs{$_}=1;}
    my %trgLeafIDs=();
    foreach (@trgleafs){$trgLeafIDs{$_}=1;}

    my $inside=0;
    my $outside=0;

    foreach my $s (@srcleafs){
	foreach my $t (keys %{$self->{MOSES}->{S2T}->{$s}}){
	    if (exists $trgLeafIDs{$t}){
		$inside++;
	    }
	    else{$outside++;}
	}
    }

    foreach my $t (@trgleafs){
	foreach my $s (keys %{$self->{MOSES}->{T2S}->{$t}}){
	    if (exists $srcLeafIDs{$s}){
		$inside++;
	    }
	    else{$outside++;}
	}
    }

    return ($inside,$outside);

}



sub read_next_moses_links{
    my $self=shift;
    my ($src,$trg,$key,$file,$encoding,$idfile)=@_;

    if (not exists $self->{$key}){
	$self->{$key} = new Lingua::Align::Corpus::Parallel::Moses(
				 -alignfile => $file,
				 -encoding => $encoding,
                                 -sent_id_file => $idfile);
    }

    my @srcwords=();
    my @trgwords=();
    my %wordlinks=();
    my @ids=();

    $self->{$key}->{S2T} = {};
    $self->{$key}->{T2S} = {};

    # read Moses word alignment for next sentence pair
    # (check IDs if there is an ID file to do that!)
    do {
	@srcwords=();
	@trgwords=();
	%wordlinks=();
	@ids=();
	if (not $self->{$key}->next_alignment(\@srcwords,\@trgwords,
					      \%wordlinks,
					      undef,undef,\@ids)){
	    if ($self->{-verbose}){
		print STDERR "reached EOF (looking for $$src{ID}:$$trg{ID})\n";
	    }
	    return 0;
	    
	}

	if (($$src{ID}<$ids[0]) || ($$trg{ID}<$ids[1])){
	    if ($self->{-verbose}>1){
		print STDERR "gone too far? (looking for $$src{ID}:$$trg{ID}";
		print STDERR " - found ($ids[0]:$ids[1])\n";
	    }
	    $self->{$key}->add_to_buffer(\@srcwords,\@trgwords,
					 \%wordlinks,\@ids);
	    # I just assume that IDs are ordered --> do not try to read further
	    return 0;
	}

	if ($self->{-verbose}>1){
	    if (@ids){
		if (($$src{ID} ne $ids[0]) || ($$trg{ID} ne $ids[1])){
		    print STDERR "skip this MOSES alignment!";
		    print STDERR "($$src{ID}/$ids[0] $$trg{ID}/$ids[1])\n";
		}
	    }
	}
    }
    until ((not defined $ids[0]) || 
	   (($$src{ID} eq $ids[0]) && ($$trg{ID} eq $ids[1])));

    # get terminal node IDs

    my @srcids = @{$src->{TERMINALS}};
    my @trgids = @{$trg->{TERMINALS}};

    # make the mapping from word position to ID

    my %srcPos2ID=();
    foreach (0..$#srcids){
	my $pos=$_;
	$srcPos2ID{$pos}=$srcids[$_];
    }
    my %trgPos2ID=();
    foreach (0..$#trgids){
	my $pos=$_;
	$trgPos2ID{$pos}=$trgids[$_];
    }

    # save word links with node IDs

    foreach my $s (keys %wordlinks){
	my $sid = $srcPos2ID{$s};
	foreach my $t (keys %{$wordlinks{$s}}){
	    my $tid = $trgPos2ID{$t};
	    $self->{$key}->{S2T}->{$sid}->{$tid}=1;
	    $self->{$key}->{T2S}->{$tid}->{$sid}=1;
	}
    }
    return 1;
}












## lexical features using lexical model of Moses

sub lex_features{
    my $self=shift;
    my ($src,$trg,$srcN,$trgN,$FeatTypes,$values)=@_;
    $self->lex_inside_features($src,$trg,$srcN,$trgN,$FeatTypes,$values);
    $self->lex_outside_features($src,$trg,$srcN,$trgN,$FeatTypes,$values);
}


sub lex_inside_features{
    my $self=shift;
    my ($srctree,$trgtree,         # entire parse tree (source & target)
	$srcnode,$trgnode,         # current tree nodes
	$FeatTypes,$values)=@_;    # feature types to be returned in values


    # do nothing if we don't need inside features
    return 0 if ($self->{FEATURE_TYPES_STRING}!~/inside/);


    # get leaf nodes dominated by the given node in the tree

    my @srcleafs = $self->{TREES}->get_leafs($srctree,$srcnode);
    my @trgleafs = $self->{TREES}->get_leafs($trgtree,$trgnode);

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
    ## ----------------------------------------
    ## original Dublin Subtree aligner scores
    ## ----------------------------------------
    ## insideST1 ...... un-normalized inside score a(s|t)
    ## insideST1 ...... un-normalized inside score a(t|s)
    ## insideST2 ...... normalized inside score a(s|t)
    ## insideST2 ...... normalized inside score a(t|s)
    ## ----------------------------------------
    ## the same without considering NULL links
    ## ----------------------------------------
    ## insideST3 ...... un-normalized inside score a(s|t)
    ## insideST3 ...... un-normalized inside score a(t|s)
    ## insideST4 ...... normalized inside score a(s|t)
    ## insideST4 ...... normalized inside score a(t|s)


    if (exists $$FeatTypes{insideST1}){
	$$values{insideST1} = 
	    $self->zhechev_scoreXY_NULL(\@srcleafs,\@trgleafs,
				   $self->{LEXE2F},$self->{LEXF2E},0);
    }
    if (exists $$FeatTypes{insideTS1}){
	$$values{insideTS1} = 
	    $self->zhechev_scoreXY_NULL(\@trgleafs,\@srcleafs,
				   $self->{LEXF2E},$self->{LEXE2F},0);
    }

    if (exists $$FeatTypes{insideST2}){
	$$values{insideST2} = 
	    $self->zhechev_scoreXY_NULL(\@srcleafs,\@trgleafs,
				   $self->{LEXE2F},$self->{LEXF2E},1);
    }
    if (exists $$FeatTypes{insideTS2}){
	$$values{insideTS2} = 
	    $self->zhechev_scoreXY_NULL(\@trgleafs,\@srcleafs,
				   $self->{LEXF2E},$self->{LEXE2F},1);
    }

    ## without NULL links

    if (exists $$FeatTypes{insideST3}){
	$$values{insideST3} = 
	    $self->zhechev_scoreXY(\@srcleafs,\@trgleafs,
				   $self->{LEXE2F},$self->{LEXF2E},0);
    }
    if (exists $$FeatTypes{insideTS3}){
	$$values{insideTS3} = 
	    $self->zhechev_scoreXY(\@trgleafs,\@srcleafs,
				   $self->{LEXF2E},$self->{LEXE2F},0);
    }

    if (exists $$FeatTypes{insideST4}){
	$$values{insideST4} = 
	    $self->zhechev_scoreXY(\@srcleafs,\@trgleafs,
				   $self->{LEXE2F},$self->{LEXF2E},1);
    }
    if (exists $$FeatTypes{insideTS4}){
	$$values{insideTS4} = 
	    $self->zhechev_scoreXY(\@trgleafs,\@srcleafs,
				   $self->{LEXF2E},$self->{LEXE2F},1);
    }


    ## combine src-trg and trg-src as in the 
    ## Dublin Tree Aligner (without normalization)

    if (exists $$FeatTypes{inside1}){
	my $insideST1;
	if (exists $$values{insideST1}){$insideST1=$$values{insideST1};}
	else{
	    $insideST1= $self->zhechev_scoreXY_NULL(\@srcleafs,\@trgleafs,
				       $self->{LEXE2F},$self->{LEXF2E},0);
	}
	my $insideTS1;
	if (exists $$values{insideTS1}){$insideTS1=$$values{insideTS1};}
	else{
	    $insideTS1=	$self->zhechev_scoreXY_NULL(\@trgleafs,\@srcleafs,
				       $self->{LEXF2E},$self->{LEXE2F},0);
	}
	$$values{inside1}=$insideST1*$insideTS1;

    }

    ## (with normalization)

    if (exists $$FeatTypes{inside2}){
	my $insideST2;
	if (exists $$values{insideST2}){$insideST2=$$values{insideST2};}
	else{
	    $insideST2=	$self->zhechev_scoreXY_NULL(\@srcleafs,\@trgleafs,
				       $self->{LEXE2F},$self->{LEXF2E},1);
	}
	my $insideTS2;
	if (exists $$values{insideTS2}){$insideTS2=$$values{insideTS2};}
	else{
	    $insideTS2=	$self->zhechev_scoreXY_NULL(\@trgleafs,\@srcleafs,
				       $self->{LEXF2E},$self->{LEXE2F},1);
	}
	$$values{inside2}=$insideST2*$insideTS2;
#	$$values{inside2}=$insideST2+$insideTS2;
    }


    ## -------------------------------------------
    ## now with the scores without NULL links

    if (exists $$FeatTypes{inside3}){
	my $insideST3;
	if (exists $$values{insideST3}){$insideST3=$$values{insideST3};}
	else{
	    $insideST3= $self->zhechev_scoreXY(\@srcleafs,\@trgleafs,
				       $self->{LEXE2F},$self->{LEXF2E},0);
	}
	my $insideTS3;
	if (exists $$values{insideTS3}){$insideTS3=$$values{insideTS3};}
	else{
	    $insideTS3=	$self->zhechev_scoreXY_NULL(\@trgleafs,\@srcleafs,
				       $self->{LEXF2E},$self->{LEXE2F},0);
	}
	$$values{inside3}=$insideST3*$insideTS3;
    }

    ## (with normalization)

    if (exists $$FeatTypes{inside4}){
	my $insideST4;
	if (exists $$values{insideST4}){$insideST4=$$values{insideST4};}
	else{
	    $insideST4=	$self->zhechev_scoreXY(\@srcleafs,\@trgleafs,
				       $self->{LEXE2F},$self->{LEXF2E},1);
	}
	my $insideTS4;
	if (exists $$values{insideTS2}){$insideTS4=$$values{insideTS4};}
	else{
	    $insideTS4=	$self->zhechev_scoreXY(\@trgleafs,\@srcleafs,
				       $self->{LEXF2E},$self->{LEXE2F},1);
	}
	$$values{inside4}=$insideST4*$insideTS4;
    }




    ## alterantive definition of inside scores:
    ## use max instead of averaged sum!


    if (exists $$FeatTypes{maxinsideST}){
	$$values{maxinsideST} = 
	    $self->maxscoreXY(\@srcleafs,\@trgleafs,$self->{LEXE2F});
    }
    if (exists $$FeatTypes{maxinsideTS}){
	$$values{maxinsideTS} = 
	    $self->maxscoreXY(\@trgleafs,\@srcleafs,$self->{LEXF2E});
    }


    if (exists $$FeatTypes{maxinside}){

	my $ST;
	if (exists $$values{maxinsideST}){$ST=$$values{maxinsideST};}
	else{$ST=$self->maxscoreXY(\@srcleafs,\@trgleafs,$self->{LEXE2F});}

	my $TS;
	if (exists $$values{maxinsideTS}){$TS=$$values{maxinsideTS};}
	else{$TS=$self->maxscoreXY(\@trgleafs,\@srcleafs,$self->{LEXF2E});}

	$$values{maxinside}=$ST*$TS;
    }



    ## yet another alterantive definition of inside scores:
    ## use max instead of averaged sum &
    ## compute average instead of multiplying prob's

    if (exists $$FeatTypes{avgmaxinsideST}){
	$$values{avgmaxinsideST} = 
	    $self->avgmaxscoreXY(\@srcleafs,\@trgleafs,$self->{LEXE2F});
    }
    if (exists $$FeatTypes{avgmaxinsideTS}){
	$$values{avgmaxinsideTS} = 
	    $self->avgmaxscoreXY(\@trgleafs,\@srcleafs,$self->{LEXF2E});
    }


    if (exists $$FeatTypes{avgmaxinside}){

	my $ST;
	if (exists $$values{avgmaxinsideST}){$ST=$$values{avgmaxinsideST};}
	else{$ST=$self->avgmaxscoreXY(\@srcleafs,\@trgleafs,$self->{LEXE2F});}

	my $TS;
	if (exists $$values{avgmaxinsideTS}){$TS=$$values{avgmaxinsideTS};}
	else{$TS=$self->avgmaxscoreXY(\@trgleafs,\@srcleafs,$self->{LEXF2E});}

	$$values{avgmaxinside}=$ST*$TS;
    }


    ## finally: another definition
    ## union of all prob's (is that justifyable?)

    if (exists $$FeatTypes{unioninsideST}){
	$$values{unioninsideST} = 
	    $self->unionscoreXY(\@srcleafs,\@trgleafs,$self->{LEXE2F});
    }
    if (exists $$FeatTypes{unioninsideTS}){
	$$values{unioninsideTS} = 
	    $self->unionscoreXY(\@trgleafs,\@srcleafs,$self->{LEXF2E});
    }

    if (exists $$FeatTypes{unioninside}){
	my $ST;
	if (exists $$values{unioninsideST}){$ST=$$values{unioninsideST};}
	else{$ST=$self->unionscoreXY(\@srcleafs,\@trgleafs,$self->{LEXE2F});}

	my $TS;
	if (exists $$values{unioninsideTS}){$TS=$$values{unioninsideTS};}
	else{$TS=$self->unionscoreXY(\@trgleafs,\@srcleafs,$self->{LEXF2E});}

	$$values{unioninside}=$ST*$TS;
    }



}

sub lex_outside_features{
    my $self=shift;
    my ($srctree,$trgtree,         # entire parse tree (source & target)
	$srcnode,$trgnode,         # current tree nodes
	$FeatTypes,$values)=@_;    # feature types to be returned in values


    # do nothing if we don't need outside features
    return 0 if ($self->{FEATURE_TYPES_STRING}!~/outside/);


    ## lexical outside scores
    ## -----------------------
    ## similar as for the inside scores but for outside words

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

    if (exists $$FeatTypes{outsideST1}){
	$$values{outsideST1} = $self->zhechev_scoreXY_NULL(\@srcout,\@trgout,
				   $self->{LEXE2F},$self->{LEXF2E},0);
    }
    if (exists $$FeatTypes{outsideTS1}){
	$$values{outsideST1} = $self->zhechev_scoreXY_NULL(\@trgout,\@srcout,
				   $self->{LEXF2E},$self->{LEXE2F},0);
    }

    if (exists $$FeatTypes{outsideST2}){
	$$values{outsideST2} = $self->zhechev_scoreXY_NULL(\@srcout,\@trgout,
				   $self->{LEXE2F},$self->{LEXF2E},1);
    }
    if (exists $$FeatTypes{outsideTS2}){
	$$values{outsideTS2} = $self->zhechev_scoreXY_NULL(\@trgout,\@srcout,
				   $self->{LEXF2E},$self->{LEXE2F},1);
    }


    ## without NULL links

    if (exists $$FeatTypes{outsideST3}){
	$$values{outsideST3} = $self->zhechev_scoreXY(\@srcout,\@trgout,
				   $self->{LEXE2F},$self->{LEXF2E},0);
    }
    if (exists $$FeatTypes{outsideTS3}){
	$$values{outsideST3} = $self->zhechev_scoreXY(\@trgout,\@srcout,
				   $self->{LEXF2E},$self->{LEXE2F},0);
    }

    if (exists $$FeatTypes{outsideST4}){
	$$values{outsideST4} = $self->zhechev_scoreXY(\@srcout,\@trgout,
				   $self->{LEXE2F},$self->{LEXF2E},1);
    }
    if (exists $$FeatTypes{outsideTS4}){
	$$values{outsideTS4} = $self->zhechev_scoreXY(\@trgout,\@srcout,
				   $self->{LEXF2E},$self->{LEXE2F},1);
    }



    ## outside scores a la Dublin Tree Aligner
    ## (without normalization)

    if (exists $$FeatTypes{outside1}){
	my $outsideST1;
	if (exists $$values{outsideST1}){$outsideST1=$$values{outsideST1};}
	else{
	    $outsideST1= $self->zhechev_scoreXY(\@srcout,\@trgout,
				       $self->{LEXE2F},$self->{LEXF2E},0);
	}
	my $outsideTS1;
	if (exists $$values{outsideTS1}){$outsideTS1=$$values{outsideTS1};}
	else{
	    $outsideTS1=$self->zhechev_scoreXY(\@trgout,\@srcout,
				       $self->{LEXF2E},$self->{LEXE2F},0);
	}
	$$values{outside1}=$outsideST1*$outsideTS1;
    }

    ## outside scores a la Dublin Tree Aligner
    ## (with normalization)

    if (exists $$FeatTypes{outside2}){
	my $outsideST2;
	if (exists $$values{outsideST2}){$outsideST2=$$values{outsideST2};}
	else{
	    $outsideST2= $self->zhechev_scoreXY_NULL(\@srcout,\@trgout,
				       $self->{LEXE2F},$self->{LEXF2E},1);
	}
	my $outsideTS2;
	if (exists $$values{outsideTS2}){$outsideTS2=$$values{outsideTS2};}
	else{
	    $outsideTS2= $self->zhechev_scoreXY_NULL(\@trgout,\@srcout,
				       $self->{LEXF2E},$self->{LEXE2F},1);
	}
	$$values{outside2}=$outsideST2*$outsideTS2;


# 	if ($$values{outside2}){

# 	    my @srcleafs = $self->{TREES}->get_leafs($srctree,$srcnode);
# 	    my @trgleafs = $self->{TREES}->get_leafs($trgtree,$trgnode);

# 	    print STDERR "inside: src = ";
# 	    print STDERR join(' ',@srcleafs);
# 	    print STDERR "\ninside: trg = ";
# 	    print STDERR join(' ',@trgleafs);
# 	    print STDERR "\n-----------$$values{inside2}------------------\n";

# 	    print STDERR "outside: src = ";
# 	    print STDERR join(' ',@srcout);
# 	    print STDERR "\noutside: trg = ";
# 	    print STDERR join(' ',@trgout);
# 	    print STDERR "\n-----------$$values{outside2}------------------\n";
# 	}

    }




    ## outside scores a la Dublin Tree Aligner
    ## (without normalization)

    if (exists $$FeatTypes{outside3}){
	my $outsideST3;
	if (exists $$values{outsideST3}){$outsideST3=$$values{outsideST3};}
	else{
	    $outsideST3= $self->zhechev_scoreXY(\@srcout,\@trgout,
				       $self->{LEXE2F},$self->{LEXF2E},0);
	}
	my $outsideTS3;
	if (exists $$values{outsideTS1}){$outsideTS3=$$values{outsideTS1};}
	else{
	    $outsideTS3=$self->zhechev_scoreXY(\@trgout,\@srcout,
				       $self->{LEXF2E},$self->{LEXE2F},0);
	}
	$$values{outside3}=$outsideST3*$outsideTS3;
    }

    ## outside scores a la Dublin Tree Aligner
    ## (with normalization)

    if (exists $$FeatTypes{outside4}){
	my $outsideST4;
	if (exists $$values{outsideST4}){$outsideST4=$$values{outsideST4};}
	else{
	    $outsideST4= $self->zhechev_scoreXY(\@srcout,\@trgout,
				       $self->{LEXE2F},$self->{LEXF2E},1);
	}
	my $outsideTS4;
	if (exists $$values{outsideTS4}){$outsideTS4=$$values{outsideTS4};}
	else{
	    $outsideTS4= $self->zhechev_scoreXY(\@trgout,\@srcout,
				       $self->{LEXF2E},$self->{LEXE2F},1);
	}
	$$values{outside4}=$outsideST4*$outsideTS4;

    }



    ## union of prob's


    if (exists $$FeatTypes{unionoutsideST}){
	$$values{unionoutsideST} = 
	    $self->unionscoreXY(\@srcout,\@trgout,$self->{LEXE2F});
    }
    if (exists $$FeatTypes{unionoutsideTS}){
	$$values{unionoutsideTS} = 
	    $self->unionscoreXY(\@trgout,\@srcout,$self->{LEXF2E});
    }


    if (exists $$FeatTypes{unionoutside}){

	my $ST;
	if (exists $$values{unionoutsideST}){$ST=$$values{unionoutsideST};}
	else{$ST=$self->unionscoreXY(\@srcout,\@trgout,$self->{LEXE2F});}

	my $TS;
	if (exists $$values{unionoutsideTS}){$TS=$$values{unionoutsideTS};}
	else{$TS=$self->unionscoreXY(\@trgout,\@srcout,$self->{LEXF2E});}

	$$values{unionoutside}=$ST*$TS;
    }

    if (exists $$FeatTypes{maxoutsideST}){
	$$values{maxoutsideST} = 
	    $self->maxscoreXY(\@srcout,\@trgout,$self->{LEXE2F});
    }
    if (exists $$FeatTypes{maxoutsideTS}){
	$$values{maxoutsideTS} = 
	    $self->maxscoreXY(\@trgout,\@srcout,$self->{LEXF2E});
    }


    ## max instead of average


    if (exists $$FeatTypes{maxoutside}){

	my $ST;
	if (exists $$values{maxoutsideST}){$ST=$$values{maxoutsideST};}
	else{$ST=$self->maxscoreXY(\@srcout,\@trgout,$self->{LEXE2F});}

	my $TS;
	if (exists $$values{maxoutsideTS}){$TS=$$values{maxoutsideTS};}
	else{$TS=$self->maxscoreXY(\@trgout,\@srcout,$self->{LEXF2E});}

	$$values{maxoutside}=$ST*$TS;
    }

    if (exists $$FeatTypes{avgmaxoutsideST}){
	$$values{avgmaxoutsideST} = 
	    $self->avgmaxscoreXY(\@srcout,\@trgout,$self->{LEXE2F});
    }
    if (exists $$FeatTypes{avgmaxoutsideTS}){
	$$values{avgmaxoutsideTS} = 
	    $self->avgmaxscoreXY(\@trgout,\@srcout,$self->{LEXF2E});
    }


    # average instead of product

    if (exists $$FeatTypes{avgmaxoutside}){

	my $ST;
	if (exists $$values{avgmaxoutsideST}){$ST=$$values{avgmaxoutsideST};}
	else{$ST=$self->avgmaxscoreXY(\@srcout,\@trgout,$self->{LEXE2F});}

	my $TS;
	if (exists $$values{avgmaxoutsideTS}){$TS=$$values{avgmaxoutsideTS};}
	else{$TS=$self->avgmaxscoreXY(\@trgout,\@srcout,$self->{LEXF2E});}

	$$values{avgmaxoutside}=$ST*$TS;
    }


}



## this is the implementation of the original Dublin Subtree aligner scores
## (including NULL links)

sub zhechev_scoreXY_NULL{
    my $self=shift;
    my ($src,$trg,$lex,$invlex,$normalize)=@_;

    return 1 if ((not @{$src}) && (not @{$trg}));

#    print STDERR join(' ',@{$src});
#    print STDERR "\n";
#    print STDERR join(' ',@{$trg});
#    print STDERR "\n--------------------------------\n";

    my @SRC=@{$src};
    my @TRG=@{$trg};
    push (@SRC,'NULL');      # add NULL words!
    push (@TRG,'NULL');      # on both sides

#    return 0 if (not @{$trg});
#    return 0 if (not @{$src});

    my $a=1;
    foreach my $s (@SRC){
	my $sum=0;

	# if one of the source words does not exist in the lexicon:
	# --> sum(s) is going to be zero
	# --> a(s|t) is going to be zero --> just ignore
	# (or should we return 0?)
	if (not exists($lex->{$s})){
	    if ($self->{-verbose}>1){
		print STDERR "no entry in lexicon for $s! --> ignore!\n";
	    }
	    next;
#	    return 0;
	}

	foreach my $t (@TRG){

	    if ($t eq 'NULL'){
		if ($s eq 'NULL'){                       # NULL --> NULL
		    if (not $sum){                       # no score otherwise
			$sum+=1;                         # = 1?!? (ok?)
#			print STDERR "add 1 for $s - $t\n";
		    }
		}
	    }

	    if (not exists($invlex->{$t})){
		next if ($t eq 'NULL');         # this is ok for NULL links
		if ($self->{-verbose}>1){
		    print STDERR "no entry in lexicon for $t! --> ignore!\n";
		}
		return 0;
	    }

	    if (exists($lex->{$s}->{$t})){
		$sum+=$lex->{$s}->{$t};
#		print STDERR "add $lex->{$s}->{$t} for $s - $t\n";
	    }
	}
	return 0 if (not $sum);  # sum=0? --> immediately stop and return 0

	if ($normalize){
	    $sum/=($#TRG+1);  # normalize sum by number of target tokens
	}
#	print STDERR "multiply $sum with $a\n";
	$a*=$sum;                # multiply with previous a(s|t)
    }
#    print STDERR "final score = $a\n";

    return $a;
#    return log($a);
#    return 1/(0-log($a));

}




## inside/outside scores without NULL link prob's

sub zhechev_scoreXY{
    my $self=shift;
    my ($src,$trg,$lex,$invlex,$normalize)=@_;

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
	    if ($self->{-verbose}>1){
		print STDERR "no entry in lexicon for $s! --> ignore!\n";
	    }
	    next;
#	    return 0;
	}

	foreach my $t (@{$trg}){
	    if (not exists($invlex->{$t})){
		if ($self->{-verbose}>1){
		    print STDERR "no entry in lexicon for $t! --> ignore!\n";
		}
		next;
	    }

	    if (exists($lex->{$s}->{$t})){
		$sum+=$lex->{$s}->{$t};
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




# this is similar to the standard inside/outside scores
# but taking the max link value instead of the (normalized) sum

sub maxscoreXY{
    my $self=shift;
    my ($src,$trg,$lex)=@_;

    return 0 if (not @{$trg});
    return 0 if (not @{$src});

    my $a=1;
    foreach my $s (@{$src}){
	my $max=0;

	# if one of the source words does not exist in the lexicon:
	# --> max(s) is going to be zero
	# --> a(s|t) is going to be zero --> just ignore
	# (or should we return 0?)
	if (not exists($lex->{$s})){
	    if ($self->{-verbose}>1){
		print STDERR "no entry in lexicon for $s! --> ignore!\n";
	    }
	    next;
#	    return 0;
	}

	foreach my $t (@{$trg}){
	    if (exists($lex->{$s})){
		if (exists($lex->{$s}->{$t})){
		    if ($lex->{$s}->{$t}>$max){
			$max=$lex->{$s}->{$t};
		    }
		}
	    }
	}

	if (not $max){           # sum=0? --> immediately stop and return 0
	    return 0;
	}
#	return 0 if (not $max);  # sum=0? --> immediately stop and return 0

	$a*=$max;                # multiply with previous a(s|t)
    }
    return $a;
}



# this is similar to the standard inside/outside scores
# but taking the max link value instead of the (normalized) sum

sub avgmaxscoreXY{
    my $self=shift;
    my ($src,$trg,$lex)=@_;

    return 0 if (not @{$trg});
    return 0 if (not @{$src});

    my $a=0;
    foreach my $s (@{$src}){
	my $max=0;

	# if one of the source words does not exist in the lexicon:
	# --> max(s) is going to be zero
	# --> a(s|t) is going to be zero --> just ignore
	# (or should we return 0?)
	if (not exists($lex->{$s})){
	    if ($self->{-verbose}>1){
		print STDERR "no entry in lexicon for $s! --> ignore!\n";
	    }
	    next;
#	    return 0;
	}

	foreach my $t (@{$trg}){
	    if (exists($lex->{$s})){
		if (exists($lex->{$s}->{$t})){
		    if ($lex->{$s}->{$t}>$max){
			$max=$lex->{$s}->{$t};
		    }
		}
	    }
	}

#	if (not $max){           # sum=0? --> immediately stop and return 0
#	    return 0;
#	}
#	return 0 if (not $max);  # sum=0? --> immediately stop and return 0

	$a+=$max;                # multiply with previous a(s|t)
    }

    $a/=($#{$src}+1);
    return $a;
}





# this is another definition of inside/outside scores
# --> take the union of all prob's according to additon rule of prob's

sub unionscoreXY{
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






1;
__END__

=head1 NAME

Lingua::Align::Trees::Features - Perl modules for feature extraction for the Lingua::Align::Trees tree aligner

=head1 SYNOPSIS

  use Lingua::Align::Trees::Features;

  my $FeatString = 'catpos:treespansim:parent_catpos';
  my $extractor = new Lingua::Align::Trees::Features(
                          -features => $FeatString);

  my %features = $extractor->features(\%srctree,\%trgtree,
                                      $srcnode,$trgnode);



  my $FeatString2 = 'giza:gizae2f:gizaf2e:moses';
  my $extractor2 = new Lingua::Align::Trees::Features(
                      -features => $FeatString2,
                      -lexe2f => 'moses/model/lex.0-0.e2f',
                      -lexf2e => 'moses/model/lex.0-0.f2e',
                      -moses_align => 'moses/model/aligned.intersect');

  my %features = $extractor2->features(\%srctree,\%trgtree,
                                       $srcnode,$trgnode);


=head1 DESCRIPTION

Extract features from a pair of nodes from two given syntactic trees (source and target language). The trees should be complex hash structures as produced by Lingua::Align::Corpus::Treebank::TigerXML. The returned features are given as simple key-value pairs (%features)

Features to be used are specified in the feature string given to the constructor ($FeatString). Default is 'inside2:outside2' which refers to 2 features, the inside score and the outside score as defined by the Dublin Sub-Tree Aligner (see http://www2.sfs.uni-tuebingen.de/ventzi/Home/Software/Software.html, http://ventsislavzhechev.eu/Downloads/Zhechev%20MT%20Marathon%202009.pdf). For this you will need the probabilistic lexicons as created by Moses (http://statmt.org/moses/); see the -lexe2f and -lexf2e parameters in the constructor of the second example.

Features in the feature string are separated by ':'. Feature types can be combined. Possible combinations are:

=over

=item product (*)

multiply the value of 2 or more feature types, e.g. 'inside2*outside2' would refer to the product of inside2 and outside2 scores

=item average (+)

compute the average (arithmetic mean) of 2 or more features,  e.g. 'inside2+outside2' would refer to the mean of inside2 and outside2 scores

=item concatenation (.)

merge 2 or more feature keys and compute the average of their scores. This can especially be useful for "nominal" feature types that have several instantiations. For example, 'catpos' refers to the labels of the nodes (category or POS label) and the value of this feature is either 1 (present). This means that for 2 given nodes the feature might be 'catpos_NN_NP => 1' if the label of the source tree node is 'NN' and the label of the target tree node is 'NP'. Such nominal features can be combined with real valued features such as inside2 scores, e.g. 'catpos.inside2' means to concatenate the keys of both feature types and to compute the arithmetic mean of both scores.

=back

We can also refer to parent nodes on source and/or target language side. A feature with the prefix 'parent_' makes the feature extractor to take the corresponding values from the first parent nodes in source and target language trees. The prefix 'srcparent_' takes the values from the source language parent (but the current target language node) and 'trgparent_' takes the target language parent but not the source language parent. For example 'parent_catpos' gets the labels of the parent nodes. These feature types can again be combined with others as described above (product, mean, concatenation). We can also use 'sister_' features 'children_' features which will refer to the feature with the maximum value among all sister/children nodes, respectively.


=head2 FEATURES

The following feature types are implemented in the Tree Aligner:



=head3 lexical equivalence features

Lexical equivalence features evaluate the relations between words dominated by the current subtree root nodes (alignment candidates). They all use lexical probabilities usually derived from automatic word alignment (other types of probabilistic lexica could be used as well). The notion of inside words refers to terminal nodes that are dominated by the current subtree root nodes and outside words refer to terminal nodes that are not dominated by the current subtree root nodes. Various variants of scores are possible:


=over

=item inside1 (insideST1*insideTS1)

This is the unnormalized score of words inside of the current subtrees (see http://ventsislavzhechev.eu/Downloads/Zhechev%20MT%20Marathon%202009.pdf). Lexical probabilities are taken from automatic word alignment (lex-files). NULL links  are also taken into account. It is actually the product of insideST1 (probabilities from source-to-target lexicon) and insideTS1 (probabilities from target-to-source lexicon) which also can be used separately (as individual features).

=item outside1 (outsideST1*outsideTS1)

The same as inside1 but for word pairs outside of the current subtrees. NULL links are counted and scores are not normalized.

=item inside2 (insideST2*insideTS2)

This refers to the normalized inside scores as defined in the Dublin Subtree Aligner.

=item outside2 (outsideST1*outsideTS1)

The normalized scores of word pairs outside of the subtrees.

=item inside3 (insideST3*insideTS3)

The same as inside1 (unnormalized) but without considering NULL links (which makes feature extraction much faster)

=item outside3 (outsideST1*outsideTS1)

The same as outside1 but without NULL links.

=item inside4 (insideST4*insideTS4)

The same as inside2 but without NULL links.

=item outside4 (insideST4*insideTS4)

The same as outside2 but without NULL links.



=item maxinside (maxinsideST*maxinsideTS)

This is basically the same as inside4 but using "max P(x|y)" instead of "1/|y \SUM P(x|y)" as in the original definition. maxinsideST is using the source-to-target scores and maxinsideTS is using the target-to-source scores.

=item maxoutside (maxoutsideST*maxoutsideTS)

The same as maxinside but for outside word pairs

=item avgmaxinside (avgmaxinsideST*avgmaxinsideTS)

This is the same as maxinside but computing the average (1/|x|\SUM_x max P(x|y)) instead of the product (\PROD_x max P(x|y))

=item avgmaxoutside (avgmaxoutsideST*avgmaxoutsideTS)

The same as avgmaxinside but for outside word pairs

=item unioninside (unioninsideST*unioninsideTS)

Add all lexical probabilities using the addition rule of independent but not mutually exclusive probabilities (P(x1|y1)+P(x2|y2)-P(x1|y1)*P(x2|y2))

=item unionoutside (unionoutsideST*unionoutsideTS)

The same as unioninside but for outside word pairs.

=back







=head3 word alignment features

Word alignment features use the automatic word alignment directly. Again we distinguish between words that are dominated by the current subtree root nodes (inside) and the ones that are outside. Alignment is binary (1 if two words are aligned and 0 if not) and as a score we usuallty compute the proportion of interlinked inside word pairs among all links involving either source or target inside words. One exception is the moselink feature which is only defined for terminal nodes.

=over

=item moses

The proportion of interlinked words (from automatic word alignment) inside of the current subtree among all links involving either source or target words inside of the subtrees.

=item moseslink

Only for terminal nodes: is set to 1 if the twwo words are linked in the automatic word alignment derived from GIZA++/Moses.

=item gizae2f

Link proportion as for moses but now using the assymmetric GIZA++ alignments only (source-to-target).

=item gizaf2e

Link proportion as for moses but now using the assymmetric GIZA++ alignments only (target-to-source).

=item giza

Links from gizae2f and gizaf2e combined.

=back




=head3 sub-tree features

Sub-tree features refer to features that are related to the structure and position of the current subtrees.

=over 

=item treespansim

This is a feature for measuring the "horizontal" similarity of the subtrees under consideration. It is defined as the 1 - the relative position difference of the subtree spans. The relative position of a subtree is defined as the middle of the span of a subtree (begin+end/2) divided by the length of the sentence.

=item treelevelsim

This is a feature measuring the "vertical" similarity of two nodes. It is defined as 1 - the relative tree level difference. The relative tree level is defined as the distance to the sentence root node divided by the size of the tree (which is the maximum distance of any node in the tree to the sentence root).

=item nrleafsratio

This is the ratio of the number of leaf nodes dominated by the two candidate nodes. The ratio is defined as the minimum(nr_src_leafs/nr_trg_leafs,nr_trg_leafs/nr_src_leafs).

=back




=head3 annotation/label features

=over

=item C<catpos>

This feature type extracts node label pairs and gives them the value 1. It uses the "cat" attribute if it exists, otherwise it uses the "pos" attribute if that one exists.

=item C<edge>

This feature refers to the pairs of edge labels (relations) of the current nodes to their immediate parent (only the first parent is considered if multiple exist). This is a binary feature and is set to 1 for each observed label pair.

=back







=head1 SEE ALSO

For the tree structure see L<Lingua::Align::Corpus::Treebank>.
For the tree aligner look at L<Lingua::Align::Trees>


=head1 AUTHOR

Joerg Tiedemann, E<lt>j.tiedemann@rug.nlE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 by Joerg Tiedemann

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.

=cut
