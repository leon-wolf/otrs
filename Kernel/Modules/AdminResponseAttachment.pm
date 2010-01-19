# --
# Kernel/Modules/AdminResponseAttachment.pm - queue <-> responses
# Copyright (C) 2001-2010 OTRS AG, http://otrs.org/
# --
# $Id: AdminResponseAttachment.pm,v 1.31 2010-01-19 21:39:22 martin Exp $
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AdminResponseAttachment;

use strict;
use warnings;

use Kernel::System::StdAttachment;
use Kernel::System::StdResponse;

use vars qw($VERSION);
$VERSION = qw($Revision: 1.31 $) [1];

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    # check all needed objects
    for (qw(ParamObject DBObject LayoutObject ConfigObject LogObject)) {
        if ( !$Self->{$_} ) {
            $Self->{LayoutObject}->FatalError( Message => "Got no $_!" );
        }
    }

    # lib object
    $Self->{StdResponseObject}   = Kernel::System::StdResponse->new(%Param);
    $Self->{StdAttachmentObject} = Kernel::System::StdAttachment->new(%Param);

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $Output = '';
    my $ID = $Self->{ParamObject}->GetParam( Param => 'ID' ) || '';
    $ID = $Self->{DBObject}->Quote( $ID, 'Integer' ) if $ID;

    my $NextScreen = 'AdminResponseAttachment';

    # get StdResponses data
    my %StdResponses = $Self->{StdResponseObject}->StdResponseList( Valid => 1 );

    # get queue data
    my %StdAttachments = $Self->{StdAttachmentObject}->StdAttachmentList( Valid => 1 );

    # user <-> group 1:n
    if ( $Self->{Subaction} eq 'Response' ) {
        $Output .= $Self->{LayoutObject}->Header();
        $Output .= $Self->{LayoutObject}->NavigationBar();

        # get StdResponses data
        my %StdResponsesData = $Self->{DBObject}->GetTableData(
            Table => 'standard_response',
            What  => 'id, name',
            Where => "id = $ID",
        );
        my %Data = $Self->{DBObject}->GetTableData(
            Table => 'standard_response_attachment',
            What  => 'standard_attachment_id, standard_response_id',
            Where => "standard_response_id = $ID",
        );
        $Output .= $Self->_MaskChange(
            FirstData  => \%StdResponsesData,
            SecondData => \%StdAttachments,
            Data       => \%Data,
            Type       => 'Response',
        );

        $Output .= $Self->{LayoutObject}->Footer();
    }

    # group <-> user n:1
    elsif ( $Self->{Subaction} eq 'Attachment' ) {
        $Output .= $Self->{LayoutObject}->Header();
        $Output .= $Self->{LayoutObject}->NavigationBar();

        # get queue data
        my %AttachmentData = $Self->{DBObject}->GetTableData(
            Table => 'standard_attachment',
            What  => 'id, name, filename',
            Clamp => 1,
            Where => "id = $ID",
        );

        my %Data = $Self->{DBObject}->GetTableData(
            Table => 'standard_response_attachment',
            What  => 'standard_response_id, standard_attachment_id',
            Where => "standard_attachment_id = $ID"
        );
        $Output .= $Self->_MaskChange(
            FirstData  => \%AttachmentData,
            SecondData => \%StdResponses,
            Data       => \%Data,
            Type       => 'Attachment',
        );
        $Output .= $Self->{LayoutObject}->Footer();
    }

    # update responses of attachment
    elsif ( $Self->{Subaction} eq 'ChangeAttachment' ) {
        my @NewIDs = $Self->{ParamObject}->GetArray( Param => 'IDs' );
        $Self->{DBObject}->Do(
            SQL => "DELETE FROM standard_response_attachment WHERE standard_attachment_id = $ID",
        );
        for my $NewID (@NewIDs) {

            # db quote
            $NewID = $Self->{DBObject}->Quote( $NewID, 'Integer' );
            my $SQL
                = "INSERT INTO standard_response_attachment (standard_attachment_id, "
                . "standard_response_id, create_time, create_by, "
                . " change_time, change_by)"
                . " VALUES "
                . " ($ID, $NewID, current_timestamp, $Self->{UserID}, current_timestamp, $Self->{UserID})";
            $Self->{DBObject}->Do( SQL => $SQL );
        }
        $Output .= $Self->{LayoutObject}->Redirect( OP => "Action=$NextScreen" );
    }

    # update attachments of response
    elsif ( $Self->{Subaction} eq 'ChangeResponse' ) {
        my @NewIDs = $Self->{ParamObject}->GetArray( Param => 'IDs' );
        $Self->{StdAttachmentObject}->StdAttachmentSetResponses(
            AttachmentIDsRef => \@NewIDs,
            ID               => $ID,
            UserID           => $Self->{UserID},
        );
        $Output .= $Self->{LayoutObject}->Redirect( OP => "Action=$NextScreen" );

    }

    # else ! print form
    else {
        $Output .= $Self->{LayoutObject}->Header();
        $Output .= $Self->{LayoutObject}->NavigationBar();
        $Output .= $Self->_Mask(
            FirstData  => \%StdResponses,
            SecondData => \%StdAttachments,
        );
        $Output .= $Self->{LayoutObject}->Footer();
    }
    return $Output;
}

