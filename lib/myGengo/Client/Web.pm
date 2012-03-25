package myGengo::Client::Web;
use strict;
use warnings;
use Data::Dumper;

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
  }->{$_[0]} || $_[0];
} # lang

sub boolean ($) {
  return $_[0] ? 'Yes' : 'No';
} # boolean

sub header_html () {
  return sprintf q{
    <header>
      <h1>myGengo Jobs</h1>
      <nav>
        <a href="/job/">Jobs</a>
      </nav>
    </header>
  };
} # header_html

sub options_html (;%) {
  my %args = @_;
  return (
    $args{with_any}
        ? '<option value="">Any'
        : ''
  ) . join '', map {
    sprintf '<option value="%s" %s>%s',
        htescape $_->[0],
        (defined $args{current_value} and $args{current_value} eq $_->[0]
             ? 'selected' : ''),
        htescape $_->[1],
  } @{$args{avail_options}};
} # options_html

sub lang_options_html (;%) {
  return options_html @_, avail_options => [
    map { [$_, lang $_] } qw(ja en fr)
  ];
} # lang_options_html

sub status ($) {
  return {
    available => 'Available',
    approved => 'Approved',
    held => 'Held',
    reviewable => 'Reviewable',
  }->{$_[0]} || $_[0];
} # status

sub status_options_html (;%) {
  return options_html @_, avail_options => [
    map { [$_, status $_] } qw(reviewable available approved held)
  ];
} # status_options_html

sub sync_jobs_from_res ($) {
  my $res = shift;
  return if $res->is_error;
  
  require myGengo::Client::MySQL;
  require Dongry::Database;
  my $db = Dongry::Database->load ('mygengo');
  
  for my $job (@{$res->jobs || []}) {
    $db->table ('job')->insert ([{
      id => $job->{job_id},
      source_lang => $job->{source}->{lang} // '',
      source_body => $job->{source}->{body} // '',
      target_lang => $job->{target}->{lang} // '',
      target_body => $job->{target}->{body} // '',
      job_created => $job->{ctime},
      status => $job->{status},
      data => {%$job},
      updated => time,
    }], duplicate => 'replace');
  }
} # sync_jobs_from_res

