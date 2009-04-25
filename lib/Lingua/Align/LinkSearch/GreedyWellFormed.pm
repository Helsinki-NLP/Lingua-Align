package Lingua::Align::LinkSearch::GreedyWellFormed;

use 5.005;
use strict;
use Lingua::Align::LinkSearch::Greedy;
use Lingua::Align::Corpus::Treebank;

use vars qw($VERSION @ISA);
@ISA = qw(Lingua::Align::LinkSearch::Greedy);
$VERSION = '0.01';


sub new{
    my $class=shift;
    my %attr=@_;

    my $self={};
    bless $self,$class;

    foreach (keys %attr){
	$self->{$_}=$attr{$_};
    }

    # for tree manipulation
    $self->{TREES} = new Lingua::Align::Corpus::Treebank();

    return $self;
}


sub search{
    my $self=shift;
    my ($linksST,$scores,$min_score,$src,$trg,$labels,$srctree,$trgtree)=@_;

    my $correct=0;
    my $wrong=0;
    my $total=0;

    my %value=();
    my %label=();
    foreach (0..$#{$scores}){
	if ($$scores[$_]>=$min_score){
	    $value{$$src[$_].':'.$$trg[$_]}=$$scores[$_];
	    $label{$$src[$_].':'.$$trg[$_]}=$$labels[$_];
	}
	if ($$labels[$_] == 1){$total++;}
    }

    my %linksTS=();
    foreach my $k (sort {$value{$b} <=> $value{$a}} keys %value){
	last if ($value{$k}<$min_score);
	my ($snid,$tnid)=split(/\:/,$k);
	next if (exists $$linksST{$snid});
	next if (exists $linksTS{$tnid});

	## check well-formedness .....

	if ($snid eq 's25_501'){
	    print '';
	}

	my $wellformed = 1;
	foreach my $s (keys %{$linksST}){

	    my $is_desc = $self->{TREES}->is_descendent($srctree,$s,$snid);
	    my $is_anc;
	    if (not $is_desc){
		$is_anc = $self->{TREES}->is_ancestor($srctree,$s,$snid);
	    }

	    foreach my $t (keys %{$$linksST{$s}}){
		if ($is_desc){
		    if (not $self->{TREES}->is_descendent($trgtree,$t,$tnid)){
			$wellformed=0;
			last;
		    }
		}
		if ($is_anc){
		    if (not $self->{TREES}->is_ancestor($trgtree,$t,$tnid)){
			$wellformed=0;
			last;
		    }
		}
	    }
	    last if (not $wellformed);
	}

	if ($wellformed){
	    $$linksST{$snid}{$tnid}=$value{$k};
	    $linksTS{$tnid}{$snid}=$value{$k};
	    if ($label{$k} == 1){$correct++;}
	    else{$wrong++;}
	}
	else{
	    print STDERR "($snid:$tnid) not wellformed! --> skip\n"
		if ($self->{-verbose});
	}
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