sub _Mask {
    my ( $Self, %Param ) = @_;

    my $UserData     = $Param{FirstData};
    my %UserDataTmp  = %$UserData;
    my $GroupData    = $Param{SecondData};
    my %GroupDataTmp = %$GroupData;
    my $BaseLink     = $Self->{LayoutObject}->{Baselink} . "Action=AdminResponseAttachment;";
    for ( sort { $UserDataTmp{$a} cmp $UserDataTmp{$b} } keys %UserDataTmp ) {
        $UserDataTmp{$_} = $Self->{LayoutObject}->Ascii2Html(
            Text                => $UserDataTmp{$_},
            HTMLQuote           => 1,
            LanguageTranslation => 0,
        ) || '';
        $Param{AnswerQueueStrg}
            .= "<a href=\"$BaseLink" . "Subaction=Response;ID=$_\">$UserDataTmp{$_}</a><br/>";
    }
    for ( sort { $GroupDataTmp{$a} cmp $GroupDataTmp{$b} } keys %GroupDataTmp ) {
        $GroupDataTmp{$_} = $Self->{LayoutObject}->Ascii2Html(
            Text                => $GroupDataTmp{$_},
            HTMLQuote           => 1,
            LanguageTranslation => 0,
        ) || '';
        $Param{QueueAnswerStrg}
            .= "<a href=\"$BaseLink" . "Subaction=Attachment;ID=$_\">$GroupDataTmp{$_}</a><br/>";
    }

    return $Self->{LayoutObject}->Output(
        TemplateFile => 'AdminResponseAttachmentForm',
        Data         => \%Param
    );
}

sub _MaskChange {
    my ( $Self, %Param ) = @_;

    my $FirstData     = $Param{FirstData};
    my %FirstDataTmp  = %$FirstData;
    my $SecondData    = $Param{SecondData};
    my %SecondDataTmp = %$SecondData;
    my $Data          = $Param{Data};
    my %DataTmp       = %$Data;
    $Param{Type} = $Param{Type} || 'Response';
    my $NeType = 'Response';
    $NeType = 'Attachment' if ( $Param{Type} eq 'Response' );

    for ( sort keys %FirstDataTmp ) {
        $FirstDataTmp{$_} = $Self->{LayoutObject}->Ascii2Html(
            Text                => $FirstDataTmp{$_},
            HTMLQuote           => 1,
            LanguageTranslation => 0,
        ) || '';
        $Param{OptionStrg0}
            .= "<b>$Param{Type}:</b> <a href=\"$Self->{LayoutObject}->{Baselink}Action=Admin$Param{Type};Subaction=Change;ID=$_\">"
            . "$FirstDataTmp{$_}</a> (id=$_)<br/>";
        $Param{OptionStrg0} .= "<input type=\"hidden\" name=\"ID\" value=\"$_\" /><br/>\n";
    }
    $Param{OptionStrg0}
        .= "<b>$NeType:</b><br/> <select name=\"IDs\" size=\"10\" multiple=\"multiple\">\n";
    for my $ID ( sort keys %SecondDataTmp ) {
        $SecondDataTmp{$ID} = $Self->{LayoutObject}->Ascii2Html(
            Text                => $SecondDataTmp{$ID},
            HTMLQuote           => 1,
            LanguageTranslation => 0,
        ) || '';
        $Param{OptionStrg0} .= "<option ";
        for ( sort keys %DataTmp ) {
            if ( $_ eq $ID ) {
                $Param{OptionStrg0} .= 'selected="selected"';
            }
        }
        $Param{OptionStrg0} .= " value=\"$ID\">$SecondDataTmp{$ID} (id=$ID)</option>\n";
    }
    $Param{OptionStrg0} .= "</select>\n";

    return $Self->{LayoutObject}->Output(
        TemplateFile => 'AdminResponseAttachmentChangeForm',
        Data         => \%Param
    );
}

1;
