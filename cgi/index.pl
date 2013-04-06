#!/usr/bin/env perl
use 5.014;
use warnings;
no warnings qw(uninitialized);
use Mojolicious::Lite;
use Date::Format qw(time2str);
use Encode qw(encode);
use Storable;
use XML::RSS;

our $VERSION = '0.01';

my $db_file = 'linktrack_db';
my %db;

my $re_pdf = qr{ \. pdf (?: $ | \? ) }iox;

sub load_db {
	if ( -e $db_file ) {
		my $db = retrieve($db_file);
		%db = %{$db};
	}
}

sub create_rss {
	my (@dates) = @_;

	my $rss = XML::RSS->new( version => '2.0' );

	$rss->channel(
		title         => 'uni.finalrewind.org',
		link          => 'http://uni.finalrewind.org',
		language      => 'de',
		description   => 'TU Dortmund Linktrack',
		pubDate       => "",
		lastBuildDate => "",
	);
}

sub handle_request {
	my $self    = shift;
	my $rss     = $self->param('rss');
	my $filter  = $self->param('filter') // $self->session->{filter} // 0;
	my $pdfonly = $self->param('_pdfonly') // $self->session->{pdfonly} // 0;

	load_db;

	my $prev;
	my @dates;
	my @sites = sort keys %{ $db{sites} };

	if ($self->param('filter')) {
		for my $site (@sites) {
			$self->session->{$site} = $self->param($site);
		}
		$pdfonly = $self->session->{pdfonly} = $self->param('_pdfonly');
	}
	elsif ( not $filter ) {
		for my $site (@sites) {
			$self->param( $site => 1 );
			$self->session->{$site} = 1;
		}
	}
	elsif (not $self->param('filter')) {
		for my $site (@sites) {
			$self->param($site => $self->session->{$site} // 0);
		}
		$self->param( _pdfonly => $pdfonly );
	}

	for my $time ( sort keys $db{entries} ) {
		my $date = time2str( '%d.%m.%Y', $time );
		my @changes;
		for my $site ( sort keys $db{entries}{$time} ) {
			if ( $self->param($site) == 0 ) {
				next;
			}
			for my $url ( sort keys $db{entries}{$time}{$site} ) {
				if ( $pdfonly and $url !~ $re_pdf ) {
					next;
				}
				if ( not exists $prev->{$site}{$url} ) {
					push(
						@changes,
						{
							site_name => $site,
							site_url  => $db{sites}{$site},
							type      => '+',
							link_name => $db{entries}{$time}{$site}{$url},
							link_url  => $url,
						}
					);
				}
			}
		}
		if (@changes) {
			push(
				@dates,
				{
					date    => $date,
					changes => \@changes
				}
			);
		}
		$prev = $db{entries}{$time};
	}
	@dates = reverse @dates;

	$self->render(
		'main',
		sites   => \@sites,
		dates   => \@dates,
		title   => 'linktrack',
		version => $VERSION,
	);
}

app->defaults( layout => 'default' );

get '/' => \&handle_request;

app->config(
	hypnotoad => {
		accept_interval => 0.2,
		listen          => ['http://*:8096'],
		pid_file        => '/tmp/linktrack.uni.pid',
		workers         => 1,
	},
);

app->secret($ENV{MOJOLICIOUS_SECRET});
app->start();
