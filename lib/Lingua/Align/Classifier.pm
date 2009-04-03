#
#
#
#

package Lingua::Align::Classifier;

use vars qw(@ISA $VERSION);
use strict;

#use Lingua::Align::Words::FeatureExtractor;
use Lingua::Align::Classifier::Megam;
#use Lingua::Align::Classifier::LibSVM;
#use Lingua::Align::Classifier::Diagonal;
#use Lingua::Align::Clue;

$VERSION='0.1';
@ISA = qw();

sub new{
    my $class=shift;
    my %attr=@_;
    my $self;

    my $classifier="megam";
    if (exists $attr{-classifier}){
	$classifier = $attr{-classifier};
	delete $attr{-classifier};
	$self=new Lingua::Align::Clue(%attr) if ($classifier=~/clue/i);
	$self=new Lingua::Align::Classifier::LibSVM(%attr) 
	    if ($classifier=~/svm/i);
	$self=new Lingua::Align::Classifier::Diagonal(%attr) 
	    if ($classifier=~/diag/i);
    }
    $self = new Lingua::Align::Classifier::Megam(%attr) if (not defined $self);


#     $self->{MAX_TRAIN_SENTS} = $attr{-max_train_sents} || 5000;
    foreach (keys %attr){
	$self->{$_}=$attr{$_};
    }
    return $self;


}

sub train{}
sub initialize_taining{};
sub register_training_event{}


sub classify{}

1;
