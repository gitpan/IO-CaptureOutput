# $Id: CaptureOutput.pm,v 1.1 2004/11/21 16:09:29 simonflack Exp $
package IO::CaptureOutput;
use strict;
use vars qw/$VERSION @ISA @EXPORT_OK %EXPORT_TAGS/;
use Exporter;
@ISA = 'Exporter';
@EXPORT_OK = qw/capture capture_exec qxx/;
%EXPORT_TAGS = (all => \@EXPORT_OK);
$VERSION = '1.0'; # sprintf'%d.%02d', q$Revision: 1.1 $ =~ /: (\d+)\.(\d+)/;

sub capture (&@) {
    my ($code, $output, $error) = @_;
    for ($output, $error) {
        $_ = \do { my $s; $s = ''} unless ref $_;
        $$_ = '' unless defined($$_);
    }
    my $capture_out = new IO::CaptureOutput::_proxy('STDOUT', $output);
    my $capture_err = new IO::CaptureOutput::_proxy('STDERR', $error);
    &$code();
}

sub capture_exec {
    my @args = @_;
    my ($output, $error);
    capture sub {system @args}, \$output, \$error;
    return wantarray ? ($output, $error) : $output;
}

*qxx = \&capture_exec;

# Captures everything printed to a filehandle for the lifetime of the object
# and then transfers it to a scalar reference
package IO::CaptureOutput::_proxy;
use File::Temp 'tempfile';
use Symbol qw/gensym qualify qualify_to_ref/;
use Carp;

sub new {
    my $class = shift;
    my ($fh, $capture) = @_;
    $fh       = qualify($fh);         # e.g. main::STDOUT
    my $fhref = qualify_to_ref($fh);  # e.g. \*STDOUT

    # Duplicate the filehandle
    my $saved = gensym;
    open $saved, ">& $fh" or croak "Can't redirect <$fh> - $!";

    # Create replacement filehandle
    my $newio = gensym;
    (undef, my $newio_file) = tempfile;
    open $newio, "+> $newio_file" or croak "Can't create temp file for $fh - $!";

    # Redirect
    open $fhref, ">& ".fileno($newio) or croak "Can't redirect $fh - $!";

    bless [$$, $fh, $saved, $capture, $newio, $newio_file], $class;
}

sub DESTROY {
    my $self = shift;

    my ($pid, $fh, $saved) = @{$self}[0..2];
    return unless $pid eq $$; # only cleanup in the process that is capturing

    # restore the original filehandle
    my $fh_ref = Symbol::qualify_to_ref($fh);
    select((select ($fh_ref), $|=1)[0]);
    open $fh_ref, ">& ". fileno($saved) or croak "Can't restore $fh - $!";

    # transfer captured data to the scalar reference
    my ($capture, $newio, $newio_file) = @{$self}[3..5];
    seek $newio, 0, 0;
    $$capture = do {local $/; <$newio>};

    # Cleanup
    unlink $newio_file or carp "Couldn't remove temp file '$newio_file' - $!";
}

1;

=pod

=head1 NAME

IO::CaptureOutput - capture STDOUT/STDERR from subprocesses and XS/C modules

=head1 SYNOPSIS

    use IO::CaptureOutput qw(capture capture_exec qxx);

    my ($stdout, $stderr);
    capture sub {noisy(@args)}, \$stdout, \$stderr;
    sub noisy {
        my @args = @_;
        warn "this sub prints to stdout and stderr!";
        ...
        print "finished";
    }

    ($stdout, $stderr) = capture_exec('perl', '-e', 'print "Hello "; print STDERR "World!"');

=head1 DESCRIPTION

This module provides routines for capturing STDOUT and STDERR from forked
system calls (e.g. C<system()>, C<fork()>) and from XS/C modules.

=head1 FUNCTIONS

The following functions are be exported on demand.

=over 4

=item capture(\&subroutine, \$output, \$error)

Captures everything printed to C<STDOUT> and C<STDERR> for the duration of
C<&subroutine>. C<$output> and C<$error> are optional scalar references that
will contain C<STDOUT> and C<STDERR> respectively.

C<capture()> is able to trap output from subprocesses and C code, which
traditional C<tie()> methods are unable to capture.

B<Note:> C<capture()> will only capture output that has been written or flushed
to the filehandle.

=item capture_exec(@args)

Captures and returns the output from C<system(@args)>. In scalar context,
C<capture_exec()> will return what was printed to C<STDOUT>. In list context,
it returns what was printed to C<STDOUT> and C<STDERR>

    my $output = capture_exec('perl', '-e', 'print "hello world"');

    my ($output, $error) = capture_exec('perl', '-e', 'warn "Test"');

C<capture_exec> passes its arguments to C<CORE::system> it can take advantage
of the shell quoting, which makes it handy and slightly more portable
alternative to backticks, piped C<open()> and C<IPC::Open3>.

You can check the exit status of the C<system()> call with the C<$?>
variable. See L<perlvar> for more information.

=item qxx(@args)

An alias for C<capture_exec>.

=back

=head1 SEE ALSO

IPC::Open3

IO::Capture

IO::Utils

=head1 AUTHOR

Simon Flack E<lt>simonflk _AT_ cpan.orgE<gt>

=head1 COPYRIGHT

Copyright 2003 Simon Flack E<lt>simonflk _AT_ cpan.orgE<gt>.
All rights reserved

You may distribute under the terms of either the GNU General Public License or
the Artistic License, as specified in the Perl README file.

=cut
