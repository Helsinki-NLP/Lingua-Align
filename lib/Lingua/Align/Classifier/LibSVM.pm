
package Align::Classifier::LibSVM;

use vars qw(@ISA $VERSION);
use strict;

$VERSION='0.1';
@ISA = qw( Align::Classifier );

sub new{
    my $class=shift;
    my %attr=@_;

    my $self={};
    bless $self,$class;

    $self->{LIBSVM_TRAIN} = $attr{-libsvm_train} || 
	$ENV{HOME}.'/projects/align/MaxEnt/SVM/libsvm-2.88/svm-train';
    $self->{LIBSVM_PREDICT} = $attr{-libsvm_train} || 
	$ENV{HOME}.'/projects/align/MaxEnt/SVM/libsvm-2.88/svm-predict';
    $self->{LIBSVM_SCALE} = $attr{-libsvm_train} || 
	$ENV{HOME}.'/projects/align/MaxEnt/SVM/libsvm-2.88/svm-scale';

    $self->{LIBSVM_TRAIN_ARGS} = $attr{-libsvm_train_args} || ' -h 0 -m 4096 ';

    $self->read_featIDs();

    return $self;
}



sub DESTROY{
    my $self=shift;
    if (ref($self->{__FEATIDS__}) eq 'HASH'){
	my $model = $self->{CLASSIFIER_MODEL};
	$model=$self->find_classifier_file($model);
	my $featidfile = $model.'.feat';
	open F,">$featidfile" || die "cannot open featID file $featidfile\n";
    
	while (my @arr = each %{$self->{__FEATIDS__}}){
	    print F $arr[0],"\t",$arr[1],"\n";
	}
	close F;
    }
}


sub read_featIDs{
    my $self=shift;
    my $model = $self->{CLASSIFIER_MODEL};
    $model=$self->find_classifier_file($model);
    my $featidfile = $model.'.feat';
    if (-e $featidfile){
	open F,"<$featidfile" || die "cannot open featID file $featidfile\n";
   
	while (<F>){
	    chomp;
	    my ($k,$v)=split;
	    $self->{__FEATIDS__}->{$k}=$v;
	}
	close F;
    }
}




sub print_training_event{
    my ($self,$fh,$label,$feat,$weight)=@_;

    if ($label==0){$label='-1';}
    if ($label==1){$label='+1';}

    if (defined($weight) && ($weight != 1)){
	if ($weight>0){
	    print STDERR "weights are not supported!\n --> use weight=1!\n";
	}
    }
    print $fh $label;
    
    foreach (keys %{$feat}){
	if (! exists $self->{__FEATIDS__}->{$_}){
	    $self->{__FEATCOUNT__}++;
	    $self->{__FEATIDS__}->{$_}=$self->{__FEATCOUNT__};
	}
	print $fh ' ',$self->{__FEATIDS__}->{$_},':'.$$feat{$_}
    }
    print $fh "\n";
}



sub train{
    my $self=shift;
    my ($srcfile,$trgfile,$alignfile,
	$model,$trainfile)=@_;

    $model = $self->{CLASSIFIER_MODEL} if (not defined $model);

    $model=$self->find_classifier_file($model);
    if (-e $model){
	print STDERR "reuse old model\n" if ($self->{VERBOSE});
	return $model;
    }

    $trainfile = $self->{CLASSIFIER_TRAIN} if (not defined $trainfile);
    $trainfile = $self->extract_training_events($srcfile,$trgfile,
						$alignfile,$trainfile);

    $self->store_features_used($model);

# .... train a new model

    my $command = $self->{LIBSVM_TRAIN}.' -b 1 ';
    $command .= $self->{LIBSVM_TRAIN_ARGS};
    ## redirect STDOUT to STDERR
    $command .= ' '.$trainfile.' '.$model.' 1>&2 ';
    print STDERR "train with:\n$command\n" if ($self->{VERBOSE});
    system($command);
    unlink $trainfile unless $self->{KEEP_FEATURE_FILES};
    unlink $trainfile.'.features' unless $self->{KEEP_FEATURE_FILES};
    return $model;
}

sub classify{
    my $self=shift;
    my ($srcfile,$trgfile,$testfile,$classfile,$model)=@_;

    $testfile = $self->{CLASSIFIER_INPUT} if (not defined $testfile);
    $classfile = $self->{CLASSIFIER_OUTPUT} if (not defined $classfile);
    $model = $self->{CLASSIFIER_MODEL} if (not defined $model);

    $testfile = $self->extract_features($srcfile,$trgfile,$testfile);
    $model=$self->find_classifier_file($model);

    ## should I allow to use models trained on other feature sets?
    ## (better not ... just die ....)
    if ($self->features_used($model) ne $self->features_used($testfile)){
	die "\n\nnot the same features used for training and testing!\nre-run training!\n\n";
    }

    my $command = $self->{LIBSVM_PREDICT}.' -b 1 '.$testfile.' '.$model;
    $command .= ' '.$classfile.' 1>&2 ';
    print STDERR "classify with:\n$command\n" if ($self->{VERBOSE});
    system($command);
    unlink $testfile unless $self->{KEEP_FEATURE_FILES};
    unlink $testfile.'.features' unless $self->{KEEP_FEATURE_FILES};
}




sub read_scores{
    my $self=shift;
    my ($x,$y,$scores,$labels,$classfile)=@_;
    $classfile = $self->{CLASSIFIER_OUTPUT} if (not defined $classfile);

    foreach my $s (0..$x){
	foreach my $t (0..$y){
	    ($$labels[$s][$t],$$scores[$s][$t])=$self->next_record($classfile);
	    ## skip first row (just info about labels used ...)
	    if ($$labels[$s][$t] eq 'labels'){
		($$labels[$s][$t],$$scores[$s][$t])=
		    $self->next_record($classfile);
	    }
	    ## label -1 --> means '0'
	    $$labels[$s][$t]=0 if ($$labels[$s][$t]<0);
	}
    }
}




1;

