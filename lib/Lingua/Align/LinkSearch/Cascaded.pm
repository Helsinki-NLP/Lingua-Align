package Lingua::Align::LinkSearch::Cascaded;

#
# cascaded link search: define a sequence of link-search algorithms
#                       to be applied for incremental alignment
#
# The sequence is specified like this:
#
# -link_search = cascaded:strategy1-strategy2-...-strategyN
#
# (names of the strategies separated by '-') any strategy supported by 
# LinkSearch is allowed here. For example:
#
# NTonlySrc2TrgWeaklyWellformed (align NT nodes only using a source-to-target
#                                strategy, checking for weak wellformedness)
# TonlyGreedyWellformed         (align terminals only using a greedy alignment
#                                strategy (1:1 links only) and check for
#                                wellformedness)
# Src2TrgWeaklyWellformed       (align nodes with a source-to-target strategy,
#                                check for weak wellformedness)
# ......
#

use 5.005;
use strict;

use vars qw($VERSION @ISA);
@ISA = qw(Lingua::Align::LinkSearch);
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

    my $cascade = $self->{-link_search} || 
	'cascaded:NTonlyGreedyWellformed-GreedyWeaklyWellformedFinal';

    $cascade=~/^[^:]*:\s*(.*)\s*$/;
    @{$self->{CASCADE}} = split(/\-/,$1);
    @{$self->{LINKSEARCH}}=();
    foreach (0..$#{$self->{CASCADE}}){
	$self->{LINKSEARCH}->[$_] = 
	    new Lingua::Align::LinkSearch(-link_search=>$self->{CASCADE}->[$_]);
    }

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

    my ($correct,$wrong,$total);

    foreach my $aligner (@{$self->{LINKSEARCH}}){
	my ($c,$w,$t) = $aligner->search($linksST,$scores,$min_score,
					 $src,$trg,$labels,
					 $stree,$ttree,$linksTS);
	$correct+=$c;$wrong+=$w;$total+=$t;
    }
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
