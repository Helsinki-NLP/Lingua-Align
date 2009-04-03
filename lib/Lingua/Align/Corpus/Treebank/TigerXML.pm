package Lingua::Align::Corpus::Treebank::TigerXML;

use 5.005;
use strict;
use Lingua::Align::Corpus::Treebank;


use vars qw($VERSION @ISA);
$VERSION = '0.01';
@ISA = qw(Lingua::Align::Corpus::Treebank);

use FileHandle;
use XML::Parser;


sub new{
    my $class=shift;
    my %attr=@_;

    my $self={};
    bless $self,$class;

    foreach (keys %attr){
	$self->{$_}=$attr{$_};
    }

    return $self;
}


sub next_tree{
    my $self=shift;
    return $self->next_sentence(@_);
}

sub next_sentence{
    my $self=shift;
    my $tree=shift;

    my $file=shift || $self->{-file};
    if (! defined $self->{FH}->{$file}){
	$self->{FH}->{$file} = new FileHandle;
	$self->{FH}->{$file}->open("<$file") || die "cannot open file $file\n";
	$self->{__XMLPARSER__} = new XML::Parser(Handlers => 
						 {Start => \&__XMLTagStart,
						  End => \&__XMLTagEnd});
	$self->{__XMLHANDLE__} = $self->{__XMLPARSER__}->parse_start;
    }

    $self->{__XMLHANDLE__}->{SENTID}=undef;
    $self->{__XMLHANDLE__}->{SENT_ENDED}=0;

    my $fh=$self->{FH}->{$file};
    my $OldDel=$/;
    $/='>';
    while (<$fh>){
	eval { $self->{__XMLHANDLE__}->parse_more($_); };
	if ($@){
	    warn $@;
	    print STDERR $_;
	}
	last if ($self->{__XMLHANDLE__}->{SENT_ENDED});
    }
    $/=$OldDel;
    if (defined $self->{__XMLHANDLE__}->{SENTID}){
	$tree->{ROOTNODE}=$self->{__XMLHANDLE__}->{ROOTNODE};
	$tree->{NODES}=$self->{__XMLHANDLE__}->{NODES};
	$tree->{TERMINALS}=$self->{__XMLHANDLE__}->{TERMINALS};
	$tree->{ID}=$self->{__XMLHANDLE__}->{SENTID};
	return 1;
    }
    $self->close_file($file);
#    $fh->close;
    return 0;
}


##-------------------------------------------------------------------------
## 

sub __XMLTagStart{
    my ($p,$e,%a)=@_;

    if ($e eq 's'){
	$p->{SENT}=1;
	$p->{SENTID}=$a{id};
	$p->{NODES}={};        # need better clean-up?! (memory leak?)
	$p->{TERMINALS}=[];
    }
    elsif ($e eq 't'){
	push(@{$p->{TERMINALS}},$a{id});
	foreach (keys %a){
	    $p->{NODES}->{$a{id}}->{$_}=$a{$_};
	}
    }
    elsif ($e eq 'nt'){
	foreach (keys %a){
	    $p->{NODES}->{$a{id}}->{$_}=$a{$_};
	}
	$p->{CURRENT}=$a{id};
    }
    elsif ($e eq 'edge'){
	my $parent=$p->{CURRENT};
	my $child=$a{idref};
	my $rel=$a{label};
        # do I have to allow multiple parents? (->secondary edges?!)
	push(@{$p->{NODES}->{$child}->{PARENTS}},$parent);
	push(@{$p->{NODES}->{$parent}->{CHILDREN}},$child);
	$p->{REL}->{$child}->{$parent}=$rel;
	$p->{REL}->{$parent}->{$child}=$rel;
    }
    elsif ($e eq 'graph'){
	$p->{ROOTNODE}=$a{root};
    }
}

sub __XMLTagEnd{
    my ($p,$e)=@_;

    if ($e eq 's'){
	$p->{SENT_ENDED}=1;
    }
}





# Preloaded methods go here.

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

YADWA::Data::Trees::TigerXML - Perl extension for blah blah blah

=head1 SYNOPSIS

  use YADWA::Data::Trees::TigerXML;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for YADWA::Data::Trees::TigerXML, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.



=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

Joerg Tiedemann, E<lt>tiedeman@E<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 by Joerg Tiedemann

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.


=cut
