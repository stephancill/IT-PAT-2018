object frmTemplate: TfrmTemplate
  Left = 0
  Top = 0
  Caption = 'PoSify by Stephan Cilliers'
  ClientHeight = 299
  ClientWidth = 635
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  PixelsPerInch = 96
  TextHeight = 13
  object pnlHeader: TPanel
    Left = 8
    Top = 8
    Width = 619
    Height = 41
    Caption = 'Welcome'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -11
    Font.Name = 'Tahoma'
    Font.Style = []
    ParentFont = False
    TabOrder = 0
    object btnLogout: TButton
      Left = 8
      Top = 9
      Width = 75
      Height = 25
      Caption = 'Logout'
      TabOrder = 0
    end
    object btnViewAccount: TButton
      Left = 536
      Top = 9
      Width = 75
      Height = 25
      Caption = 'View Account'
      TabOrder = 1
    end
  end
end
