package Module::Build::DAGOLDEN;
use strict;
use Module::Build;
use vars qw/@ISA/;
BEGIN { @ISA = 'Module::Build' }
use IO::File;
use File::Spec;

sub ACTION_distdir {
    my $self = shift;
    $self->depends_on('wikidoc');
    $self->SUPER::ACTION_distdir;
}

sub ACTION_testpod {
    my $self = shift;
    $self->depends_on('wikidoc');
    $self->SUPER::ACTION_testpod;
}

sub ACTION_test {
    my $self = shift;
    my $missing_pod;
    for my $src ( keys %{ $self->find_pm_files() } ) {
        next unless _has_pod($src);
        (my $tgt = $src) =~ s{\.pm$}{.pod};
        $missing_pod = 1 if ! -e $tgt;
    }
    if ( $missing_pod ) {
        $self->depends_on('wikidoc');
        $self->depends_on('build');
    }
    $self->SUPER::ACTION_test;
}

sub ACTION_wikidoc {
    my $self = shift;
    eval "use Pod::WikiDoc";
    if ( $@ eq '' ) {
        my $parser = Pod::WikiDoc->new({ 
            comment_blocks => 1,
            keywords => { VERSION => $self->dist_version },
        });
        for my $src ( keys %{ $self->find_pm_files() } ) {
            next unless _has_pod( $src ); 
            (my $tgt = $src) =~ s{\.pm$}{.pod};
            $parser->filter( {
                input   => $src,
                output  => $tgt,
            });
            print "Creating $tgt\n";
            $tgt =~ s{\\}{/}g;
            $self->_add_to_manifest( 'MANIFEST', $tgt );
        }
    }
    else {
        warn "Pod::WikiDoc not available. Skipping wikidoc.\n";
    }
}

sub _has_pod {
    my ($file) = shift;
    my $fh = IO::File->new( $file );
    my $data = do {local $/; <$fh>};
    return $data =~ m{^=(?:pod|head\d|over|item|begin)\b}ms;
}

1;
