package Lingua::Align::LinkSearch::Trg2Src;

use 5.005;
use strict;
use vars qw($VERSION @ISA);
use Lingua::Align::LinkSearch::Greedy;

@ISA = qw(Lingua::Align::LinkSearch::Greedy);
$VERSION = '0.01';



sub search{
    my $self=shift;
    return $self->searchTrg2Src(@_);
}


sub searchTrg2Src{
    my $self=shift;
    my ($linksST,$scores,$min_score,$src,$trg,$labels,$LabelMatrix)=@_;

    my $correct=0;
    my $wrong=0;
    my $total=0;

    my %value=();
    my %label=();

    my %BestTrg=();
    my %BestLink=();
    my %BestLabel=();

    foreach (0..$#{$scores}){
	if ($$scores[$_]>=$min_score){
	    if ($$scores[$_]>$BestTrg{$$trg[$_]}){
		$BestTrg{$$trg[$_]}=$$scores[$_];
		$BestLink{$$trg[$_]}=$$src[$_];
		$BestLabel{$$trg[$_]}=$$labels[$_];
	    }
	}
	if ($LabelMatrix){
	    $$LabelMatrix{$$src[$_]}{$$trg[$_]}=$$labels[$_];
	}
	if ($$labels[$_] == 1){$total++;}
    }

    my %linksTS=();
    foreach my $t (keys %BestTrg){
	$$linksST{$BestLink{$t}}{$t}=$BestTrg{$t};
	$linksTS{$t}{$BestLink{$t}}=$BestTrg{$t};
	if ($BestLabel{$t} == 1){$correct++;}
	else{$wrong++;}
    }

    $self->remove_already_linked($linksST,\%linksTS,$scores,$src,$trg,$labels);
    return ($correct,$wrong,$total);
}


1;
__END__

=head1 NAME

Lingua::Align::LinkSearch::Trg2Src

=head1 SYNOPSIS

=head1 DESCRIPTION

This module implements an alignment strategy that greedily aligns the best scoring source tree node to each target tree node. Only one link per target tree node is allowed.

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
