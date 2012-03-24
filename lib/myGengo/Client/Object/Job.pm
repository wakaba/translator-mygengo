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

sub target_has_preview ($) {
  return !!$_[0]->data->{target}->{preview_image_url};
} # target_has_preview

sub target_is_machine_translation ($) {
  return $_[0]->data->{target}->{is_machine_translation};
} # target_is_machine_translation

sub status ($) {
  return $_[0]->row->get ('status');
} # status

sub auto_approve ($) {
  return $_[0]->data->{auto_approve};
} # auto_approve

sub updated ($) {
  return $_[0]->row->get ('updated');
} # updated

sub tier ($) {
  return $_[0]->data->{tier};
} # tier

sub unit_count ($) {
  return $_[0]->data->{quote}->{unit_count};
} # unit_count

sub credits ($) {
  return $_[0]->data->{quote}->{credits};
} # credits

sub eta ($) {
  return $_[0]->data->{quote}->{eta};
} # eta

sub data ($) {
  return $_[0]->{data} ||= $_[0]->row->get ('data');
} # data

sub path ($) {
  my $self = shift;
  return "/job/" . $self->job_id;
} # path

sub preview_path ($) {
  my $self = shift;
  return "/job/" . $self->job_id . '/preview';
} # preview_path

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
