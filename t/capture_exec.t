#!/usr/bin/perl -w
#$Id: capture_exec.t,v 1.2 2004/11/21 16:09:29 simonflack Exp $
use strict;
use Test::More tests => 5;
use IO::CaptureOutput 'capture_exec';

my ($out, $err);
my @perl_e = ($^X, '-e'); # perl -e

($out, $err) = capture_exec(@perl_e, 'print "Hello World!"; print STDERR "PID=$$"');
is($out, 'Hello World!', 'capture_exec() caught stdout from external command');
like($err, qr/^PID=\d+/, 'capture_exec() caught stderr from external command');

# check exit code of system()
($out, $err) = capture_exec(@perl_e, 'print "ok"');
ok($out eq 'ok' && $? == 0, '$? set to 0 after successful execution');

($out, $err) = capture_exec(@perl_e, 'print STDERR "not ok"; exit 5');
ok($err eq 'not ok' && $? >> 8 == 5, '$? contains child error after failed execution');

# check that output is returned if called in scalar context
$out = capture_exec(@perl_e, 'print "stdout"; print STDERR "stderr"');
is($out, 'stdout', 'capture_exec() returns stdout in scalar context');
