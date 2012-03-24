package myGengo::Client::Object::Job;
use strict;
use warnings;

sub new_from_row ($$) {
  return bless {row => $_[1]}, $_[0];
} # new_from_row

sub row ($) {
  return $_[0]->{row};
} # row

sub job_id ($) {
  return $_[0]->row->get ('id');
} # job_id

sub source_lang ($) {
  return $_[0]->row->get ('source_lang');
} # source_lang

sub source_body ($) {
  return $_[0]->row->get ('source_body');
} # source_body

sub target_lang ($) {
  return $_[0]->row->get ('target_lang');
} # target_lang

sub target_body ($) {
  return $_[0]->row->get ('target_body');
} # target_body

sub status ($) {
  return $_[0]->row->get ('status');
} # status

sub updated ($) {
  return $_[0]->row->get ('updated');
} # updated

sub data ($) {
  return $_[0]->row->get ('data');
} # data

sub path ($) {
  my $self = shift;
  return "/job/" . $self->job_id;
} # path

sub as_jsonable ($) {
  my $self = shift;
  my $row = $self->row;
  return {
    id => $self->job_id,
    data => $row->get ('data'),
    updated => $self->updated,
  };
} # as_jsonable

1;
