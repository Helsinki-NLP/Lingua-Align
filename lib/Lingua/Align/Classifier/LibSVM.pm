
package Lingua::Align::Classifier::LibSVM;

use vars qw(@ISA $VERSION);
use strict;

use FileHandle;
use IPC::Open3;
use Algorithm::SVM;
use Algorithm::SVM::DataSet;

$VERSION='0.1';
@ISA = qw( Lingua::Align::Classifier::Megam );


sub new{
    my $class=shift;
    my %attr=@_;

    my $self={};
    bless $self,$class;

    foreach (keys %attr){
	$self->{$_}=$attr{$_};
    }

    return $self;
}



sub initialize_training{
    my $self=shift;
    $self->{SVM} = new Algorithm::SVM(Type => 'nu-SVR',
				      Kernel => 'linear');
    $self->{SVM_TRAINSET}=[];
}


sub add_train_instance{
    my ($self,$label,$feat,$weight)=@_;
    if (not ref($self->{SVM})){
	$self->initialize_training();
    }

#    if ($label==0){$label='-1';}
#    if ($label==1){$label='+1';}

    if (defined($weight) && ($weight != 1)){
	if ($weight<1){
	    print STDERR "weights are not supported!\n --> use weight=1!\n";
	}
    }
    else{$weight=1;}

    my @data=();
    foreach (keys %{$feat}){
	if (! exists $self->{__FEATIDS__}->{$_}){
	    $self->{__FEATCOUNT__}++;
	    $self->{__FEATIDS__}->{$_}=$self->{__FEATCOUNT__};
	}
	$data[$self->{__FEATIDS__}->{$_}]=$$feat{$_};
    }

    my $instance = new Algorithm::SVM::DataSet(Label => $label, 
					       Data => \@data);
#    for (my $i=0;$i<$weight;$i++){
	push(@{$self->{SVM_TRAINSET}},$instance);
#    }
}

sub train{
    my $self = shift;
    my $model = shift || '__megam.'.$$;

    $self->{SVM}->train(@{$self->{SVM_TRAINSET}});

#    # cross validation on training set
#    if ($self->{-verbose}){
#	my $accuracy = $self->{SVM}->svm_validate(5);
#	print STDERR "accuracy = $accuracy\n";
#    }

    $self->{SVM}->save($model);
    $self->save_feature_ids($model.'.ids',$self->{__FEATIDS__});

    ################################ !!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    ## save feature ids ......
    ## ---> need them for feature extraction for aligning!!!!!!!!!
    ################################ !!!!!!!!!!!!!!!!!!!!!!!!!!!!!

    return $model;
}

sub save_feature_ids{
    my $self=shift;
    my ($file,$feat)=@_;
    open F,">$file" || die "cannot open feature ID file $file\n";
    foreach (keys %{$feat}){
	print F "$$feat{$_}\t$_\n";
    }
    close F;
}

sub load_feature_ids{
    my $self=shift;
    my ($file,$feat)=@_;
    open F,"<$file" || die "cannot open feature ID file $file\n";
    while (<F>){
	chomp;
	my ($id,$f)=split(/\t/);
	$$feat{$f}=$id;
    }
    close F;
}





sub initialize_classification{
    my $self=shift;
    my $model=shift;

    $self->{__FEATCOUNT__}=0;
    $self->{__FEATIDS__}={};

    $self->{SVM} = new Algorithm::SVM(Model => $model,
				      Kernel => 'linear',
				      Type => 'nu-SVR');
    $self->{SVM_MODEL} = $model;
    $self->load_feature_ids($model.'.ids',$self->{__FEATIDS__});

    return 1;
}

sub add_test_instance{
    my ($self,$feat)=@_;
    my $label = $_[2] || 0;

    if (not ref($self->{TEST_DATA})){
	$self->{TEST_DATA}=[];
	$self->{TEST_LABEL}=[];
    }

#    if ($label==0){$label='-1';}
#    if ($label==1){$label='+1';}

    my @data=();
    foreach (keys %{$feat}){
	if (! exists $self->{__FEATIDS__}->{$_}){
	    if ($self->{-verbose}){
		print STDERR "feature $_ does not exist! ignore!\n";
	    }
	}
	$data[$self->{__FEATIDS__}->{$_}]=$$feat{$_};
    }

    my $instance = new Algorithm::SVM::DataSet(Label => $label, 
					       Data => \@data);
    push(@{$self->{TEST_DATA}},$instance);
    push(@{$self->{TEST_LABEL}},$label);

}


sub classify{
    my $self=shift;
    my $model = shift || '__svm.'.$$;

    return () if (not ref($self->{TEST_DATA}));

    if ($self->{SVM_MODEL} ne $model){
	$self->initialize_classification($model);
    }

    # send input data to the megam process

    my @scores=();
    my @labels=();
    foreach my $data (@{$self->{TEST_DATA}}){
	my $res=$self->{SVM}->predict($data);
	my $val=$self->{SVM}->predict_value($data);
#	my $prob=$self->{SVM}->getSVRProbability();
#	if ($res>0){
#	    print STDERR "!!!!! positive!!!!!!\n";
#	}
	push (@scores,$val);
	push (@labels,$res);
    }

    delete $self->{TEST_DATA};
    delete $self->{TEST_LABEL};

    return @scores;

}


1;

