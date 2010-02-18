package Lingua::Align::LinkSearch::PaCoMT;

use 5.005;
use strict;

use vars qw($VERSION @ISA);
@ISA = qw(Lingua::Align::LinkSearch::GreedyWellFormed);
$VERSION = '0.01';

use Lingua::Align::LinkSearch;

sub new{
    my $class=shift;
    my %attr=@_;

    my $self={};
    bless $self,$class;

    foreach (keys %attr){
	$self->{$_}=$attr{$_};
    }

    $self->{LINKNT} = 
	new Lingua::Align::LinkSearch(-link_search =>'NTonlyGreedyWellformed');

    $self->{LINKT} = 
	new Lingua::Align::LinkSearch(-link_search =>'TonlyGreedyWellformed');

    $self->{FINAL} = 
	new Lingua::Align::LinkSearch(-link_search =>'GreedyWeaklyWellformedFinal');

    # for tree manipulation
    $self->{TREES} = new Lingua::Align::Corpus::Treebank();

    return $self;
}

sub search{
    my $self=shift;
    my ($linksST,$scores,$min_score,
	$src,$trg,$labels,
	$stree,$ttree,$linksTS)=@_;

    if (ref($linksTS) ne 'HASH'){$linksTS={};}

    my ($correct1,$wrong1,$total1) = 
	$self->{LINKNT}->search($linksST,$scores,$min_score,
				$src,$trg,$labels,
				$stree,$ttree,$linksTS);
    my ($correct2,$wrong2,$total2) = 
	$self->{LINKT}->search($linksST,$scores,$min_score,
			       $src,$trg,$labels,
			       $stree,$ttree,$linksTS);
    my ($correct3,$wrong3,$total3) = 
	$self->{FINAL}->search($linksST,$scores,$min_score,
			       $src,$trg,$labels,
			       $stree,$ttree,$linksTS);

    return ($correct1+$correct2+$correct3,
	    $wrong1+$wrong2+$wrong3,
	    $total1+$total2+$total3);

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