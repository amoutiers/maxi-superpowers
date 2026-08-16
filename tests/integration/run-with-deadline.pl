#!/usr/bin/env perl
use strict;
use warnings;
use POSIX qw(:sys_wait_h);

my ($timeout_seconds, $grace_seconds, @command) = @ARGV;
shift @command if @command && $command[0] eq '--';

die "usage: run-with-deadline.pl <seconds> <grace-seconds> -- <command> [args...]\n"
  unless defined $timeout_seconds && defined $grace_seconds && @command;
die "timeout values must be positive integers\n"
  unless $timeout_seconds =~ /^[1-9][0-9]*$/ && $grace_seconds =~ /^[1-9][0-9]*$/;

sub exit_code {
  my ($status) = @_;
  return 0 if $status == 0;
  return 128 + ($status & 127) if $status & 127;
  return $status >> 8;
}

sub deadline_exit_code {
  my ($status, $timed_out) = @_;
  my $code = exit_code($status);
  return 124 if $timed_out && $code != 0;
  return $code;
}

sub signal_child_group {
  my ($signal, $child_pid) = @_;
  return 1 if kill $signal, -$child_pid;
  return kill $signal, $child_pid;
}

my $child_pid = fork();
die "fork failed: $!\n" unless defined $child_pid;

if ($child_pid == 0) {
  setpgrp(0, 0) or die "setpgrp failed: $!\n";
  exec @command or die "exec failed: $!\n";
}

my $deadline = time + $timeout_seconds;
my $term_deadline;
my $timed_out = 0;

while (1) {
  my $waited = waitpid($child_pid, WNOHANG);
  exit deadline_exit_code($?, $timed_out) if $waited == $child_pid;
  die "waitpid failed: $!\n" if $waited == -1;

  my $now = time;
  if (!$timed_out && $now >= $deadline) {
    if (signal_child_group('TERM', $child_pid)) {
      $timed_out = 1;
      $term_deadline = time + $grace_seconds;
    }
  } elsif ($timed_out && $now >= $term_deadline) {
    $waited = waitpid($child_pid, WNOHANG);
    exit deadline_exit_code($?, $timed_out) if $waited == $child_pid;
    die "waitpid failed: $!\n" if $waited == -1;

    signal_child_group('KILL', $child_pid);
    waitpid($child_pid, 0);
    exit deadline_exit_code($?, $timed_out);
  }

  select undef, undef, undef, 0.05;
}
