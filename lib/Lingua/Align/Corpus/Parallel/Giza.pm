#
# constructor parameters:
#    -src_file ...... source language corpus file
#    -trg_file ...... target language corpus file
#    -src_type ...... corpus type, source language
#    -trg_type ...... corpus type, target language
#
#


package Lingua::Align::Corpus::Parallel::Giza;

use 5.005;
use strict;

use vars qw($VERSION @ISA);
@ISA = qw();

$VERSION = '0.01';

use Lingua::Align::Corpus;

sub new{
    my $class=shift;
    my %attr=@_;

    my $self={};
    bless $self,$class;

    foreach (keys %attr){
	$self->{$_}=$attr{$_};
    }

    $self->make_corpus_handles(%attr);

    return $self;
}


sub next_alignment{
    my $self=shift;
    my ($src,$trg)=@_;
    return 0 if (not $self->{SRC}->next_sentence($src));
    return 0 if (not $self->{TRG}->next_sentence($trg));
    return 1;
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
