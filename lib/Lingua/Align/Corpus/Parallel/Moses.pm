

package Lingua::Align::Corpus::Parallel::Moses;

use 5.005;
use strict;

use vars qw($VERSION @ISA);
@ISA = qw(Lingua::Align::Corpus::Parallel::Bitext);

$VERSION = '0.01';

use Lingua::Align::Corpus;
use Lingua::Align::Corpus::Parallel::Bitext;


sub next_alignment{
    my $self=shift;
    my ($src,$trg,$links)=@_;

    my $file=$_[3] || $self->{-alignfile};
    my $encoding=$_[4] || $self->{-encoding};

    if (exists $self->{-src_file}){
	$self->{SRC}->next_sentence($src);
    }
    if (exists $self->{-trg_file}){
	$self->{TRG}->next_sentence($trg);
    }

    my $fh=$self->open_file($file,$encoding);

    if ($_=<$fh>){
	chomp;
	my @align = split(/\s+/);
	foreach my $l (@align){
	    my ($s,$t)=split(/\-/,$l);
	    $$links{$s}{$t}=1;
	}
	return 1;
    }
    return 0;    
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
