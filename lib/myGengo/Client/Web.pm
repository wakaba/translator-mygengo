package myGengo::Client::Web;
use strict;
use warnings;
use Data::Dumper;
use JSON::Functions::XS qw(json_bytes2perl);
use Web::UserAgent::Functions qw(http_post);

sub htescape ($) {
  my $s = $_[0];
  return '' unless defined $s;
  $s =~ s/&/&amp;/g;
  $s =~ s/\"/&quot;/g;
  $s =~ s/</&lt;/g;
  $s =~ s/>/&gt;/g;
  return $s;
} # htescape

sub price ($) {
  my $c = shift;
  return '$' . $c;
} # price

sub timestamp ($) {
  my $t = shift;
  return scalar (gmtime $t) . ' UTC';
} # timestamp

sub time_amount ($) {
  my $s = shift;
  if ($s <= 0) {
    return $s . 's';
  }

  my @v;
  if ($s % 60) {
    unshift @v, ($s % 60) . ' s';
  }
  $s = int ($s / 60);
  if ($s % 60) {
    unshift @v, ($s % 60) . ' min';
  }
  $s = int ($s / 60);
  if ($s) {
    unshift @v, $s . ' h';
  }
  return join ' ', @v;
} # time_amount

sub lang ($) {
  return {
    ja => 'Japanese',
    en => 'English',
    fr => 'French',
    es => 'Spanish',
    de => 'German',
    it => 'Italish',
  }->{$_[0]} || $_[0];
} # lang

sub author_type ($) {
  return ucfirst $_[0];
} # author_type

sub boolean ($) {
  return $_[0] ? 'Yes' : 'No';
} # boolean

sub header_html ($$) {
  my ($class, $app) = @_;
  return sprintf q{
    <header>
      <h1>myGengo Jobs</h1>
      <nav>
        <a href="/job/">Jobs</a>
        <a href="/account">Account</a>
      </nav>
    </header>
    <script>
      function toggleAction (id) {
        var el = document.getElementById (id);
        el.hidden = !el.hidden;
      } // toggleAction
    </script>

    %s
  }, $app->mygengo_webservice->is_production ? q{} : q{
    <div class=use-sandbox-warning>
      myGengo sandbox mode
    </div>
  };
} # header_html

sub options_html (;%) {
  my %args = @_;
  return (
    $args{with_any}
        ? '<option value="">Any'
        : ''
  ) . join '', map {
    sprintf '<option value="%s" class="%s-%s" %s>%s',
        htescape $_->[0],
        htescape $args{class_prefix} || '',
        htescape $_->[0],
        (defined $args{current_value} and $args{current_value} eq $_->[0]
             ? 'selected' : ''),
        htescape $_->[1],
  } @{$args{avail_options}};
} # options_html

sub lang_options_html (;%) {
  return options_html @_, avail_options => [
    map { [$_, lang $_] } qw(ja en fr es it de)
  ];
} # lang_options_html

sub status ($) {
  return {
    added => 'Added',
    available => 'Available',
    approved => 'Approved',
    held => 'Held',
    reviewable => 'Reviewable',
    cancelled => 'Cancelled',
  }->{$_[0]} || $_[0];
} # status

sub status_options_html (;%) {
  return options_html @_, avail_options => [
    map { [$_, status $_] } qw(reviewable available approved held)
  ], class_prefix => 'status';
} # status_options_html

sub sync_jobs_from_res ($;%) {
  my ($res, %args) = @_;
  return if $res->is_error;
  
  require myGengo::Client::MySQL;
  require Dongry::Database;
  my $db = Dongry::Database->load ('mygengo');

  my $job_group_id = $res->data->{group_id} || 0;
  
  my $repo_data = $args{callback_key_to_repo_data} || {};
  my @job_row;
  for my $job (@{$res->jobs || []}) {
    my $job_repo_data = $repo_data->{$job->{custom_data} || 0};
    my $job_repo_data_row;
    if (not $job_repo_data) {
      $job_repo_data_row = $db->table ('job_repo_data')->find
          ({job_id => $job->{job_id}}, source_name => 'master');
      if ($job_repo_data_row) {
        $job_repo_data = $job_repo_data_row->get ('repo_data') || {};
      } else {
        $job_repo_data = {};
      }
    }
    push @job_row, $db->table ('job')->insert ([{
      id => $job->{job_id},
      job_group_id => $job_group_id,
      callback_key => $job->{custom_data} || 0,
      source_lang => $job->{source}->{lang} // '',
      source_body => $job->{source}->{body} // '',
      target_lang => $job->{target}->{lang} // '',
      target_body => $job->{target}->{body} // '',
      job_created => $job->{ctime} || 0,
      status => $job->{status},
      data => {%$job},
      data_updated => time,
      repo_msgid => $job_repo_data->{msgid},
      repo_data => $job_repo_data,
      updated => time,
    }], duplicate => 'replace')->first_as_row;
    $db->table ('job_repo_data')->insert ([{
      job_id => $job->{job_id},
      repo_data => $job_repo_data,
    }], duplicate => 'ignore') unless $job_repo_data_row;
  }
  return \@job_row;
} # sync_jobs_from_res

