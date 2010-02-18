package Lingua::Align::LinkSearch::Assignment;

use 5.005;
use strict;

use vars qw($VERSION @ISA);
@ISA = qw(Lingua::Align::LinkSearch::Greedy);
$VERSION = '0.01';

use Algorithm::Munkres;

sub search{
    my $self=shift;
    my ($linksST,$scores,$min_score,$src,$trg,$labels)=@_;

    my $correct=0;
    my $wrong=0;
    my $total=0;

    my $max=1;       # max score --> use cost=max-score

    # inefficent way to assign position IDs to nodeIDs
    my %SrcIds=();
    my @SrcNodes=();
    my $nr=0;
    foreach (@{$src}){
	if (not exists $SrcIds{$_}){
	    $SrcIds{$_}=$nr;$SrcNodes[$nr]=$_;
	    $nr++;
	}
    }
    my %TrgIds=();
    my @TrgNodes=();
    my $nr=0;
    foreach (@{$trg}){
	if (not exists $TrgIds{$_}){
	    $TrgIds{$_}=$nr;$TrgNodes[$nr]=$_;
	    $nr++;
	}
    }

    # make cost matrix (simply use $max-score)
    my @matrix=();
    my @label=();
    foreach (0..$#{$scores}){
	$matrix[$SrcIds{$$src[$_]}][$TrgIds{$$trg[$_]}] = $max-$$scores[$_];
	$label[$SrcIds{$$src[$_]}][$TrgIds{$$trg[$_]}] = $$labels[$_];
	if ($$labels[$_] == 1){$total++;}
    }

    for my $s (0..$#SrcNodes){
	for my $t (0..$#TrgNodes){
	    if (not $matrix[$s][$t]){
		$matrix[$s][$t]=$max;
	    }
	}
    }


    # assign connections
    my @assignment=();
    &Algorithm::Munkres::assign(\@matrix,\@assignment);

    my %linksTS=();

    # save links (no score threshold?!?)
    foreach (0..$#assignment){
	next if (not $matrix[$_][$assignment[$_]]);
	my $score=$max-$matrix[$_][$assignment[$_]];
	next if ($score<$min_score);
	my ($snid,$tnid);
	$snid = $SrcNodes[$_];
	$tnid = $TrgNodes[$assignment[$_]];
	$$linksST{$snid}{$tnid}=$max-$matrix[$_][$assignment[$_]];
	$linksTS{$tnid}{$snid}=$max-$matrix[$_][$assignment[$_]];
	if ($label[$_][$assignment[$_]] == 1){$correct++;}
	else{$wrong++;}
    }
    $self->remove_already_linked($linksST,\%linksTS,$scores,$src,$trg,$labels);
    return ($correct,$wrong,$total);
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