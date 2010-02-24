

package Lingua::Align::Corpus::Parallel::Dublin;

use 5.005;
use strict;

use vars qw($VERSION @ISA);
@ISA = qw(Lingua::Align::Corpus::Parallel);

$VERSION = '0.01';

use Lingua::Align::Corpus;
use Lingua::Align::Corpus::Parallel;

sub new{
    my $class=shift;
    my %attr=@_;

    my $self={};
    bless $self,$class;

    foreach (keys %attr){
	$self->{$_}=$attr{$_};
    }

    my %CorpusAttr=%attr;
    $CorpusAttr{-type} = 'penn';
    $CorpusAttr{-add_ids} = 1;            # add node id's
    if ($attr{-skip_node_ids}){           # but skip adding the original
	$CorpusAttr{-skip_node_ids} = 1;  # node IDs
    }

    $self->{CORPUS}=new Lingua::Align::Corpus(%CorpusAttr);

    return $self;
}


sub read_next_alignment{
    my $self=shift;
    my ($src,$trg)=@_;
    return 0 if (not $self->{CORPUS}->next_sentence($src));
    return 0 if (not $self->{CORPUS}->next_sentence($trg));

    ## .... unfinished
    ## do something more to handle collapsed unary sub-trees
    ## do something to handle node alignments ....
    ## .....

    return 1;
}



sub print_alignments{
    my $self=shift;
    my $srctree=shift;
    my $trgtree=shift;
    my $links=shift;

    
    my @srcIDs=();
    my $str=$self->{CORPUS}->print_tree($srctree,\@srcIDs);
    $str.="\n";
    my @trgIDs=();
    $str.=$self->{CORPUS}->print_tree($trgtree,\@trgIDs);
    $str.="\n";

    my %srcid2nr=();
    for (0..@srcIDs){
	$srcid2nr{$srcIDs[$_]}=$_+1;
    }
    my %trgid2nr=();
    for (0..@trgIDs){
	$trgid2nr{$trgIDs[$_]}=$_+1;
    }

    my @LinkNr=();
    foreach my $s (keys %{$links}){
	foreach my $t (keys %{$$links{$s}}){
	    push(@LinkNr,$srcid2nr{$s}.' '.$trgid2nr{$t});
	}
    }
    $str.=join(' ',sort {$a <=> $b} @LinkNr);
    $str.="\n\n";
    return $str;

}




1;
__END__

=head1 NAME

Lingua::Align::Corpus::Parallel::Dublin - Perl extension for reading tree-aligned parallel corpora in Dublin Subtree Aligner format

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
