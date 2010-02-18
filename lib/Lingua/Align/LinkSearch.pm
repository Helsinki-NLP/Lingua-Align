package Lingua::Align::LinkSearch;

use 5.005;
use strict;

use vars qw($VERSION @ISA);
@ISA = qw();
$VERSION = '0.01';

use FileHandle;
use Lingua::Align::LinkSearch::Threshold;
use Lingua::Align::LinkSearch::Greedy;
use Lingua::Align::LinkSearch::GreedyWellFormed;
use Lingua::Align::LinkSearch::GreedyFinal;
use Lingua::Align::LinkSearch::GreedyFinalAnd;
use Lingua::Align::LinkSearch::Src2Trg;
use Lingua::Align::LinkSearch::Trg2Src;
use Lingua::Align::LinkSearch::Intersection;
use Lingua::Align::LinkSearch::NTFirst;
use Lingua::Align::LinkSearch::NTonly;
use Lingua::Align::LinkSearch::Tonly;
use Lingua::Align::LinkSearch::Assignment;
use Lingua::Align::LinkSearch::PaCoMT;


sub new{
    my $class=shift;
    my %attr=@_;

#    my $type = $attr{-link_search} || 'greedy';
    my $type = $attr{-link_search} || 'threshold';

    if ($type=~/paco/i){
	return new Lingua::Align::LinkSearch::PaCoMT(%attr);
    }

    # NT nodes first using the search strategy specified thereafter
    if ($type=~/^nt.*first/i){
	return new Lingua::Align::LinkSearch::NTFirst(%attr);
    }
    if ($type=~/and/i){
	return new Lingua::Align::LinkSearch::GreedyFinalAnd(%attr);
    }
    if ($type=~/final/i){
	return new Lingua::Align::LinkSearch::GreedyFinal(%attr);
    }

    # NT nodes first but "final" and "and" are handled before
    if ($type=~/nt.*first/i){
	return new Lingua::Align::LinkSearch::NTFirst(%attr);
    }

    if ($type=~/ntonly/i){
	return new Lingua::Align::LinkSearch::NTonly(%attr);
    }
    if ($type=~/tonly/i){
	return new Lingua::Align::LinkSearch::Tonly(%attr);
    }
    if ($type=~/src2trg/i){
	return new Lingua::Align::LinkSearch::Src2Trg(%attr);
    }
    if ($type=~/trg2src/i){
	return new Lingua::Align::LinkSearch::Trg2Src(%attr);
    }
    if ($type=~/inter/i){
	return new Lingua::Align::LinkSearch::Intersection(%attr);
    }
    if ($type=~/well.*formed/i){
	return new Lingua::Align::LinkSearch::GreedyWellFormed(%attr);
    }
    if ($type=~/greedy/i){
	return new Lingua::Align::LinkSearch::Greedy(%attr);
    }
    if ($type=~/(assign|munkres)/i){
	return new Lingua::Align::LinkSearch::Assignment(%attr);
    }
    return new Lingua::Align::LinkSearch::Threshold(%attr);
}



1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Lingua::Align::LinkSearch - Perl extension for tree link search

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 SEE ALSO

=head1 AUTHOR

Joerg Tiedemann, E<lt>j.tiedemann@rug.nlE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 by Joerg Tiedemann

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.


=cut
