package Padre::Wx::Syntax;

use 5.008;
use strict;
use warnings;
use Params::Util          ();
use Padre::Feature        ();
use Padre::Role::Task     ();
use Padre::Wx::Role::View ();
use Padre::Wx::Role::Main ();
use Padre::Wx             ();
use Padre::Wx::Icon       ();
use Padre::Wx::TreeCtrl   ();
use Padre::Wx::HtmlWindow ();
use Padre::Logger;

our $VERSION = '0.90';
our @ISA     = qw{
	Padre::Role::Task
	Padre::Wx::Role::View
	Padre::Wx::Role::Main
	Wx::Panel
};

# perldiag error message classification
my %MESSAGE = (

	# (W) A warning (optional).
	'W' => {
		label  => Wx::gettext('Warning'),
		marker => Padre::Wx::MarkWarn(),
	},

	# (D) A deprecation (enabled by default).
	'D' => {
		label  => Wx::gettext('Deprecation'),
		marker => Padre::Wx::MarkWarn(),
	},

	# (S) A severe warning (enabled by default).
	'S' => {
		label  => Wx::gettext('Severe Warning'),
		marker => Padre::Wx::MarkWarn(),
	},

	# (F) A fatal error (trappable).
	'F' => {
		label  => Wx::gettext('Fatal Error'),
		marker => Padre::Wx::MarkError(),
	},

	# (P) An internal error you should never see (trappable).
	'P' => {
		label  => Wx::gettext('Internal Error'),
		marker => Padre::Wx::MarkError(),
	},

	# (X) A very fatal error (nontrappable).
	'X' => {
		label  => Wx::gettext('Very Fatal Error'),
		marker => Padre::Wx::MarkError(),
	},

	# (A) An alien error message (not generated by Perl).
	'A' => {
		label  => Wx::gettext('Alien Error'),
		marker => Padre::Wx::MarkError(),
	},
);

sub new {
	my $class = shift;
	my $main  = shift;
	my $panel = shift || $main->bottom;
	my $self  = $class->SUPER::new($panel);

	# Create the underlying object
	$self->{tree} = Padre::Wx::TreeCtrl->new(
		$self,
		-1,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxTR_SINGLE | Wx::wxTR_FULL_ROW_HIGHLIGHT | Wx::wxTR_HAS_BUTTONS
	);

	$self->{help} = Padre::Wx::HtmlWindow->new(
		$self,
		-1,
		Wx::wxDefaultPosition,
		Wx::wxDefaultSize,
		Wx::wxBORDER_STATIC,
	);
	$self->{help}->Hide;

	my $sizer = Wx::BoxSizer->new(Wx::wxHORIZONTAL);
	$sizer->Add( $self->{tree}, 3, Wx::wxALL | Wx::wxEXPAND, 2 );
	$sizer->Add( $self->{help}, 2, Wx::wxALL | Wx::wxEXPAND, 2 );
	$self->SetSizer($sizer);

	# Additional properties
	$self->{model}  = [];
	$self->{length} = -1;

	# Prepare the available images
	my $images = Wx::ImageList->new( 16, 16 );
	$self->{images} = {
		error       => $images->Add( Padre::Wx::Icon::icon('status/padre-syntax-error') ),
		warning     => $images->Add( Padre::Wx::Icon::icon('status/padre-syntax-warning') ),
		ok          => $images->Add( Padre::Wx::Icon::icon('status/padre-syntax-ok') ),
		diagnostics => $images->Add(
			Wx::ArtProvider::GetBitmap(
				'wxART_GO_FORWARD',
				'wxART_OTHER_C',
				[ 16, 16 ],
			),
		),
		root => $images->Add(
			Wx::ArtProvider::GetBitmap(
				'wxART_HELP_FOLDER',
				'wxART_OTHER_C',
				[ 16, 16 ],
			),
		),
	};
	$self->{tree}->AssignImageList($images);

	Wx::Event::EVT_TREE_ITEM_ACTIVATED(
		$self,
		$self->{tree},
		sub {
			$_[0]->on_tree_item_activated( $_[1] );
		},
	);

	Wx::Event::EVT_TREE_SEL_CHANGED(
		$self,
		$self->{tree},
		sub {
			$_[0]->on_tree_item_selection_changed( $_[1] );
		},
	);

	$self->Hide;

	if (Padre::Feature::STYLE_GUI) {
		$self->recolour;
	}

	return $self;
}





######################################################################
# Padre::Wx::Role::View Methods

sub view_panel {
	return 'bottom';
}

sub view_label {
	shift->gettext_label(@_);
}

sub view_close {
	$_[0]->main->show_syntaxcheck(0);
}

sub view_start {
	my $self = shift;

	# Add the margins for the syntax markers
	foreach my $editor ( $self->main->editors ) {

		# Margin number 1 for symbols
		$editor->SetMarginType( 1, Wx::wxSTC_MARGIN_SYMBOL );

		# Set margin 1 16 px wide
		$editor->SetMarginWidth( 1, 16 );
	}
}

