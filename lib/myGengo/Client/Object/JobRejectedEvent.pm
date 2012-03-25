package myGengo::Client::Object::JobRejectedEvent;
use strict;
use warnings;
use myGengo::Client::Object::JobEvent;
push our @ISA, qw(myGengo::Client::Object::JobEvent);

sub new_from_row ($) {
  return bless {row => $_[1]}, $_[0];
} # new_from_row

sub row ($) {
  return $_[0]->{row};
} # row

sub type ($) {
  return 'job_rejected';
} # type

sub client_record_id ($) {
  my $row = $_[0]->row or return undef;
  return $row->get ('id');
} # client_record_id

sub author_id ($) {
  return $_[0]->row->get ('author_id');
} # author_id

sub author_type ($) {
  return 'customer';
} # author_type

sub label ($) {
  return 'Rejected the job';
} # label

sub timestamp ($) {
  return $_[0]->row->get ('created');
} # timestamp

sub comment_for_translator ($) {
  return $_[0]->row->get ('comment_for_translator');
} # comment_for_translator

sub reason ($) {
  return $_[0]->row->get ('reason');
} # reason

sub follow_up ($) {
  return $_[0]->row->get ('follow_up');
} # follow_up

1;