sub process ($$) {
  my $app = $_[1];
  my $http = $app->http;
  
  my $path = $app->path_segments;
  if (@$path == 2 and $path->[0] eq 'job') {
    if ($path->[1] eq '' or $path->[1] eq 'index.json') {
      require Dongry::Database;
      require myGengo::Client::MySQL;
      require myGengo::Client::Object::Job;

      my $status = $app->bare_param ('status');
      my $source_lang = $app->bare_param ('source-lang');
      my $target_lang = $app->bare_param ('target-lang');

      my $db = Dongry::Database->load ('mygengo');
      my $jobs = $db->query
          (table_name => 'job',
           where => [
             ':status:optsub',
             status => {
               ($status ? (status => $status) : ()),
               ($source_lang ? (source_lang => $source_lang) : ()),
               ($target_lang ? (target_lang => $target_lang) : ()),
             },
           ],
           order => [updated => 'desc', job_created => 'desc'],
           item_list_filter => sub {
             return $_[1]->map (sub {
               return myGengo::Client::Object::Job->new_from_row ($_);
             });
           })->find_all (offset => 0, limit => 100);

      if ($path->[1] eq 'index.json') {
        $app->send_json ($jobs->map (sub { $_->as_jsonable }));
      } else {
        my $job_trs = join '', map {
          my $target_html = htescape $_->target_body;
          if ($target_html eq '' and 
              $_->target_has_preview) {
            $target_html = sprintf q{<img src="%s">},
                $_->preview_path;
          }

          sprintf q{
            <tr>
              <th title="Updated: %s"><a href="%s">%d</a>
              <td>%s
              <td lang="%s">%s
              <td>%s
              <td lang="%s">%s
              <td>%s
          },
              htescape timestamp $_->updated,
              htescape $_->path,
              $_->job_id,
              htescape lang $_->source_lang,
              htescape $_->source_lang, htescape $_->source_body,
              htescape lang $_->target_lang,
              htescape $_->target_lang, $target_html,
              htescape status $_->status;
        } @$jobs;

        my $html = sprintf q{
          <!DOCTYPE HTML>
          <html lang=en>
          <title>Jobs</title>
          <link rel=stylesheet href="/css/mygengo-client">
          %s
          <h1>Jobs</h1>

          <nav>
            <p>
              <strong>Status</strong>:
              <a href="/job/?status=reviewable">Reviewable</a>
              <a href="/job/?status=approved">Approved</a>
              <a href="/job/?status=available">Available</a>
              <a href="/job/?status=held">Held</a>
          </nav>

          <table>
            <thead>
              <tr>
                <th rowspan=2><abbr title="Job ID">#</abbr>
                <th colspan=2>
                  Source
                <th colspan=2>
                  Target
                <th rowspan=2>Status
              <tr>
                <th><abbr title=Language>Lang</abbr>
                <th>Text
                <th><abbr title=Language>Lang</abbr>
                <th>Text
            <tbody>
              %s
          </table>

          <nav>
            <form action="/job/" method=get>
              <table>
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
                <tfoot>
                  <tr>
                    <td colspan=2><button type=submit>Show</button>
              </table>
            </form>
          </nav>

          <section>
            <h2>Actions</h2>

            <menu>
              <li><a href=/job/submit>Submit jobs</a>
              <li>
                <form action=/job/sync method=POST>
                  <button type=submit>
                    Sync recent jobs
                  </button>
                </form>
            </menu>
          </section>
        }, header_html, $job_trs,
            status_options_html (with_any => 1, current_value => $status),
            lang_options_html (with_any => 1, current_value => $source_lang),
            lang_options_html (with_any => 1, current_value => $target_lang);
        $app->send_html ($html);
      }
      $app->throw;
    } elsif ($path->[1] =~ /\A[0-9]+\z/) {
      require Dongry::Database;
      require myGengo::Client::MySQL;
      require myGengo::Client::Object::Job;

      my $db = Dongry::Database->load ('mygengo');
      my $row = $db->table ('job')->find ({id => $path->[1]});
      $app->throw_code (404) unless $row;
      my $job = myGengo::Client::Object::Job->new_from_row ($row);

      my $target_html = htescape $job->target_body;
      if ($target_html eq '' and 
          $job->target_has_preview) {
        $target_html = sprintf q{<img src="%s">},
            $job->preview_path;
      }
      
      my $html = sprintf q{ 
        <!DOCTYPE HTML>
        <html lang=en>
        <title>Job #%d</title>
        <link rel=stylesheet href="/css/mygengo-client">
        %s
        <h1>Job #%d</h1>
        <table>
          <tbody>
            <tr>
              <th rowspan=3>Source
              <th>Language
              <td>%s
            <tr>
              <th>Text
              <td lang="%s">%s
            <tr>
              <th>Unit count
              <td>%d
          <tbody>
            <tr>
              <th rowspan=3>Target
              <th>Language
              <td>%s
            <tr>
              <th>Text
              <td lang="%s">%s
            <tr>
              <th>Is machine-translation
              <td>%s
          <tbody>
            <tr>
              <th rowspan=2>Status
              <th>Current
              <td>%s
            <tr>
              <th>Auto-approve
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
        </table>

        <section>
          <h2>Actions</h2>

          <menu>
            <li>Approve:
              <form action="%s" method=POST>
                <table>
                  <tbody>
                    <tr>
                      <th>Comment
                      <td><textarea name=comment></textarea>
                  <tfoot>
                    <tr>
                      <td colspan=2>
                        <button type=submit>
                          Approve
                        </button>
                </table>
              </form>
            <li>Reject:
              <form action="%s" method=POST>
                <table>
                  <tbody>
                    <tr>
                      <th>Reason
                      <td>
                        <select name=reason>
                          <option value=quality>Quality
                          <option value=incomplete>Incomplete
                          <option value=other>Other
                        </select>
                    <tr>
                      <th>Follow-up
                      <td>
                        <select name=follow-up>
                          <option value=requeue>Requeue
                          <option value=cancel>Cancel
                        </select>
                    <tr>
                      <th>Comment
                      <td><textarea name=comment></textarea>
                    <tr>
                      <th><img src="%s">
                      <td><input name=captcha>
                  <tfoot>
                    <tr>
                      <td colspan=2>
                        <button type=submit>
                          Reject
                        </button>
                </table>
             </form>
          </menu>
        </section>

        <section>
          <h2>Job data dump</h2>
          <pre>%s</pre>
        </section>
      },
          $job->job_id,
          header_html,
          $job->job_id,
          htescape lang $job->source_lang,
          htescape $job->source_lang, htescape $job->source_body,
          htescape $job->unit_count,
          htescape lang $job->target_lang,
          htescape $job->target_lang, $target_html,
          htescape boolean $job->target_is_machine_translation,
          htescape status $job->status,
          htescape boolean $job->auto_approve,
          htescape timestamp $job->updated,
          htescape $job->tier,
          htescape price $job->credits,
          htescape time_amount $job->eta,
          htescape $job->approve_path,
          htescape $job->reject_path,
          htescape $job->captcha_image_url,
          htescape Dumper $job->data;
      $app->send_html ($html);
      $app->throw;
    } elsif ($path->[1] eq 'sync') {
      $app->requires_mygengo_keys_from_auth;
      $app->requires_request_method ({POST => 1});
      
      require WebService::myGengo::Lite;
      
      my $ws = WebService::myGengo::Lite->new
          (api_key => $http->request_auth->{userid},
           private_key => $http->request_auth->{password});
      
      my $res = $ws->job_list (count => 100);
      $app->throw_error (400) if $res->is_error;
      
      $res = $ws->jobs_get ([map { $_->{job_id} } @{$res->data}]);
      $app->throw_error (400) if $res->is_error;
      
      sync_jobs_from_res $res;
      $app->throw_redirect ('/job/');
    } elsif ($path->[1] eq 'submit') {
      if ($http->request_method eq 'POST') {
        $app->requires_no_csrf;
        $app->requires_mygengo_keys_from_auth;
        $app->requires_request_method ({POST => 1});
        
        require WebService::myGengo::Lite;
        
        my $ws = WebService::myGengo::Lite->new
            (api_key => $http->request_auth->{userid},
             private_key => $http->request_auth->{password});

        use Data::Dumper;
        my $job = $ws->create_job_request
            (source => {
               lang => $app->bare_param ('source-lang'),
               body => $app->text_param ('source-body'),
             },
             target => {
               lang => $app->bare_param ('target-lang'),
             },
             tier => $app->bare_param ('tier'));
        my $res = $ws->job_post ([$job]);
        unless ($res->is_error) {
          sync_jobs_from_res $res;
          $app->throw_redirect ('/job/' . $res->jobs->[0]->{job_id});
        } else {
          $http->set_status (400);
          $app->send_plain_text (Dumper {
            error_message => $res->error_message,
            error_details => $res->error_details,
          });
          $app->throw;
        }
      } else {
        my $html = sprintf q{
          <!DOCTYPE HTML>
          <html lang=en>
          <title>Submit jobs</title>
          <link rel=stylesheet href="/css/mygengo-client">
          %s
          <h1>Submit jobs</h1>

          <form action="/job/submit" method=POST>

            <section>
              <table>
                <tbody>
                  <tr>
                    <th rowspan=2>Source
                    <th>Language
                    <td>
                      <select name=source-lang>%s</select>
                  <tr>
                    <th>Text
                    <td>
                      <textarea name=source-body></textarea>
                <tbody>
                  <tr>
                    <th>Target
                    <th>Language
                    <td>
                      <select name=target-lang>%s</select>
                <tbody>
                  <tr>
                    <th colspan=2>Quality level
                    <td>
                      <select name=tier>
                        <option value=machine>Machine
                        <option value=standard>Standard
                        <option value=pro>Pro
                        <option value=ultra>Ultra
                      </select>
                <tfoot>
                  <tr>
                    <td colspan=3>
                      <button type=submit>
                        Submit
                      </button>
              </table>
            </section>

          </form>
        }, header_html, lang_options_html, lang_options_html;
        $app->send_html ($html);
        $app->throw;
      }
    }
  } elsif (@$path == 3 and
           $path->[0] eq 'job' and
           $path->[1] =~ /\A[0-9]+\z/) {
    if ($path->[2] eq 'preview') {
      $app->requires_mygengo_keys_from_auth;
      require WebService::myGengo::Lite;
      my $ws = WebService::myGengo::Lite->new
          (api_key => $http->request_auth->{userid},
           private_key => $http->request_auth->{password});
      $app->throw_redirect ($ws->job_preview_url ($path->[1]));
      #my $res = $ws->job_preview ($path->[1]);
      #$app->throw_code (404) if $res->is_error;
      #$http->set_response_header ('Content-Type' => 'image/jpeg');
      #$http->send_response_body_as_ref (\($res->image_as_bytes));
      #$app->throw;
    } elsif ($path->[2] eq 'approve') {
      $app->requires_no_csrf;
      $app->requires_mygengo_keys_from_auth;
      $app->requires_request_method ({POST => 1});
      
      require WebService::myGengo::Lite;
      
      my $ws = WebService::myGengo::Lite->new
          (api_key => $http->request_auth->{userid},
           private_key => $http->request_auth->{password});
      my $res = $ws->job_approve
          ($path->[1],
           comment_for_translator => $app->text_param ('comment'));
      if ($res->is_error) {
        $http->set_status (400);
        $app->send_plain_text (Dumper {
          error_message => $res->error_message,
          error_details => $res->error_details,
        });
        $app->throw;
      } else {
        sync_jobs_from_res $ws->job_get ($path->[1]);
        $app->throw_redirect (q</job/> . $path->[1]);
      }
    } elsif ($path->[2] eq 'reject') {
      $app->requires_no_csrf;
      $app->requires_mygengo_keys_from_auth;
      $app->requires_request_method ({POST => 1});
      
      require WebService::myGengo::Lite;
      
      my $ws = WebService::myGengo::Lite->new
          (api_key => $http->request_auth->{userid},
           private_key => $http->request_auth->{password});
      my $res = $ws->job_reject
          ($path->[1],
           reason => $app->bare_param ('reason'),
           captcha => $app->text_param ('captcha'),
           follow_up => $app->text_param ('follow-up'),
           comment_for_translator => $app->text_param ('comment'));
      if ($res->is_error) {
        $http->set_status (400);
        $app->send_plain_text (Dumper {
          error_message => $res->error_message,
          error_details => $res->error_details,
        });
        $app->throw;
      } else {
        sync_jobs_from_res $ws->job_get ($path->[1]);
        $app->throw_redirect (q</job/> . $path->[1]);
      }
    }
  } elsif (@$path == 2 and $path->[0] eq 'css') {
    if ($path->[1] eq 'mygengo-client') {
      $http->set_response_header ('Content-Type' => 'text/css; charset=utf-8');
      $http->send_response_body_as_text (q{
        h1, h2 {
          background-color: #F9F9F9;
          color: black;
          padding: 0.2em 0.4em;
        }

        h1 {
          font-size: 150%;
        }
        h2 {
          font-size: 130%;
        }

        header {
          display: block;
          position: relative;
          border: 1px solid #AAAAAA;
          background-color: #F9F9F9;
          color: blank;
          padding: 0.4em;
        }
        header h1 {
          background-color: transparent;
          margin: 0;
        }
        header nav {
          display: block;
          position: absolute;
          top: 0.7em;
          right: 0.7em;
        }

        section {
          display: block;
          margin: 1em;
        }

        nav {
          display: block;
          text-align: right;
          font-size: 90%;
          padding: 0.3em;
        }
        nav p {
          margin: 0;
        }

        table {
          width: 100%;
        }

        nav table {
          width: 40%;
          margin-left: auto;
          margin-right: 0;
        }

        th {
          background-color: #F9F9F9;
          color: black;
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
        th, td {
          padding: 0.2em;
        }

        td input:not([type]),
        td textarea,
        td select {
          width: 100%;
        }

        textarea {
          height: 5em;
        }

        tfoot td {
          text-align: center;
        }

        menu li {
          padding: 0.3em;
        }

        pre {
          white-space: pre-wrap;
        }
      });
      $app->throw;
    }
  }
  $app->throw_error (404);
} # process

1;
