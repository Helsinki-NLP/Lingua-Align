
package Lingua::Align::Classifier::LibSVM;

use vars qw(@ISA $VERSION);
use strict;

use FileHandle;
use IPC::Open3;

$VERSION='0.1';
@ISA = qw( Lingua::Align::Classifier::Megam );



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

    foreach (keys %attr){
	$self->{$_}=$attr{$_};
    }

    return $self;
}

sub initialize_classification{
    my $self=shift;
    my $model=shift;

    my $arguments = "-fvals -predict $model binary";
    my $command = "$self->{MEGAM} $arguments -";

    $self->{MEGAM_PROC} = open3($self->{MEGAM_IN}, 
				$self->{MEGAM_OUT}, 
				$self->{MEGAM_ERR},
				$command);
    return $self->{MEGAM_PROC};
}

sub add_test_instance{
    my ($self,$feat)=@_;
    my $label = $_[2] || 0;

    if (not ref($self->{TEST_DATA})){
	$self->{TEST_DATA}=[];
	$self->{TEST_LABEL}=[];
    }
    push(@{$self->{TEST_DATA}},join(' ',%{$feat}));
    push(@{$self->{TEST_LABEL}},$label);
}



sub initialize_training{
    my $self=shift;

    $self->{TRAINFILE} = $self->{-training_data} || '__train.'.$$;
    $self->{TRAIN_FH} = new FileHandle;
    $self->{TRAIN_FH}->open(">$self->{TRAINFILE}") || 
	die "cannot open training data file $self->{TRAINFILE}\n";
}


sub add_train_instance{
    my ($self,$label,$feat,$weight)=@_;
    if (not ref($self->{TRAIN_FH})){
	$self->initialize_training();
    }

    if (not ref($self->{TRAIN_FH})){
	$self->initialize_training();
    }
    my $fh=$self->{TRAIN_FH};

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
    my $self = shift;
    my $model = shift || '__megam.'.$$;

#    $self->store_features_used($model);
    my $trainfile = $self->{TRAINFILE};

# .... train a new model

    my $arguments=$self->{LIBSVM_TRAIN_ARGS};
    my $command = "$self->{LIBSVM_TRAIN} $arguments $trainfile $model";
    print STDERR "train with:\n$command\n" if ($self->{-verbose});
    system($command);

    unlink $trainfile unless $self->{-keep_training_data};
    return $model;
}


sub classify{
    my $self=shift;
    my $model = shift || '__megam.'.$$;

    return () if (not ref($self->{TEST_DATA}));

    if (not defined $self->{MEGAM_PROC}){
	if (not $self->initialize_classification($model)){
	    return $self->classify_with_tempfile($model);
	}
    }

    my $in = $self->{MEGAM_IN};
    my $out = $self->{MEGAM_OUT};

    # send input data to the megam process

    my @scores=();
    foreach my $data (@{$self->{TEST_DATA}}){
	my $label=shift(@{$self->{TEST_LABEL}});
	print $in $label,' ',$data,"\n";            # send input
	my $line=<$out>;                            # read classification
	chomp $line;
	my ($label,$score)=split(/\s+/,$line);
	push (@scores,$score);
    }

    delete $self->{TEST_DATA};
    delete $self->{TEST_LABEL};

#    print STDERR scalar @scores if ($self->{-verbose});
#    print STDERR " ... new scores returned\n"  if ($self->{-verbose});
    return @scores;

}




# classify test data by calling megam with a temporary feature file
# (if opening IPC fails)


sub classify_with_tempfile{
    my $self=shift;
    my $model = shift || '__megam.'.$$;

    return () if (not ref($self->{TEST_DATA}));

    # store features in temporary file
    # (or can we somehow pipe data into megam?)

    my $testfile = $self->{-classification_data} || '__megam_testdata.'.$$;
    my $fh = new FileHandle;
    $fh->open(">$testfile") || die "cannot open data file $testfile\n";
    foreach my $data (@{$self->{TEST_DATA}}){
	my $label=shift(@{$self->{TEST_LABEL}});
	print $fh $label.' ';
	print $fh $data,"\n";
    }
    $fh->close();

    # classify with megam (predict mode)

    my $arguments="-fvals -predict $model binary";
    my $command = "$self->{MEGAM} $arguments $testfile";
    print STDERR "classify with:\n$command\n" if ($self->{-verbose});
    my $results = `$command 2>/dev/null`;
    unlink $testfile;

    # get the results (from STDOUT)

    my @lines = split(/\n/,$results);

    my @scores=();
    foreach (@lines){
	my ($label,$score)=split(/\s+/);
	push (@scores,$score);
    }

    delete $self->{TEST_DATA};
    delete $self->{TEST_LABEL};

    return @scores;

}


###########################################################################
# alternative: load the model and classify myself (without megam)

sub load_model{
    my $self=shift;
    my $model = shift || '__megam.'.$$;
    open F,"<$model" || die "cannot open megam model $model\n";
    while (<F>){
	chomp;
	my ($name,$value)=split(/\s+/);
	$self->{MODEL}->{$name}=$value;
    }
    close F;
}

# classify internally without calling megam using the weights in the model file
# problem: how do we normalize?

sub classify_myself{
    my $self=shift;
    my $model = shift || '__megam.'.$$;
    if (not ref($self->{MODEL})){
	$self->load_model($model);
    }

    return () if (not ref($self->{TEST_DATA}));

    my $topscore=0;
    my @scores=();
    foreach my $data (@{$self->{TEST_DATA}}){
	my $label=shift(@{$self->{TEST_LABEL}});
	my %feat = split(/\s+/,$data);
	my $score=0;
	foreach my $f (keys %feat){
	    $score += $feat{$f}*$self->{MODEL}->{$f};
	    if ($score>$topscore){$topscore=$score;}
	}
#	$score = 1/(1+exp(0-$score));
	push(@scores,$score);
    }
    map($_/=$topscore,@scores);

    delete $self->{TEST_DATA};
    delete $self->{TEST_LABEL};

    return @scores;
}



1;

