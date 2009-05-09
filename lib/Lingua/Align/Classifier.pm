#
#
#
#

package Lingua::Align::Classifier;

use vars qw(@ISA $VERSION);
use strict;


use Lingua::Align::Classifier::Megam;
use Lingua::Align::Classifier::LibSVM;
use Lingua::Align::Classifier::Clues;

#use Lingua::Align::Words::FeatureExtractor;
#use Lingua::Align::Classifier::LibSVM;
#use Lingua::Align::Classifier::Diagonal;


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
	if ($classifier=~/clue/i){
	    return $self=new Lingua::Align::Classifier::Clues(%attr);
	}
	elsif ($classifier=~/svm/i){
	    return $self=new Lingua::Align::Classifier::LibSVM(%attr);
	}
	elsif ($classifier=~/diag/i){
	    return $self=new Lingua::Align::Classifier::Diagonal(%attr);
	}
	    
    }
    ## default = MEGAM classifier!
    return $self = new Lingua::Align::Classifier::Megam(%attr);

}


sub initialize_training{};
sub add_train_instance{}
sub train{}

sub initialize_classification{}
sub load_model{};
sub add_test_instance{}
sub classify{}

1;
