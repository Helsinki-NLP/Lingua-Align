#
#
#
#

package Align::Classifier::Diagonal;

use vars qw(@ISA $VERSION);
use strict;


$VERSION='0.1';
@ISA = qw( Align::Classifier );

sub new{
    my $class=shift;
    my %attr=@_;

    my $self={};
    bless $self,$class;
    return $self;
}



sub train{}
sub classify{}

sub read_scores{
    my $self=shift;
    my ($nrSrc,$nrTrg,$scores,$labels)=@_;
    foreach my $s (0..$nrSrc){
	foreach my $t (0..$nrTrg){
	    $$scores[$s][$t] = 1 - abs($s/$nrSrc - $t/$nrTrg);
	    if ($$scores[$s][$t]>0.8){
		$$labels[$s][$t]=1;
	    }
	    else{$$labels[$s][$t]=0;}
	}
    }
}





1;