sub view_stop {
	my $self = shift;
	my $main = $self->main;
	my $lock = $main->lock('UPDATE');

	# Clear out any state and tasks
	$self->task_reset;
	$self->clear;

	# Remove the editor margins
	foreach my $editor ( $main->editors ) {
		$editor->SetMarginWidth( 1, 0 );
	}

	return;
}





#####################################################################
# Event Handlers

sub on_tree_item_selection_changed {
	my $self  = shift;
	my $event = shift;
	my $item  = $event->GetItem or return;
	my $issue = $self->{tree}->GetPlData($item);

	if ( $issue and $issue->{diagnostics} ) {
		my $diag = $issue->{diagnostics};
		$self->_update_help_page($diag);
	} else {
		$self->_update_help_page;
	}
}

sub on_tree_item_activated {
	my $self   = shift;
	my $event  = shift;
	my $item   = $event->GetItem or return;
	my $issue  = $self->{tree}->GetPlData($item) or return;
	my $editor = $self->current->editor or return;
	my $line   = $issue->{line};

	# Does it point to somewhere valid?
	return unless defined $line;
	return if $line !~ /^\d+$/o;
	return if $editor->GetLineCount < $line;

	# Select the problem after the event has finished
	Wx::Event::EVT_IDLE(
		$self,
		sub {
			$self->select_problem( $line - 1 );
			Wx::Event::EVT_IDLE( $self, undef );
		},
	);
}





#####################################################################
# General Methods

sub bottom {
	TRACE("DEPRECATED") if DEBUG;
	shift->main->bottom;
}

sub gettext_label {
	Wx::gettext('Syntax Check');
}

# Remove all markers and empty the list
sub clear {
	my $self = shift;
	my $lock = $self->main->lock('UPDATE');

	# Remove the margins for the syntax markers
	foreach my $editor ( $self->main->editors ) {
		$editor->MarkerDeleteAll(Padre::Wx::MarkError);
		$editor->MarkerDeleteAll(Padre::Wx::MarkWarn);
	}

	# Remove all items from the tool
	$self->{tree}->DeleteAllItems;

	# Clear the help page
	$self->_update_help_page;

	return;
}

# Pick up colouring from the current editor style
sub recolour {
	my $self   = shift;
	my $config = $self->config;

	# Load the editor style
	require Padre::Wx::Editor;
	my $data = Padre::Wx::Editor::data( $config->editor_style ) or return;

	# Find the colours we need
	my $foreground = $data->{padre}->{colors}->{PADRE_BLACK}->{foreground};
	my $background = $data->{padre}->{background};

	# Apply them to the widgets
	if ( defined $foreground and defined $background ) {
		$foreground = Padre::Wx::color($foreground);
		$background = Padre::Wx::color($background);

		$self->{tree}->SetForegroundColour($foreground);
		$self->{tree}->SetBackgroundColour($background);

		# $self->{search}->SetForegroundColour($foreground);
		# $self->{search}->SetBackgroundColour($background);
	}

	return 1;
}

# Nothing to implement here
sub relocale {
	return;
}

sub refresh {
	my $self = shift;

	# Abort any in-flight checks
	$self->task_reset;

	# Do we have a document with something in it?
	my $document = $self->current->document;
	unless ( $document and not $document->is_unused ) {
		$self->clear;
		return;
	}

	# Is there a syntax check task for this document type
	my $task = $document->task_syntax;
	unless ($task) {
		$self->clear;
		return;
	}

	# Fire the background task discarding old results
	$self->task_request(
		task     => $task,
		document => $document,
	);

	# Clear out the syntax check window, leaving the margin as is
	$self->{tree}->DeleteAllItems;
	$self->_update_help_page;

	return 1;
}

sub task_finish {
	my $self = shift;
	my $task = shift;
	$self->{model} = $task->{model};
	$self->render;
}

