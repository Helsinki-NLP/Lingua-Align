package Lingua::Align::LinkSearch;

use 5.005;
use strict;

use vars qw($VERSION @ISA);
@ISA = qw();
$VERSION = '0.01';

use FileHandle;
use Lingua::Align::LinkSearch::Greedy;
use Lingua::Align::LinkSearch::GreedyWellFormed;
use Lingua::Align::LinkSearch::Src2Trg;
use Lingua::Align::LinkSearch::Trg2Src;
use Lingua::Align::LinkSearch::Intersection;


sub new{
    my $class=shift;
    my %attr=@_;

    my $type = $attr{-link_search} || 'greedy';

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
    return new Lingua::Align::LinkSearch::Greedy(%attr);
}



1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Lingua::Align::LinkSearch - Perl extension for 

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
