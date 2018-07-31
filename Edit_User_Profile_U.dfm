object frmEditUserProfile: TfrmEditUserProfile
  Left = 0
  Top = 0
  Caption = 'Edit Profile'
  ClientHeight = 221
  ClientWidth = 429
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  PixelsPerInch = 96
  TextHeight = 13
  object lblFirstName: TLabel
    Left = 22
    Top = 18
    Width = 51
    Height = 13
    Caption = 'First Name'
  end
  object lblLastName: TLabel
    Left = 22
    Top = 66
    Width = 50
    Height = 13
    Caption = 'Last Name'
  end
  object lblNewPassword: TLabel
    Left = 262
    Top = 65
    Width = 70
    Height = 13
    Caption = 'New Password'
  end
  object lblConfirmNewPassword: TLabel
    Left = 262
    Top = 113
    Width = 110
    Height = 13
    Caption = 'Confirm New Password'
  end
  object lblOldPassword: TLabel
    Left = 262
    Top = 18
    Width = 65
    Height = 13
    Caption = 'Old Password'
  end
  object btnUpdate: TButton
    Left = 21
    Top = 172
    Width = 159
    Height = 25
    Caption = 'Update'
    Default = True
    Enabled = False
    TabOrder = 0
    OnClick = btnUpdateClick
  end
  object edtFirstName: TEdit
    Left = 22
    Top = 37
    Width = 158
    Height = 21
    TabOrder = 1
    TextHint = 'First Name'
    OnChange = profileFieldChanged
    OnDblClick = fieldSelected
  end
  object edtLastName: TEdit
    Left = 22
    Top = 85
    Width = 158
    Height = 21
    TabOrder = 2
    TextHint = 'Last Name'
    OnChange = profileFieldChanged
    OnDblClick = fieldSelected
  end
  object edtNewPassword: TEdit
    Left = 262
    Top = 84
    Width = 131
    Height = 21
    PasswordChar = '*'
    TabOrder = 4
    TextHint = 'New Password'
    OnChange = passwordFieldChanged
  end
  object edtOldPassword: TEdit
    Left = 262
    Top = 37
    Width = 131
    Height = 21
    PasswordChar = '*'
    TabOrder = 3
    TextHint = 'Old Password'
    OnChange = passwordFieldChanged
  end
  object edtNewPasswordConfirm: TEdit
    Left = 262
    Top = 132
    Width = 131
    Height = 21
    PasswordChar = '*'
    TabOrder = 5
    TextHint = 'Confirm New Password'
    OnChange = passwordFieldChanged
  end
  object btnChangePassword: TButton
    Left = 262
    Top = 172
    Width = 131
    Height = 25
    Caption = 'Change'
    Default = True
    Enabled = False
    TabOrder = 6
    OnClick = btnChangePasswordClick
  end
end
