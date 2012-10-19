#!/usr/bin/env perl
use 5.014;
use warnings;
no warnings qw(uninitialized);
use Mojolicious::Lite;
use Date::Format qw(time2str);
use Encode qw(encode);
use Storable;

our $VERSION = '0.00';

my $db_file = 'linktrack_db';
my %db;

sub load_db {
	if (-e $db_file) {
		my $db = retrieve($db_file);
		%db = %{$db};
	}
}

sub handle_request {
	my $self    = shift;
	my $station = $self->stash('station');
	my $via     = $self->stash('via');

	my @sites = split( /,/, $self->param('sites') // q{} );

	my $prev;
	my @dates;
	my @lectures = sort keys %{$db{lectures}};

	load_db;

	if (not $self->param('filter')) {
		for my $lecture (@lectures) {
			$self->param($lecture => 1);
		}
	}

	for my $time (sort keys $db{entries}) {
		my $date = time2str('%d.%m.%Y', $time);
		my @changes;
		for my $lecture (sort keys $db{entries}{$time}) {
			if ($self->param($lecture) == 0) {
				next;
			}
			for my $url (sort keys $db{entries}{$time}{$lecture}) {
				if (not exists $prev->{$lecture}{$url}) {
					push(@changes, {
						lecture_name => $lecture,
						lecture_url => $db{lectures}{$lecture},
						type => '+',
						link_name => $db{entries}{$time}{$lecture}{$url},
						link_url => $url,
					});
				}
			}
		}
		push(@dates, {date => $date, changes => \@changes});
		$prev = $db{entries}{$time};
	}
	@dates = reverse @dates;

	$self->render(
		'main',
		lectures => \@lectures,
		dates => \@dates,
		title => 'linktrack',
		version    => $VERSION,
	);
}

app->defaults( layout => 'default' );

get '/'               => \&handle_request;

app->config(
	hypnotoad => {
		accepts  => 10,
		listen   => ['http://*:8096'],
		pid_file => '/tmp/linktrack.uni.pid',
		workers  => 1,
	},
);

app->start();

__DATA__

@@ layouts/default.html.ep
<!DOCTYPE html>
<html>
<head>
<head>
	<title><%= $title %></title>
	<meta charset="utf-8">
	<style type="text/css">

	html {
		font-family: Sans-Serif;
	}

	div.outer {
		border: 0.2em solid #000066;
		width: 55em;
	}

	div.separator {
		border-bottom: 0.1em solid #000066;
	}

	div.about {
		font-family: Sans-Serif;
		color: #666666;
	}

	div.about a {
		color: #000066;
	}

	div.input-field {
		margin-top: 1em;
		clear: both;
	}

	span.fielddesc {
		display: block;
		float: left;
		width: 15em;
		text-align: right;
		padding-right: 0.5em;
	}

	input, select {
		border: 1px solid #000066;
	}

	</style>
</head>
<body>

<div class="input-field">
<% if (my $error = stash 'error') { %>
<p class="error">
  Error: <%= $error %><br/>
</p>
<% } %>

<%= content %>

<div class="about">
<a href="https://github.com/derf/linktrack">linktrack</a>
v<%= $version %>
</div>

</body>
</html>

@@ main.html.ep

%= form_for '/' => begin
<p>
%= hidden_field filter => 1
% for my $lecture (@{$lectures}) {
<%= check_box $lecture => 1 %> <%= $lecture %>
% }
%= submit_button 'show'
</p>
%= end

% for my $date (@{$dates}) {
<h1> <%= $date->{date} %> </h1>
<ul>
% for my $change (@{$date->{changes}}) {
<li>
<a href="<%= $change->{lecture_url} %>"><%= $change->{lecture_name} %></a>
<%= $change->{type} %>
<a href="<%= $change->{link_url} %>"><%= $change->{link_name} %></a>
</li>
% }
</ul>
% }

@@ not_found.html.ep
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN"
	"http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en">
<head>
	<title>page not found</title>
	<meta http-equiv="Content-Type" content="text/html;charset=utf-8"/>
</head>
<body>
<div>
page not found
</div>
</body>
</html>