sub process ($$) {
  my ($class, $app) = @_;
  my $http = $app->http;
  
  my $path = $app->path_segments;
  if (@$path == 2 and $path->[0] eq 'job') {
    if ($path->[1] eq '') {
      require Dongry::Database;
      require myGengo::Client::MySQL;
      require myGengo::Client::Object::Job;

      my $status = $app->bare_param ('status');
      my $source_lang = $app->bare_param ('source-lang');
      my $target_lang = $app->bare_param ('target-lang');
      my $group_id = $app->bare_param ('group-id');
      my $sort_key = $app->bare_param ('sort') || '';
      my $msgid = $app->bare_param ('msgid');

      my $db = Dongry::Database->load ('mygengo');
      my $jobs = $db->query
          (table_name => 'job',
           where => [
             ':status:optsub',
             status => {
               ($status ? (status => $status) : ()),
               ($source_lang ? (source_lang => $source_lang) : ()),
               ($target_lang ? (target_lang => $target_lang) : ()),
               ($group_id ? (job_group_id => $group_id) : ()),
               ($msgid ? (repo_msgid => {-infix => $msgid}) : ()),
             },
           ],
           order => [
             ($sort_key eq 'comments' ? (comments_updated => 'desc') : ()),
             updated => 'desc',
             job_created => 'desc',
           ],
           item_list_filter => sub {
             return $_[1]->map (sub {
               return myGengo::Client::Object::Job->new_from_row ($_);
             });
           })->find_all (offset => 0, limit => 100);

      my $job_trs = join '', map {
        my $target_html = htescape substr $_->target_body, 0, 100;
        if ($target_html eq '' and 
            $_->target_has_preview) {
          $target_html = sprintf q{<img src="%s">},
              $_->preview_path;
        }

        sprintf q{
            <tr class="status-%s">
              <th>
                <a href="%s">%d</a>
                <a href="%s" target=_blank class=newtab>[New tab]</a>
              <td class=lang-col>%s
              <td class=text-col lang="%s">%s
              <td class=lang-col>%s
              <td class=text-col lang="%s">%s
              <td>%s
        },
              htescape $_->status,
              htescape $_->path . ($sort_key eq 'comments' ? '#comments' : ''),
              $_->job_id,
              htescape $_->path . ($sort_key eq 'comments' ? '#comments' : ''),
              htescape lang $_->source_lang,
              htescape $_->source_lang,
              htescape (substr $_->source_body, 0, 100),
              htescape lang $_->target_lang,
              htescape $_->target_lang, $target_html,
              htescape status $_->status;
      } @$jobs;

      my $html = sprintf q{
          <!DOCTYPE HTML>
          <html lang=en>
          <title>Submitted jobs - myGengo job manager</title>
          <link rel=stylesheet href="/css/mygengo-client">
          %s

          <section>
            <h1>Submitted jobs</h1>

            <nav>
              <p>
                <strong>Status</strong>:
                <a href="/job/?status=reviewable" class=status-reviewable>Reviewable</a>
                <a href="/job/?status=approved" class=status-approved>Approved</a>
                <a href="/job/?status=available" class=status-available>Available</a>
            </nav>

            <table class=item-list>
              <thead>
                <tr>
                  <th rowspan=2><abbr title="Job ID">#</abbr>
                  <th colspan=2>
                    Source
                  <th colspan=2>
                    Target
                  <th rowspan=2>Status
                <tr>
                  <th class=lang-col><abbr title=Language>Lang</abbr>
                  <th class=text-col>Text
                  <th class=lang-col><abbr title=Language>Lang</abbr>
                  <th class=text-col>Text
              <tbody>
                %s
            </table>

            <nav class=panel>
              <form action="/job/" method=get>
                <table>
                  <caption>Filtering</caption>
                  <tbody>
                    <tr>
                      <th>Status
                      <td><select name=status>%s</select>
                    <tr>
                      <th>Source language
                      <td><select name=source-lang>%s</select>
                    <tr>
                      <th>Target language
                      <td><select name=target-lang>%s</select>
                    <tr>
                      <th>Job group <abbr title=ID>#</abbr>
                      <td><input type=number name=group-id value="%s">
                    <tr>
                      <th>Message ID
                      <td><input name=msgid value="%s">
                    <tr>
                      <th>Sort by
                      <td><select name=sort>%s</select>
                  <tfoot>
                    <tr>
                      <td colspan=2><button type=submit>Show</button>
                </table>
              </form>
            </nav>

            <section>
              <h2>Actions</h2>

              <menu>
                <li><a href=/job/submit>Submit new jobs</a>
                <li>
                  <a href="javascript:toggleAction('syncrecent')">
                    Sync recent jobs
                  </a>
                  <form action=/job/sync method=POST hidden
                      id=syncrecent class=details>
                    <button type=submit>
                      Sync recent jobs with myGengo server
                    </button>
                  </form>
                <li>
                  <a href="javascript:toggleAction('syncajob')">
                    Sync a job
                  </a>
                  <form method=POST hidden id=syncajob class=details>
                    <label>
                      Job #<input type=number value="" onchange="
                             this.form.action = '/job/' + this.value + '/sync';
                           " oninput="
                             this.form.action = '/job/' + this.value + '/sync';
                           " required>
                    </label>
                    <button type=submit>Sync with myGengo server</button>
                  </form>
              </menu>
            </section>
         </section>
        }, $class->header_html ($app), $job_trs,
            status_options_html (with_any => 1, current_value => $status),
            lang_options_html (with_any => 1, current_value => $source_lang),
            lang_options_html (with_any => 1, current_value => $target_lang),
            htescape $group_id || '',
            htescape $msgid || '',
            options_html (current_value => $sort_key, avail_options => [
              [job => 'Any update'],
              [comments => 'Comments'],
            ]);
      $app->send_html ($html);
      $app->throw;

    } elsif ($path->[1] =~ /\A[0-9]+\z/) {
      if ($http->request_method eq 'POST') {
        $app->requires_no_csrf;
        my $job_row = $app->requires_mygengo_job_row ($path->[1]);
        my $ws = $app->mygengo_webservice;

        my $action = $app->bare_param ('action') || '';
        if ($action eq 'approve') {
          my %param = (comment_for_translator => $app->text_param ('comment'),
                       comment_for_mygengo => $app->text_param ('comment-for-mygengo'),
                       comment_is_public => $app->text_param ('comment-is-public') || 0,
                       rating => $app->text_param ('rating'));
          my $res = $ws->job_approve ($path->[1], %param);
          $app->throw_mygengo_error ($res) if $res->is_error;

          my $db = Dongry::Database->load ('mygengo');
          $db->table ('job_approval')->create ({
            id => $db->bare_sql_fragment ('uuid_short()'),
            job_id => $path->[1],
            %param,
            #author_id => ...,
          });

          sync_jobs_from_res $ws->job_get ($path->[1]);
          $job_row = $job_row->reload;

          $class->sync_job_feedback ($app, $ws, $job_row);
          $class->sync_job_revisions ($app, $ws, $job_row);

          $class->post_approved_job_to_repo ($app, $job_row);

          $app->throw_redirect (q</job/> . $path->[1]);
        } elsif ($action eq 'reject') {
          my %param = (reason => $app->bare_param ('reason'),
                       follow_up => $app->text_param ('follow-up'),
                       comment_for_translator => $app->text_param ('comment'));
          my $res = $ws->job_reject
              ($path->[1],
               captcha => $app->text_param ('captcha'),
               %param);
          $app->throw_mygengo_error ($res) if $res->is_error;

          my $db = Dongry::Database->load ('mygengo');
          $db->table ('job_rejection')->create ({
            id => $db->bare_sql_fragment ('uuid_short()'),
            job_id => $path->[1],
            %param,
            #author_id => ...,
          });
          
          sync_jobs_from_res $ws->job_get ($path->[1]);
          $app->throw_redirect (q</job/> . $path->[1]);
        } elsif ($action eq 'cancel') {
          my $res = $ws->job_delete ($path->[1]);
          $app->throw_mygengo_error ($res) if $res->is_error;

          my $db = Dongry::Database->load ('mygengo');
          $db->table ('job_cancellation')->create ({
            id => $db->bare_sql_fragment ('uuid_short()'),
            job_id => $path->[1],
            #author_id => ...,
          });

          sync_jobs_from_res $ws->job_get ($path->[1]);
          $app->throw_redirect (q</job/> . $path->[1]);
        } # action

      } else {
        require myGengo::Client::Service::JobEventList;
        my $service = myGengo::Client::Service::JobEventList->new_from_job_id
            ($path->[1]);
        my $job = $service->job
            or $app->throw_error (404, reason_phrase => 'Job not found');

      my $target_html = htescape $job->target_body;
      if ($target_html eq '' and 
          $job->target_has_preview) {
        $target_html = sprintf q{<img src="%s">},
            $job->preview_path;
      }

      my $events_html = join '', $service->event_list->map (sub {
        my $event = $_;
        my $comment1 = $event->comment_for_translator;
        my $comment2 = $event->comment_for_mygengo;
        my $comment3 = $event->comment_for_customer;
        return sprintf q{
          <article class="event event-%s by-%s">
            <footer class=header>
              %s
            </footer>
            %s
            <footer class=footer>
              %s
            </footer class=footer>
          </article>
        },
            htescape $event->type,
            htescape $event->author_type,
            ('<p>' . htescape ($event->author_id
                                   ? $event->author_id .
                                     ' (' .
                                     (author_type $event->author_type) .
                                     ')'
                                   : author_type $event->author_type)) .
            ($event->not_found_at_server
                 ? '<p class=warning><strong>Not found at myGengo server!</strong>' : ''),
            (('<p>' . htescape $event->label) . 
             (defined $comment3 and length $comment3
                  ? '<p class=for-mygengo-customer><strong>For customer</strong>: ' .
                    htescape $comment3
                  : '') .
             (defined $comment1 and length $comment1
                  ? '<p class=for-mygengo-translator><strong>For myGengo translator</strong>: ' .
                    htescape $comment1
                  : '') .
             ($event->reason
                  ? '<p class=for-mygengo-translator><strong>Reason</strong>: ' .
                    htescape $event->reason : '') .
             (defined $comment2 and length $comment2
                  ? '<p class=for-mygengo-admin><strong>For myGengo admin</strong>: ' .
                    (htescape $comment2) .
                    ($event->comment_is_public ? ' (Public)' : '')
                  : '')) .
             ($event->follow_up
                  ? '<p><strong>Follow up</strong>: ' .
                    htescape $event->follow_up : ''),
            (htescape timestamp $event->timestamp) .
            ($event->client_record_id ? ' / #' . $event->client_record_id : '');
      })->join ('');

      my $feedback_html = '';
      if ($job->has_feedback) {
        $feedback_html = sprintf q{
          <section id=feedback>
            <h2>Feedback</h2>
            <p class=for-mygengo-translator><strong>For myGengo translator</strong>: %s (%s)
          </section>
        },
            htescape $job->feedback_comment_for_translator,
            htescape $job->feedback_rating;
      }

      my $html = sprintf q{ 
        <!DOCTYPE HTML>
        <html lang=en>
        <title>Job #%d - myGengo job manager</title>
        <link rel=stylesheet href="/css/mygengo-client">
        %s

        <section>
          <h1>Job #%d</h1>

          <nav>
            <a href="#actions">Actions</a>
            <a href="#comments">Events</a>
          </nav>

          <table class=prop-list>
            <tbody>
              <tr>
                <th colspan=2>Message ID
                <td><a href="%s">%s</a> %s
            <tbody>
              <tr>
                <th rowspan=3>Source
                <th>Language
                <td>%s
              <tr class=text-row>
                <th>Text
                <td lang="%s">%s
              <tr>
                <th>Unit count
                <td>%d
            <tbody class="status-%s">
              <tr>
                <th rowspan=3>Target
                <th>Language
                <td>%s
              <tr class=text-row>
                <th>Text
                <td lang="%s">%s
              <tr>
                <th>Is machine-translation
                <td>%s
            <tbody>
              <tr class="status-%s">
                <th rowspan=2>Status
                <th>Current
                <td>%s
              <tr>
                <th>Auto-approve
                <td>%s
              <tr>
                <th colspan=2>Group
                <td>%s
              <tr>
                <th colspan=2>Updated
                <td>%s
            <tbody>
              <tr>
                <th colspan=2>Quality level
                <td>%s
              <tr>
                <th colspan=2>Credit price
                <td>%s
              <tr>
                <th colspan=2>Estimated time
                <td>%s
            <tbody>
              <tr class=for-mygengo-customer>
                <th colspan=2>Notes (private)
                <td>%s
          </table>

          %s

          <section id=comments>
            <h2>Events</h2>

            %s
          </section>

          <section id=actions>
            <h2>Actions</h2>
  
            <menu>
              <li>
                <a href="javascript:toggleAction('addcomment')">
                  Add a comment
                </a>
                <form action="%s" method=post class=details id=addcomment
                    hidden>
                  <table class="prop-list">
                    <tbody>
                      <tr>
                        <th>Author
                        <td>Customer
                      <tr class=for-mygengo-translator>
                        <th>Comment for myGengo translator
                        <td><textarea name=comment required></textarea>
                    <tfoot>
                      <tr>
                        <td colspan=2>
                          <button type=submit>Post</button>
                  </table>
                </form>

              <li>
                <a href="javascript:toggleAction('approveform')">Approve</a>
                <form action="%s" method=POST class=details id=approveform
                    hidden>
                  <input type=hidden name=action value=approve>
                  <table class=prop-list>
                    <tbody>
                      <tr class=text-row>
                        <th>Text
                        <td>%s
                    <tbody>
                      <tr class=for-mygengo-translator>
                        <th>Rating
                        <td>
                          <input type=number name=rating
                              value=3.0 min=1.0 max=5.0 step=0.1>
                          (1.0 [bad] - 5.0 [good])
                      <tr class=for-mygengo-translator>
                        <th>Comment for myGengo translator
                        <td><textarea name=comment></textarea>
                      <tr class=for-mygengo-admin>
                        <th>Comment for myGengo admin
                        <td>
                          <textarea name=comment-for-mygengo></textarea>
                          <p><label>
                            <input type=checkbox name=comment-is-public value=1>
                            Public
                          </label>
                    <tbody>
                      <tr class=for-mygengo-customer>
                        <th>Message ID
                        <td><input name=msgid value="%s">
                      <tr class=for-mygengo-customer>
                        <th>Message arguments
                        <td><input name=msgargs value="%s">
                      <tr class=for-mygengo-customer>
                        <th>Notes
                        <td><textarea name=comment-for-customer>%s</textarea>
                    <tfoot>
                      <tr>
                        <td colspan=2>
                          <button type=submit %s>
                            Approve the text
                          </button>
                  </table>
                </form>

              <li>
                <a href="javascript:toggleAction('rejectform')">Reject</a>
                <form action="%s" method=POST class=details id=rejectform
                    hidden>
                  <input type=hidden name=action value=reject>
                  <table class=prop-list>
                    <tbody>
                      <tr class=for-mygengo-translator>
                        <th>Reason of rejection
                        <td>
                          <select name=reason>
                            <option value=quality>Quality
                            <option value=incomplete>Incomplete
                            <option value=other>Other reason
                          </select>
                      <tr class=for-mygengo-translator>
                        <th>Comment for myGengo translator
                        <td><textarea name=comment required></textarea>
                      <tr>
                        <th>Follow-up
                        <td>
                          <select name=follow-up>
                            <option value=requeue>Requeue for revision
                            <option value=cancel>Cancel the job
                          </select>
                      <tr>
                        <th><img src="%s" onload="
                          this.removeAttribute ('alt');
                        " alt="CAPTCHA image error">
                        <td><input name=captcha autocomplete=off
                            placeholder="Input the shown text" required>
                    <tfoot>
                      <tr>
                        <td colspan=2>
                          <button type=submit %s>
                            Reject the text
                          </button>
                  </table>
                </form>

              <li>
                <a href="javascript:toggleAction('cancelform')">Cancel</a>
                <form action="%s" method=post
                    class=details id=cancelform hidden>
                  <input type=hidden name=action value=cancel>
                  <button type=submit %s>Cancel the job</button>
                </form>

              <li>
                <a href="javascript:toggleAction('syncform')">Sync the job</a>
                <form action="%s" method=post class=details id=syncform hidden>
                  <button type=submit>
                    Sync the job with myGengo server
                  </button>
                </form>
            </menu>
          </section>

          <section>
            <h2>Job data dump</h2>
            <pre>%s</pre>
          </section>
        </section>
      },
          $job->job_id,
          $class->header_html ($app),
          $job->job_id,
          htescape ($app->translator_repo->get_msg_permalink_url_as_string
                        (langs => [$job->source_lang, $job->target_lang],
                         msgid => $job->repo_data->{msgid})),
          htescape $job->repo_data->{msgid},
          htescape $job->repo_data->{msgargs},

          htescape lang $job->source_lang,
          htescape $job->source_lang, htescape $job->source_body,
          htescape $job->unit_count,

          htescape $job->status,
          htescape lang $job->target_lang,
          htescape $job->target_lang, $target_html,
          htescape boolean $job->target_is_machine_translation,

          htescape $job->status,
          htescape status $job->status,
          htescape boolean $job->auto_approve,
          ($job->job_group_id
               ? sprintf q{<a href="/job/?group-id=%d">#%d</a>},
                     $job->job_group_id, $job->job_group_id,
               : '(None)'),
          htescape timestamp $job->updated,

          htescape $job->tier,
          htescape price $job->credits,
          htescape time_amount $job->eta,
          htescape $job->repo_data->{comment_for_customer} // '',

          $feedback_html,

          $events_html,
          htescape $job->comment_post_path,

          htescape $job->action_path,
          $target_html,
          htescape $job->repo_data->{msgid},
          htescape $job->repo_data->{msgargs},
          htescape (join "\n\n",
                        '[mygengo:job:' . $job->job_id . ']',
                        ($job->job_group_id ?
                             ('[mygengo:jobgroup:' . $job->job_group_id . ']'):
                             ())),
          $job->is_approvable ? '' : 'disabled',

          htescape $job->action_path,
          htescape $job->captcha_image_url,
          $job->is_rejectable ? '' : 'disabled',
          htescape $job->action_path,
          $job->is_cancellable ? '' : 'disabled',
          htescape $job->sync_path,

          htescape Dumper $job->as_dumpable;
        $app->send_html ($html);
        $app->throw;
      } # request_method

    } elsif ($path->[1] eq 'sync') {
      $app->requires_request_method ({POST => 1});
      my $ws = $app->mygengo_webservice;
      
      my $res = $ws->job_list (count => 100);
      $app->throw_mygengo_error ($res) if $res->is_error;
      
      $res = $ws->jobs_get ([map { $_->{job_id} } @{$res->data}]);
      $app->throw_mygengo_error ($res) if $res->is_error;
      
      sync_jobs_from_res $res;
      $app->throw_redirect ('/job/');
    } elsif ($path->[1] eq 'submit') {
      if ($http->request_method eq 'POST' and $app->bare_param ('send')) {
        $app->requires_no_csrf;
        $app->requires_request_method ({POST => 1});
        my $ws = $app->mygengo_webservice;

        my $source_lang = $app->bare_param ('source-lang');
        my $target_lang = $app->bare_param ('target-lang');
        my $tier = $app->bare_param ('tier');

        my $callback_url = $ws->callback_url;
        require myGengo::Client::MySQL;
        require Dongry::Database;
        my $db = Dongry::Database->load ('mygengo');
        my $bodies = $app->text_param_list ('source-body');
        my $msgids = $app->text_param_list ('msgid');
        my $msgargses = $app->text_param_list ('msgargs');
        my $comment1s = $app->text_param_list ('comment-for-translator');
        my $comment2s = $app->text_param_list ('comment-for-customer');
        my $callback_keys = [];
        push @$callback_keys, 
            $db->execute ('select uuid_short () as uuid')->first->{uuid}
                for 0..$#$bodies;
        my $key_to_index = {map { $callback_keys->[$_] => $_ } 0..$#$bodies};
        my $key_to_repo_data = {map {
          my $i = $key_to_index->{$_};
          ($_ => {
            msgid => $msgids->[$i],
            msgargs => $msgargses->[$i],
            comment_for_customer => $comment2s->[$i],
          });
        } keys %$key_to_index};
        my $jobs = [map {
          $ws->create_job_request
              (source => {lang => $source_lang, body => $bodies->[$_]},
               target => {lang => $target_lang},
               tier => $tier,
               comment => $comment1s->[$_],
               callback_url => $callback_url,
               custom_data => $callback_keys->[$_]);
        } 0..$#$bodies];
        my $res = $ws->job_post
            ($jobs, as_group => (@$jobs > 1 && $app->bare_param ('as-group')));
        $app->throw_mygengo_error ($res) if $res->is_error;
        my $job_rows = sync_jobs_from_res $res,
            callback_key_to_repo_data => $key_to_repo_data; # XXX author_id => ...

        $class->sync_job_comments ($app, $ws, $_) for @$job_rows;

        if ($res->data->{group_id}) {
          $app->throw_redirect ('/job/?group-id=' . $res->data->{group_id});
        } else {
          $app->throw_redirect ('/job/' . $res->jobs->[0]->{job_id});
        }
      } else {
        my $input_json = $app->bare_param ('from-repo');
        if ($input_json) {
          $input_json = json_bytes2perl $input_json;
        }
        $input_json ||= {};

        my $source_lang = $input_json->{source_lang}
            || $app->bare_param ('source-lang') || '';
        my $target_lang = $input_json->{target_lang}
            || $app->bare_param ('target-lang') || '';

        my $items = $input_json->{items} || [];
        $items = [map {
          my $tags = {map { $_ => 1 } @{$_->{tags} || []}};
          my $source = $_->{source_body} // '';
          $source =~ s/(%[0-9]+)/[[[$1: variable]]]/g;
          +{
            msgid => $_->{msgid},
            msgargs => $_->{msgargs},
            source_body => $source,
            comment_for_translator => (join "\n\n",
                ($tags->{countable} ? 'Countable (plural / singular required)':
                 $tags->{plural} ? 'Plural':
                 $tags->{singular} ? 'Singular' : '')),
            comment_for_customer => (join "\n\n",
                ($_->{target_body} ? 'Current text: ' . $_->{target_body}
                                   : ''),
                (map { $_->{text} } grep { $_->{important} }
                 @{$_->{comments} || []})),
          };
        } @$items];
        unless (@$items) {
          push @$items, {
            msgid => '',
            msgargs => '',
            source_body => '',
            comment_for_translator => '',
            comment_for_customer => '',
          };
        }

        my $items_html = join '', map {
          sprintf q{
            <tr>
              <th colspan=3>
                <span class=for-mygengo-customer>%s %s</span>
                <input type=hidden name=msgid value="%s">
                <input type=hidden name=msgargs value="%s">
                <button type=button onclick="
                  if (!confirm (this.getAttribute ('data-confirm'))) return;
                  var tr = this.parentNode.parentNode;
                  tr.parentNode.removeChild (tr.nextSibling);
                  tr.parentNode.removeChild (tr);
                  updateUnitCount (this.form);
                " data-confirm="Delete this item?">Delete</button>
            <tr>
              <td class="for-mygengo-translator text-col">
                <textarea name=source-body required>%s</textarea>
              <td class="for-mygengo-translator comment-col">
                <textarea name=comment-for-translator>%s</textarea>
              <td class="for-mygengo-customer comment-col">
                <textarea name=comment-for-customer>%s</textarea>
          }, 
              htescape $_->{msgid}, htescape $_->{msgargs},
              htescape $_->{msgid}, htescape $_->{msgargs},
              htescape $_->{source_body},
              htescape $_->{comment_for_translator},
              htescape $_->{comment_for_customer};
        } @$items;

        my $html = sprintf q{
          <!DOCTYPE HTML>
          <html lang=en>
          <title>Submit new jobs - myGengo job manager</title>
          <link rel=stylesheet href="/css/mygengo-client">
          %s

          <section>
            <h1>Submit new jobs</h1>

            <form action="/job/submit" method=POST onsubmit="
              return confirm (this.getAttribute ('data-confirm'));
            " data-confirm="Submit these jobs?" oninput="
              updateUnitCount (this);
            " class=job-submit-form>
              <table class="job-submit-texts">
                <thead>
                  <tr>
                    <th class="for-mygengo-translator text-col">Texts
                    <th class="for-mygengo-translator comment-col">
                      Comment for myGengo translator
                    <th class="for-mygengo-customer comment-col">
                      Notes (private)
                <tbody>
                  %s
                <tfoot>
                  <tr>
                    <td colspan=3><button type=button onclick="
                      var table = this.parentNode.parentNode.parentNode.parentNode;
                      var tr = document.createElement ('tr');
                      tr.innerHTML = table.getAttribute ('data-template-1');
                      table.tBodies[0].appendChild (tr);
                      var tr = document.createElement ('tr');
                      tr.innerHTML = table.getAttribute ('data-template-2');
                      table.tBodies[0].appendChild (tr);
                    ">Add</button>
              </table>
              <script>
                var tables = document.querySelectorAll ('table');
                var table = tables[tables.length - 1];
                var trHTML = table.getElementsByTagName ('tr')[1].innerHTML;
                table.setAttribute ('data-template-1', trHTML);
                var trHTML = table.getElementsByTagName ('tr')[2].innerHTML;
                table.setAttribute ('data-template-2', trHTML);
              </script>

              <table class=prop-list>
                <tbody>
                  <tr>
                    <th>Source language
                    <td>
                      <select name=source-lang onchange="
                        updateUnitCount (this.form);
                      ">%s</select>
                  <tr>
                    <th>Target language
                    <td><select name=target-lang>%s</select>
                  <tr>
                    <th>Quality level
                    <td>
                      <select name=tier>
                        <option value=machine>Machine
                        <option value=standard>Standard
                        <option value=pro>Pro
                        <option value=ultra>Ultra
                      </select>
                  <tr>
                    <th>Grouping
                    <td><label>
                      <input type=checkbox name=as-group checked value=1>
                      Submit as a group
                    </label>
                <tfoot>
                  <tr>
                    <th>Unit count
                    <td>
                      <output id=unit-count></output>
                      <script>
                        function updateUnitCount (form) {
                          var els = form.elements;
                          var unitType = {
                            ja: 'char',
                            zh: 'char'
                          }[els['source-lang'].value] || 'word';
                          var count = 0;
                          for (var i = 0; i < els.length; i++) {
                            var el = els[i];
                            if (el.name == 'source-body') {
                              var value = el.value.replace
                                  (/\[\[\[.*?\]\]\]/g, '');
                              if (unitType == 'char') {
                                value = value.replace (/\s+/g, '');
                                count += value.length;
                              } else {
                                count += value.split (/\s+/).length;
                              }
                            }
                          }
                          document.getElementById ('unit-count').textContent
                              = count;
                        } // updateUnitCount
                        updateUnitCount
                            (document.forms[document.forms.length - 1]);
                      </script>
                      <p class=info><a href="http://mygengo.com/how-it-works/pricing-languages/" target=_blank>Price</a>
                  <tr>
                    <td colspan=2>
                      <button type=submit name=send value=1>Submit</button>
              </table>
            </form>
          </section>
        }, $class->header_html ($app),
            $items_html,
            lang_options_html (current_value => $source_lang),
            lang_options_html (current_value => $target_lang);
        $app->send_html ($html);
        $app->throw;
      }
    } elsif ($path->[1] eq 'callback') {
      #warn Dumper $http->request_body_params;

      require WebService::myGengo::Lite;
      my $ws = WebService::myGengo::Lite->new;
      my $res = $ws->receive_callback
          (job => $app->bare_param ('job'),
           comment => $app->bare_param ('comment'));
      my $obj = $res->data->{job} || $res->data->{comment} || {};
      my $job_id = $obj->{job_id} or $app->throw_error (404);
      my $job_row = $app->requires_mygengo_job_row ($job_id)
          or $app->throw_error (404);

      my $key_from_db = $job_row->get ('callback_key');
      if (not $obj->{custom_data} or
          not $key_from_db or
          $obj->{custom_data} ne $key_from_db) {
        $app->throw_error (403);
      }

      $class->sync_job_by_id ($app, $job_id, job_row => $job_row);

      $app->send_plain_text ('Thanks!');
      $app->throw;
    }

  } elsif (@$path == 3 and
           $path->[0] eq 'job' and
           $path->[1] =~ /\A[0-9]+\z/) {
    if ($path->[2] eq 'preview') {
      my $ws = $app->mygengo_webservice;
      $app->throw_redirect ($ws->job_preview_url ($path->[1]));
      #my $res = $ws->job_preview ($path->[1]);
      #$app->throw_code (404) if $res->is_error;
      #$http->set_response_header ('Content-Type' => 'image/jpeg');
      #$http->send_response_body_as_ref (\($res->image_as_bytes));
      #$app->throw;
    } elsif ($path->[2] eq 'sync') {
      $app->requires_request_method ({POST => 1});
      $class->sync_job_by_id ($app, $path->[1]);
      $app->throw_redirect (q</job/> . $path->[1]);
    }

  } elsif (@$path == 4 and
           $path->[0] eq 'job' and
           $path->[1] =~ /\A[0-9]+\z/ and
           $path->[2] eq 'comment') {
    if ($path->[3] eq 'submit') {
      $app->requires_request_method ({POST => 1});
      my $ws = $app->mygengo_webservice;
      my $job_row = $app->requires_mygengo_job_row ($path->[1]);

      my $comment_body = $app->text_param ('comment');
      my $res = $ws->job_comment_post
          ($path->[1], comment_for_translator => $comment_body);
      $app->throw_mygengo_error ($res) if $res->is_error;

      my $db = Dongry::Database->load ('mygengo');
      $db->table ('customer_comment')->create ({
        id => $db->bare_sql_fragment ('uuid_short()'),
        job_id => $path->[1],
        body => $comment_body,
        #author_id => ...,
      });

      $class->sync_job_comments ($app, $ws, $job_row);
      $app->throw_redirect (q</job/> . $path->[1] . q<#comments>);
    }

  } elsif (@$path == 1 and $path->[0] eq 'account') {
    my $ws = $app->mygengo_webservice;

    my $stats = $ws->account_stats;
    $app->throw_mygengo_error ($stats) if $stats->is_error;

    my $balance = $ws->account_balance;
    $app->throw_mygengo_error ($balance) if $balance->is_error;

    my $html = sprintf q{
      <!DOCTYPE HTML>
      <html lang=en>
      <title>Account status information - myGengo job manager</title>
      <link rel=stylesheet href="/css/mygengo-client">
      %s

      <section>
        <h1>Account status information</h1>

        <table class=prop-list>
          <tbody>
            <tr>
              <th>Registered
              <td>%s
            <tr>
              <th>Credits spent
              <td>%s
            <tr>
              <th>Credits available
              <td>%s
        </table>
      </section>
    },
        $class->header_html ($app),
        htescape timestamp $stats->data->{user_since},
        htescape price $stats->data->{credits_spent},
        htescape price $balance->data->{credits};
    $app->send_html ($html);
    $app->throw;

  } elsif (@$path == 2 and $path->[0] eq 'css') {
    if ($path->[1] eq 'mygengo-client') {
      $http->set_response_header ('Content-Type' => 'text/css; charset=utf-8');
      $http->send_response_body_as_text (q{
        h1, h2 {
          color: white;
          padding: 0.2em 0.4em;
        }

        h1 {
          font-size: 150%;
          border-top-right-radius: 0.5em;
        }
        h2 {
          font-size: 130%;
          border-top-left-radius: 0.5em;
          border-top-right-radius: 0.5em;
        }

        header {
          display: block;
          position: relative;
          background-color: #558100;
          color: white;
          padding: 0.4em;
          border-radius: 0.5em;
          box-shadow: 0.2em 0.2em #eee;
        }
        header h1 {
          background-color: transparent;
          margin: 0;
        }
        header nav {
          display: block;
          position: absolute;
          top: 0.8em;
          right: 0.8em;
          margin: 0;
          padding: 0.4em;
          background-color: white;
          border-radius: 0.4em;
        }
        header nav a {
          margin-left: 0.5em;
          margin-right: 0.5em;
          letter-spacing: 0.2em;
        }

        section > h1, h2 {
          background-color: #558100;
          background: -webkit-gradient(linear, left bottom, right top,  
                                       from(#558100), to(#89ca67));
          background: -moz-linear-gradient(left bottom, 
                                           #558100, #89ca67);
        }

        section {
          display: block;
          margin: 1em;
        }

        nav {
          display: block;
          margin: 0 0 0 1em;
          text-align: right;
          font-size: 90%;
          padding: 0.3em;
        }
        nav p {
          margin: 0;
        }

        table {
          margin: 0;
          padding: 0 0 0 1em;
          width: 100%;
        }

        nav.panel {
          background-color: #efefef;
          margin: 0.5em;
          margin-left: auto;
          padding: 0.6em 0.4em;
          width: 30%;
          border-radius: 0.9em;
          font-size: 80%;
        }

        nav.panel table {
          margin: 0;
          padding: 0;
          border-spacing: 2px;
        }

        nav.panel table caption {
          padding: 0.3em;
          font-weight: bolder;
          background-color: #89ca67;
          color: white;
          border: 2px #efefef solid;
        }

        nav.panel table th {
          width: 40%;
          line-height: 1;
        }

        .item-list tbody tr:nth-child(2n) {
          background-color: #f6FFce;
        }

        th, td {
          min-height: 2em;
        }

        form table th {
          width: 30%;
        }

        th {
          background-color: #89ca67;
          color: #fff;
          line-height: 1.5;
        }
        th:first-child {
          text-align: left;
        }
        thead th:first-child {
          text-align: center;
        }
        tbody th {
          text-align: left;
        }
        td p {
          margin: 0;
        }
        th a {
          color: inherit;
        }
        th a:hover {
          color: black;
        }
        th a.newtab {
          display: block;
          text-align: right;
          font-size: 70%;
          font-weight: normal;
          white-space: nowrap;
          text-decoration: none;
        }
        th a.newtab:hover {
          text-decoration: underline;
        }

        th, td {
          padding: 0.2em;
        }

        td input:not([type]),
        td input[type=number],
        td textarea,
        td select {
          width: 100%;
          box-sizing: border-box;
        }

        tfoot td {
          text-align: center;
          padding: 0.5em;
        }
        
        tfoot th + td {
          text-align: left;
        }

        .item-list .text-col {
          width: 40%;
        }
        .item-list td.text-col {
          font-size: 80%;
          overflow: hidden;
        }

        .prop-list th, .prop-list td {
          border: 3px solid transparent;
        }
        .prop-list th {
          width: 25%;
          vertical-align: top;
        }
        .prop-list th[rowspan] {
          width: auto;
        }

        .prop-list .text-row td {
          font-size: 150%;
          white-space: pre-wrap;
        }

        .job-submit-form {
          margin: 1em;
        }

        .job-submit-texts {
          border-collapse: collapse;
          border: 3px solid #89ca67;
        }

        .job-submit-texts thead th {
          background-color: #89ca67;
          color: white;
        }

        .job-submit-texts tr:nth-child(4n+3),
        .job-submit-texts tr:nth-child(4n+4) {
          background-color: #f6FFce;
        }
        .job-submit-texts tr:nth-child(4n+2),
        .job-submit-texts tr:nth-child(4n+4) {
          border-bottom: 3px solid #89ca67;
        }

        .job-submit-texts tbody th {
          background-color: transparent;
          color: inherit;
        }

        .job-submit-texts tbody th button {
          float: right;
        }

        .job-submit-texts td + td {
          text-align: center;
        }

        .job-submit-texts .text-col {
          width: 50%;
        }

        .job-submit-texts .comment-col {
          width: 25%;
        }

        .job-submit-texts tfoot td {
          text-align: right;
        }

        .job-submit-form table {
          margin-bottom: 0.5em;
          padding: 0;
        }

        menu {
          margin: 0 0 10em 1em;
          padding: 0;
        }

        menu li {
          display: block;
          margin: 0 0 0.3em 0;
          padding: 0;
        }

        menu li::before {
          content: "\261E  "
        }

        menu li > a {
          font-size: 150%;
        }

        menu .details {
          background-color: #efefef;
          margin: 0.5em;
          padding: 0.6em;
          border-radius: 0.9em;
        }

        .details table {
          margin: 0;
          padding: 0.6em;
          border-radius: 0.9em;
        }

        #feedback p {
          padding: 0.4em;
        }

        .event {
          position: relative;
          margin: 1em;
          border: 0.3em #89ca67 solid;
          border-radius: 0.5em;
          padding: 0.5em;
        }

        .event.by-customer {
          margin-left: 6em;
          box-shadow: 0.3em 0.3em #efefef;
        }
        .event.by-worker {
          margin-right: 6em;
          box-shadow: -0.3em 0.3em #efefef;
        }

        .event p {
          margin: 0.5em 0;
          padding: 0.4em;
        }

        .event footer {
          margin: 0.5em 0;
          font-size: 90%;
        }

        .event .header {
          background-color: transparent;
          color: black;
          box-shadow: none;
          font-weight: bolder;
        }

        .event .header p {
          position: absolute;
        }
        .event.by-customer .header p {
          left: -6em;
        }
        .event.by-worker .header p {
          right: -6em;
        }

        .event.by-customer .header p::after {
          content: "\261E  ";
        }
        .event.by-worker .header p::before {
          content: "\261C  ";
        }

        .event .footer {
          color: gray;
          text-align: right;
        }

        .event footer p {
          margin: 0;
        }

        textarea {
          height: 5em;
        }

        button {
          min-width: 5em;
          padding: 0.3em;
        }

        pre {
          white-space: pre-wrap;
          background-color: #f7fff7;
          padding: 0.5em;
        }

        a:hover {
          background-color: #f7fff7;
        }

        a[href^="#"] {
          text-decoration: none;
          padding-bottom: 2px;
          border-bottom: 1px dashed;
        }

        .use-sandbox-warning {
          margin: 0.5em;
          border: 0.3em solid red;
          padding: 0.3em;
          font-size: 160%;
          text-align: center;
          background-color: #ffefe5;
        }

        .status-reviewable {
          background-color: #ffefe5;
        }

        .item-list tbody tr.status-reviewable {
          background-color: #FFF8F9;
        }
        .item-list tbody tr.status-reviewable:nth-child(2n) {
          background-color: #ffefe5;
        }

        .info {
          text-align: right;
        }

        .for-mygengo-customer {
          background-color: #ffefe5;
        }
        .for-mygengo-customer th,
        .for-mygengo-customer td {
          border: #ffefe5 3px solid;
        }
        .for-mygengo-translator {
          background-color: #E5F5FA;
        }
        .for-mygengo-translator th,
        .for-mygengo-translator td {
          border: #E5F5FA 3px solid;
        }
        .for-mygengo-admin {
          background-color: #fafafa;
        }
        .for-mygengo-admin th,
        .for-mygengo-admin td {
          border: #fafafa 3px solid;
        }
      });
      $app->throw;
    }
  }
  $app->throw_error (404);
} # process

sub sync_job_by_id ($$$;%) {
  my ($class, $app, $job_id, %args) = @_;
  my $ws = $app->mygengo_webservice;
  my $res = $ws->job_get ($job_id);
  $app->throw_mygengo_error ($res) if $res->is_error;

  sync_jobs_from_res $res;
  my $job_row = $args{job_row} || $app->requires_mygengo_job_row ($job_id);

  $class->sync_job_comments ($app, $ws, $job_row);
  $class->sync_job_feedback ($app, $ws, $job_row);
  $class->sync_job_revisions ($app, $ws, $job_row);
} # sync_job_by_id

sub sync_job_comments ($$$$) {
  my ($class, $app, $ws, $job_row) = @_;
  
  my $res = $ws->job_comments ($job_row->get ('id'));
  $app->throw_mygengo_error ($res) if $res->is_error;
  
  my $comments = $res->data->{thread};
  if ($comments and ref $comments eq 'ARRAY' and @$comments) {
    $job_row->update ({
      comments => $comments,
      comments_updated => time,
    });
  }
} # sync_job_comments

sub sync_job_feedback ($$$$) {
  my ($class, $app, $ws, $job_row) = @_;
  
  my $res = $ws->job_feedback ($job_row->get ('id'));
  $app->throw_mygengo_error ($res) if $res->is_error;
  
  my $feedback = $res->data->{feedback};
  if ($feedback and ref $feedback eq 'HASH') {
    $job_row->update ({
      feedback => $feedback,
      feedback_updated => time,
    });
  }
} # sync_job_feedback

sub sync_job_revisions ($$$$) {
  my ($class, $app, $ws, $job_row) = @_;
  
  my $job_id = $job_row->get ('id');
  my $res = $ws->job_revision_list ($job_id);
  $app->throw_mygengo_error ($res) if $res->is_error;

  my $revs = $res->data->{revisions};
  if ($revs and ref $revs eq 'ARRAY') {
    my $value = $job_row->get ('revisions') || {};
    $value->{ids} = [map { $_->{rev_id} } @$revs];
    
    for (@{$value->{ids}}) {
      unless ($value->{rev}->{$_}) {
        my $res = $ws->job_revision ($job_id, $_);
        if (not $res->is_error and
            $res->data and ref $res->data eq 'HASH' and
            $res->data->{revision} and ref $res->data->{revision} eq 'HASH') {
          $value->{rev}->{$_} = $res->data->{revision};
        }
      }
    }
    
    $job_row->update ({
      revisions => $value,
      revisions_updated => time,
    });
  }
} # sync_job_revisions

sub post_approved_job_to_repo ($$$) {
  my ($class, $app, $job_row) = @_;
  
  my $msgid = $app->text_param ('msgid');
  my $body = $job_row->get ('target_body');
  if (defined $msgid and length $msgid and
      defined $body and length $body) {
    my $repo = $app->translator_repo;
    my $tag = $job_row->get ('job_group_id');
    $tag = $tag ? 'mygengo-jobgroup-' . $tag : undef;
    my ($req, $res) = http_post
        url => $repo->get_msg_update_url_as_string,
        header_fields => {
            Authorization => $repo->get_repo_authorization,
        },
        params => {
          api_key => $repo->get_msg_update_api_key,
          msgid => $msgid,
          msgargs => $app->text_param ('msgargs'),
          target_lang => $job_row->get ('target_lang'),
          body => $body,
          comment => $app->text_param ('comment-for-customer'),
          additional_tag => $tag,
        };
    if ($res->is_error) {
      $app->http->set_status (500);
      $app->send_plain_text ($res->status_line);
      $app->throw;
    }
  }
} # post_approved_job_to_repo

1;
