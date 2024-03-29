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

sub is_approvable ($) {
  return $_[0]->status eq 'reviewable';
} # is_approvable

sub is_rejectable ($) {
  return $_[0]->status eq 'reviewable';
} # is_rejectable

sub is_cancellable ($) {
  return $_[0]->status eq 'available';
} # is_cancellable

sub auto_approve ($) {
  return $_[0]->data->{auto_approve};
} # auto_approve

sub job_group_id ($) {
  return $_[0]->row->get ('job_group_id');
} # job_group_id

sub created ($) {
  return $_[0]->row->get ('job_created');
} # created

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

sub captcha_image_url ($) {
  return $_[0]->data->{captcha_url};
} # captcha_image_url

sub data ($) {
  return $_[0]->{data} ||= $_[0]->row->get ('data');
} # data

sub synced_time ($) {
  return $_[0]->row->get ('data_updated');
} # synced_time

sub comments ($) {
  require List::Ish;
  require myGengo::Client::Object::Comment;
  return $_[0]->{comments}
      ||= List::Ish->new ([map {
            myGengo::Client::Object::Comment->new_from_hashref ($_)
          } @{$_[0]->row->get ('comments') || []}]);
} # comments

sub comments_synced_time ($) {
  return $_[0]->row->get ('comments_updated');
} # comments_synced_time

sub revisions ($) {
  require List::Ish;
  require myGengo::Client::Object::Revision;
  my $revs = $_[0]->row->get ('revisions') || {};
  return $_[0]->{revisions}
      ||= List::Ish->new ([map {
            my $v = $revs->{rev}->{$_} || {};
            myGengo::Client::Object::Revision->new_from_hashref ($v);
          } @{$revs->{ids} or []}]);
} # revisions

sub revisions_synced_time ($) {
  return $_[0]->row->get ('revisions_updated');
} # revisions_synced_time

sub feedback ($) {
  return $_[0]->{feedback} ||= $_[0]->row->get ('feedback') || {};
} # feedback

sub has_feedback ($) {
  return ($_[0]->feedback and keys %{$_[0]->feedback});
} # has_feedback

sub feedback_rating ($) {
  return $_[0]->feedback->{rating};
} # feedback_rating

sub feedback_comment_for_translator ($) {
  return $_[0]->feedback->{for_translator};
} # feedback_comment_for_translator

sub feedback_synced_time ($) {
  return $_[0]->row->get ('feedback_updated');
} # feedback_synced_time

sub repo_data ($) {
  return $_[0]->{repo_data} ||= $_[0]->row->get ('repo_data') || {};
} # repo_data

sub path ($) {
  my $self = shift;
  return "/job/" . $self->job_id;
} # path

sub preview_path ($) {
  my $self = shift;
  return "/job/" . $self->job_id . '/preview';
} # preview_path

sub action_path ($) {
  my $self = shift;
  return '/job/' . $self->job_id;
} # approve_path

sub sync_path ($) {
  my $self = shift;
  return '/job/' . $self->job_id . '/sync';
} # sync_path

sub comment_post_path ($) {
  my $self = shift;
  return '/job/' . $self->job_id . '/comment/submit';
} # comment_post_path

sub as_dumpable ($) {
  my $self = shift;
  my $row = $self->row;
  return {
    id => $self->job_id,
    data => $row->get ('data'),
    comments => $row->get ('comments'),
    feedback => $row->get ('feedback'),
    revisions => $row->get ('revisions'),
    repo_data => $row->get ('repo_data'),
  };
} # as_dumpable

1;
