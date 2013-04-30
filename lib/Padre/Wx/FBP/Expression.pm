package Padre::Wx::FBP::Expression;

## no critic

# This module was generated by Padre::Plugin::FormBuilder::Perl.
# To change this module edit the original .fbp file and regenerate.
# DO NOT MODIFY THIS FILE BY HAND!

use 5.008005;
use utf8;
use strict;
use warnings;
use Padre::Wx ();
use Padre::Wx::Role::Main ();

our $VERSION = '0.98';
our @ISA     = qw{
	Padre::Wx::Role::Main
	Wx::Dialog
};

sub new {
	my $class  = shift;
	my $parent = shift;

	my $self = $class->SUPER::new(
		$parent,
		-1,
		Wx::gettext("Evaluate Expression"),
		Wx::DefaultPosition,
		Wx::DefaultSize,
		Wx::DEFAULT_DIALOG_STYLE | Wx::RESIZE_BORDER,
	);

	$self->{code} = Wx::ComboBox->new(
		$self,
		-1,
		"",
		Wx::DefaultPosition,
		Wx::DefaultSize,
		[
			"Padre::Current->config",
			"Padre::Current->editor",
			"Padre::Current->document",
			"Padre::Current->ide",
			"Padre::Current->ide->task_manager",
			"Padre::Wx::Display->dump",
			"\\\@INC, \\%INC",
		],
		Wx::TE_PROCESS_ENTER,
	);

	Wx::Event::EVT_COMBOBOX(
		$self,
		$self->{code},
		sub {
			shift->on_combobox(@_);
		},
	);

	Wx::Event::EVT_TEXT(
		$self,
		$self->{code},
		sub {
			shift->on_text(@_);
		},
	);

	Wx::Event::EVT_TEXT_ENTER(
		$self,
		$self->{code},
		sub {
			shift->on_text_enter(@_);
		},
	);

	$self->{evaluate} = Wx::Button->new(
		$self,
		-1,
		Wx::gettext("Evaluate"),
		Wx::DefaultPosition,
		Wx::DefaultSize,
	);

	Wx::Event::EVT_BUTTON(
		$self,
		$self->{evaluate},
		sub {
			shift->evaluate_clicked(@_);
		},
	);

	$self->{watch} = Wx::ToggleButton->new(
		$self,
		-1,
		Wx::gettext("Watch"),
		Wx::DefaultPosition,
		Wx::DefaultSize,
	);

	Wx::Event::EVT_TOGGLEBUTTON(
		$self,
		$self->{watch},
		sub {
			shift->watch_clicked(@_);
		},
	);

	$self->{output} = Wx::TextCtrl->new(
		$self,
		-1,
		"",
		Wx::DefaultPosition,
		Wx::DefaultSize,
		Wx::TE_MULTILINE | Wx::TE_READONLY,
	);
	$self->{output}->SetMinSize( [ 500, 400 ] );
	$self->{output}->SetFont(
		Wx::Font->new( Wx::NORMAL_FONT->GetPointSize, 76, 90, 90, 0, "" )
	);

	my $bSizer36 = Wx::BoxSizer->new(Wx::HORIZONTAL);
	$bSizer36->Add( $self->{code}, 1, Wx::EXPAND | Wx::LEFT | Wx::TOP, 5 );
	$bSizer36->Add( $self->{evaluate}, 0, Wx::LEFT | Wx::TOP, 5 );
	$bSizer36->Add( $self->{watch}, 0, Wx::LEFT | Wx::RIGHT | Wx::TOP, 5 );

	my $bSizer35 = Wx::BoxSizer->new(Wx::VERTICAL);
	$bSizer35->Add( $bSizer36, 0, Wx::EXPAND, 3 );
	$bSizer35->Add( $self->{output}, 1, Wx::ALL | Wx::EXPAND, 5 );

	$self->SetSizerAndFit($bSizer35);
	$self->Layout;

	return $self;
}

sub on_combobox {
	$_[0]->main->error('Handler method on_combobox for event code.OnCombobox not implemented');
}

sub on_text {
	$_[0]->main->error('Handler method on_text for event code.OnText not implemented');
}

sub on_text_enter {
	$_[0]->main->error('Handler method on_text_enter for event code.OnTextEnter not implemented');
}

sub evaluate_clicked {
	$_[0]->main->error('Handler method evaluate_clicked for event evaluate.OnButtonClick not implemented');
}

sub watch_clicked {
	$_[0]->main->error('Handler method watch_clicked for event watch.OnToggleButton not implemented');
}

1;

# Copyright 2008-2013 The Padre development team as listed in Padre.pm.
# LICENSE
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl 5 itself.