sub render {
	my $self     = shift;
	my $model    = $self->{model} || [];
	my $current  = $self->current;
	my $editor   = $current->editor;
	my $document = $current->document;
	my $filename = $current->filename;
	my $lock     = $self->main->lock('UPDATE');

	# Clear all indicators
	$editor->StartStyling( 0, Wx::wxSTC_INDICS_MASK );
	$editor->SetStyling( $editor->GetTextLength - 1, 0 );

	# NOTE: Recolor the document to make sure we do not accidentally
	# remove syntax highlighting while syntax checking
	$document->colourize;

	# Flush old results
	$self->clear;

	my $root = $self->{tree}->AddRoot('Root');

	# If there are no errors clear the synax checker pane
	unless ( Params::Util::_ARRAY($model) ) {

		# Relative-to-the-project filename.
		# Check that the document has been saved.
		if ( defined $filename ) {
			my $project_dir = $document->project_dir;
			if ( defined $project_dir ) {
				$project_dir = quotemeta $project_dir;
				$filename =~ s/^$project_dir[\\\/]?//;
			}
			$self->{tree}->SetItemText(
				$root,
				sprintf( Wx::gettext('No errors or warnings found in %s.'), $filename )
			);
		} else {
			$self->{tree}->SetItemText( $root, Wx::gettext('No errors or warnings found.') );
		}
		$self->{tree}->SetItemImage( $root, $self->{images}->{ok} );
		return;
	}

	$self->{tree}->SetItemText(
		$root,
		defined $filename
		? sprintf( Wx::gettext('Found %d issue(s) in %s'), scalar @$model, $filename )
		: sprintf( Wx::gettext('Found %d issue(s)'),       scalar @$model )
	);
	$self->{tree}->SetItemImage( $root, $self->{images}->{root} );

	my $i = 0;
	ISSUE:
	foreach my $issue ( sort { $a->{line} <=> $b->{line} } @$model ) {

		my $line       = $issue->{line} - 1;
		my $type       = exists $issue->{type} ? $issue->{type} : 'F';
		my $marker     = $MESSAGE{$type}{marker};
		my $is_warning = $marker == Padre::Wx::MarkWarn();
		$editor->MarkerAdd( $line, $marker );

		# Underline the syntax warning/error line with an orange or red squiggle indicator
		my $start  = $editor->PositionFromLine($line);
		my $indent = $editor->GetLineIndentPosition($line);
		my $end    = $editor->GetLineEndPosition($line);

		# Change only the indicators
		$editor->StartStyling( $indent, Wx::wxSTC_INDICS_MASK );
		$editor->SetStyling( $end - $indent, $is_warning ? Wx::wxSTC_INDIC1_MASK : Wx::wxSTC_INDIC2_MASK );

		my $item = $self->{tree}->AppendItem(
			$root,
			sprintf(
				Wx::gettext('Line %d:   (%s)   %s'),
				$line + 1,
				$MESSAGE{$type}{label},
				$issue->{message}
			),
			$is_warning ? $self->{images}{warning} : $self->{images}{error}
		);
		$self->{tree}->SetPlData( $item, $issue );
	}

	$self->{tree}->Expand($root);
	$self->{tree}->EnsureVisible($root);

	return 1;
}

# Updates the help page. It shows the text if it is defined otherwise clears and hides it
sub _update_help_page {
	my $self = shift;
	my $text = shift;

	# load the escaped HTML string into the shown page otherwise hide
	# if the text is undefined
	my $help = $self->{help};
	if ( defined $text ) {
		require CGI;
		$text = CGI::escapeHTML($text);
		$text =~ s/\n/<br>/g;
		my $WARN_TEXT = $MESSAGE{'W'}{label};
		if ( $text =~ /^\((W\s+(\w+)|D|S|F|P|X|A)\)/ ) {
			my ( $category, $warning_category ) = ( $1, $2 );
			my $category_label = ( $category =~ /^W/ ) ? $MESSAGE{'W'}{label} : $MESSAGE{$1}{label};
			my $notes =
				defined($warning_category)
				? "<code>no warnings '$warning_category';    # disable</code><br>"
				. "<code>use warnings '$warning_category';   # enable</code><br><br>"
				: '';
			$text =~ s{^\((W\s+(\w+)|D|S|F|P|X|A)\)}{<h3>$category_label</h3>$notes};
		}
		$help->SetPage($text);
		$help->Show;
	} else {
		$help->SetPage('');
		$help->Hide;
	}

	# Sticky note light-yellow background
	$self->{help}->SetBackgroundColour( Wx::Colour->new( 0xFD, 0xFC, 0xBB ) );

	# Relayout to actually hide/show the help page
	$self->Layout;
}

# Selects the problemistic line :)
sub select_problem {
	my $self   = shift;
	my $line   = shift;
	my $editor = $self->current->editor or return;
	$editor->EnsureVisible($line);
	$editor->goto_pos_centerize( $editor->GetLineIndentPosition($line) );
	$editor->SetFocus;
}

# Selects the next problem in the editor.
# Wraps to the first one when at the end.
sub select_next_problem {
	my $self         = shift;
	my $editor       = $self->current->editor or return;
	my $current_line = $editor->LineFromPosition( $editor->GetCurrentPos );

	# Start with the first child
	my $root = $self->{tree}->GetRootItem;
	my ( $child, $cookie ) = $self->{tree}->GetFirstChild($root);
	my $first_line = undef;
	while ($cookie) {

		# Get the line and check that it is a valid line number
		my $issue = $self->{tree}->GetPlData($child) or return;
		my $line = $issue->{line};

		if (   not defined($line)
			or ( $line !~ /^\d+$/o )
			or ( $line > $editor->GetLineCount ) )
		{
			( $child, $cookie ) = $self->{tree}->GetNextChild( $root, $cookie );
			next;
		}
		$line--;

		if ( not $first_line ) {

			# record the position of the first problem
			$first_line = $line;
		}

		if ( $line > $current_line ) {

			# select the next problem
			$self->select_problem($line);

			# no need to wrap around...
			$first_line = undef;

			# and we're done here...
			last;
		}

		# Get the next child if there is one
		( $child, $cookie ) = $self->{tree}->GetNextChild( $root, $cookie );
	}

	# The next problem is simply the first (wrap around)
	$self->select_problem($first_line) if $first_line;
}

1;

# Copyright 2008-2011 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
