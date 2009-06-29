#

package Lingua::Align::Corpus::Parallel;

use 5.005;
use strict;

use vars qw($VERSION @ISA);
@ISA = qw(Lingua::Align::Corpus);

$VERSION = '0.01';

use Lingua::Align::Corpus;

use Lingua::Align::Corpus::Parallel::STA;
use Lingua::Align::Corpus::Parallel::Dublin;
use Lingua::Align::Corpus::Parallel::Giza;
use Lingua::Align::Corpus::Parallel::Moses;
use Lingua::Align::Corpus::Parallel::Bitext;
use Lingua::Align::Corpus::Parallel::OPUS;
use Lingua::Align::Corpus::Parallel::OrderedIds;



sub new{
    my $class=shift;
    my %attr=@_;

    if ($attr{-type}=~/(sta|stockholm)/i){
	return new Lingua::Align::Corpus::Parallel::STA(%attr);
    }
    if ($attr{-type}=~/dublin/i){
	return new Lingua::Align::Corpus::Parallel::Dublin(%attr);
    }
    if ($attr{-type}=~/giza/i){
	return new Lingua::Align::Corpus::Parallel::Giza(%attr);
    }
    if ($attr{-type}=~/moses/i){
	return new Lingua::Align::Corpus::Parallel::Moses(%attr);
    }
    if ($attr{-type}=~/opus/i){
	return new Lingua::Align::Corpus::Parallel::OPUS(%attr);
    }
    if ($attr{-type}=~/(ordered|id)/i){
	return new Lingua::Align::Corpus::Parallel::OrderedIds(%attr);
    }
    return new Lingua::Align::Corpus::Parallel::Bitext(%attr);
}



sub add_to_buffer{
    my $self=shift;
    my ($src,$trg,$links,$ids)=@_;

    print STDERR "buffering src\n" if ($self->{-verbose}>1);
    my $ret = $self->{SRC}->add_to_buffer($src);
    print STDERR "buffering trg\n" if ($self->{-verbose}>1);
    $ret += $self->{TRG}->add_to_buffer($trg);
    
    # also add links and ids to the buffer
    $links = {} if (not ref($links));
    $ids = [] if (not ref($ids));
    print STDERR "buffering links\n" if ($self->{-verbose}>1);
    $self->SUPER::add_to_buffer($links);
    print STDERR "buffering ids\n" if ($self->{-verbose}>1);
    $self->SUPER::add_to_buffer($ids);

    return $ret;
}




sub next_alignment{
    my $self=shift;
    my ($src,$trg,$links,$file,$enc,$ids)=@_;

    if (ref($self->{SRC}) && ref($self->{TRG})){
	if ($self->{SRC}->read_from_buffer($src)){
	    if ($self->{TRG}->read_from_buffer($trg)){
		$links = {} if (not ref($links));
		$ids = [] if (not ref($ids));
		$self->SUPER::read_from_buffer($ids);
		$self->SUPER::read_from_buffer($links);
		return 1;
	    }
	}
    }

    return $self->read_next_alignment(@_);
}



sub read_next_alignment{
    my $self=shift;
    my ($src,$trg)=@_;
    return 0 if (not $self->{SRC}->next_sentence($src));
    return 0 if (not $self->{TRG}->next_sentence($trg));
    return 1;
}





# read sentence ID pairs from external file

sub next_sentence_ids{
    my $self=shift;

    my $fh;
    if ($self->{-sent_id_file}){
	$fh=$self->open_file($self->{-sent_id_file});

	while (<$fh>){
	    chomp;
	    if (/^\#+\s+(.*)$/){
		my $files=$1;
		($self->{SRCFILE},$self->{TRGFILE}) = split(/\t/,$files);
	    }
	    else{
		my ($srcid,$trgid) = split(/\t/);
		return ($srcid,$trgid,$self->{SRCFILE},$self->{TRGFILE});
	    }
	}
    }
    return ();
}

sub print_alignments{}
sub print_header{}
sub print_tail{}

sub make_corpus_handles{
    my $self=shift;
    my %attr=@_;

    my %srcattr=();
    my %trgattr=();
    foreach (keys %attr){
	if (/\-src_(.*)$/){$srcattr{'-'.$1}=$attr{$_};}
	elsif (/\-trg_(.*)$/){$trgattr{'-'.$1}=$attr{$_};}
    }
    $self->{-src_type} = $attr{-src_type} || 'text';
    $self->{-trg_type} = $attr{-trg_type} || 'text';

    $self->{SRC}=new Lingua::Align::Corpus(%srcattr);
    $self->{TRG}=new Lingua::Align::Corpus(%trgattr);
}

sub close{
    my $self=shift;
    if (exists $self->{SRC}){
	$self->{SRC}->close();
    }
    if (exists $self->{TRG}){
	$self->{TRG}->close();
    }
}


sub src_treebankID{
    return 1;
}

sub trg_treebankID{
    return 2;
}


sub src_treebank{
    return $_[0]->{SRC}->{-file};
}

sub trg_treebank{
    return $_[0]->{TRG}->{-file};
}




1;
__END__

=head1 NAME

Lingua::Align::Corpus::Parallel - Perl extension for reading a simple parallel corpus (two corpus files, one for the source language, one for the target language); text on corresponding lines are aligned with each other

=head1 SYNOPSIS

  use Lingua::Align::Corpus::Parallel;

  my $corpus = new Lingua::Align::Corpus::Parallel(-srcfile => $srcfile,
                                                   -trgfile => $trgfile);

  my @src=();
  my @trg=();
  while ($corpus->next_alignment(\@src,\@trg)){
     print "src> ";
     print join(' ',@src);
     print "\ntrg> ";
     print join(' ',@trg);
     print "============================\n";
  }

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
